/// Stockage local (hors-ligne) des classes, via shared_preferences.
/// Fonctionne sur Android, iOS, Web, Windows, macOS et Linux.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/classroom.dart';
import '../models/saved_room.dart';

enum RepositoryLoadStatus {
  ok,
  recoveredFromBackup,
  corrupted,
}

class RepositoryLoadResult<T> {
  final T data;
  final RepositoryLoadStatus status;

  const RepositoryLoadResult(this.data, this.status);
}

class Repository {
  static const _key = 'plandeclasse_classes_v1';
  static const _backupKey = 'plandeclasse_classes_v1_backup';
  static const _corruptKey = 'plandeclasse_classes_v1_corrupt';
  static const _viewModeKey = 'plandeclasse_students_view_mode_v1';
  static const _windowBoundsKey = 'plandeclasse_window_bounds_v1';
  static const _savedRoomsKey = 'plandeclasse_saved_rooms_v1';
  static const _savedRoomsBackupKey = 'plandeclasse_saved_rooms_v1_backup';
  static const _savedRoomsCorruptKey = 'plandeclasse_saved_rooms_v1_corrupt';
  static const _genderColorPaletteKey =
      'plandeclasse_gender_color_palette_v1';

  Future<List<ClassGroup>> load() async =>
      (await loadClassesWithStatus()).data;

  Future<RepositoryLoadResult<List<ClassGroup>>>
      loadClassesWithStatus() => _loadList(
            key: _key,
            backupKey: _backupKey,
            corruptKey: _corruptKey,
            fromJson: ClassGroup.fromJson,
          );

  Future<void> save(List<ClassGroup> classes) {
    // Sérialiser avant le premier await fige l'état correspondant exactement
    // à cette demande de sauvegarde, même si les modèles mutables évoluent
    // pendant l'écriture asynchrone.
    final raw = jsonEncode(classes.map((c) => c.toJson()).toList());
    return _saveList(
      key: _key,
      backupKey: _backupKey,
      corruptKey: _corruptKey,
      raw: raw,
      fromJson: ClassGroup.fromJson,
    );
  }

  /// Retourne le nom brut stocké (ex. `'complete'`/`'compact'`), ou `null` si
  /// jamais réglé. La conversion en [StudentsViewMode] se fait côté AppState.
  Future<String?> loadStudentsViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_viewModeKey);
  }

  Future<void> saveStudentsViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, _viewModeKey, mode);
  }

  /// Nom brut de la palette choisie (ex. `'violetAmbre'`), ou `null` si
  /// jamais réglée. La conversion en [GenderColorPalette] se fait côté
  /// AppState.
  Future<String?> loadGenderColorPalette() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_genderColorPaletteKey);
  }

  Future<void> saveGenderColorPalette(String palette) async {
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, _genderColorPaletteKey, palette);
  }

  /// Taille/position de la fenêtre desktop (Windows/macOS/Linux), ou `null`
  /// si jamais sauvegardée. Pas de dépendance à `dart:ui` ici (types bruts),
  /// c'est à l'appelant (main.dart) de les convertir en Offset/Size.
  Future<({double x, double y, double width, double height})?>
      loadWindowBounds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_windowBoundsKey);
    if (raw == null) return null;
    final parts = raw.split(',').map(double.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return null;
    return (x: parts[0]!, y: parts[1]!, width: parts[2]!, height: parts[3]!);
  }

  Future<void> saveWindowBounds(
      double x, double y, double width, double height) async {
    final prefs = await SharedPreferences.getInstance();
    await _setString(prefs, _windowBoundsKey, '$x,$y,$width,$height');
  }

  /// Salles enregistrées par l'utilisateur (voir [SavedRoom]), indépendantes
  /// des classes.
  Future<List<SavedRoom>> loadSavedRooms() async =>
      (await loadSavedRoomsWithStatus()).data;

  Future<RepositoryLoadResult<List<SavedRoom>>>
      loadSavedRoomsWithStatus() => _loadList(
            key: _savedRoomsKey,
            backupKey: _savedRoomsBackupKey,
            corruptKey: _savedRoomsCorruptKey,
            fromJson: SavedRoom.fromJson,
          );

  Future<void> saveSavedRooms(List<SavedRoom> rooms) {
    final raw = jsonEncode(rooms.map((r) => r.toJson()).toList());
    return _saveList(
      key: _savedRoomsKey,
      backupKey: _savedRoomsBackupKey,
      corruptKey: _savedRoomsCorruptKey,
      raw: raw,
      fromJson: SavedRoom.fromJson,
    );
  }

  Future<RepositoryLoadResult<List<T>>> _loadList<T>({
    required String key,
    required String backupKey,
    required String corruptKey,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return RepositoryLoadResult(<T>[], RepositoryLoadStatus.ok);
    }

    final decoded = _tryDecodeList(raw, fromJson);
    if (decoded != null) {
      return RepositoryLoadResult(decoded, RepositoryLoadStatus.ok);
    }

    // Ne jamais écraser la seule trace des données illisibles : une copie
    // séparée reste disponible pour une récupération manuelle éventuelle.
    await _preserveCorruptData(prefs, corruptKey, raw);

    final backupRaw = prefs.getString(backupKey);
    if (backupRaw != null && backupRaw.isNotEmpty) {
      final backup = _tryDecodeList(backupRaw, fromJson);
      if (backup != null) {
        // Répare au mieux la valeur principale. Même si l'écriture échoue,
        // les données de secours restent chargées pour cette session.
        await prefs.setString(key, backupRaw);
        return RepositoryLoadResult(
          backup,
          RepositoryLoadStatus.recoveredFromBackup,
        );
      }
    }

    return RepositoryLoadResult(<T>[], RepositoryLoadStatus.corrupted);
  }

  Future<void> _saveList<T>({
    required String key,
    required String backupKey,
    required String corruptKey,
    required String raw,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(key);
    final previousIsValid = previous != null &&
        previous.isNotEmpty &&
        _tryDecodeList(previous, fromJson) != null;

    if (previousIsValid) {
      await _setString(prefs, backupKey, previous);
    } else if (previous != null && previous.isNotEmpty) {
      await _preserveCorruptData(prefs, corruptKey, previous);
    }

    await _setString(prefs, key, raw);

    // Première sauvegarde, ou valeur principale antérieure corrompue sans
    // secours exploitable : initialiser aussi un point de restauration.
    final backup = prefs.getString(backupKey);
    final backupIsValid = backup != null &&
        backup.isNotEmpty &&
        _tryDecodeList(backup, fromJson) != null;
    if (!previousIsValid && !backupIsValid) {
      await _setString(prefs, backupKey, raw);
    }
  }

  List<T>? _tryDecodeList<T>(
    String raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _preserveCorruptData(
      SharedPreferences prefs, String key, String raw) async {
    try {
      await prefs.setString(key, raw);
    } catch (_) {
      // La lecture reste possible sans faire planter l'application. Le statut
      // « corrupted » avertira l'utilisateur même si cette copie échoue.
    }
  }

  Future<void> _setString(
      SharedPreferences prefs, String key, String value) async {
    final written = await prefs.setString(key, value);
    if (!written) {
      throw StateError('Impossible d\'écrire la préférence $key.');
    }
  }
}
