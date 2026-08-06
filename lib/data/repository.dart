/// Stockage local (hors-ligne) des classes, via shared_preferences.
/// Fonctionne sur Android, iOS, Web, Windows, macOS et Linux.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/classroom.dart';

class Repository {
  static const _key = 'plandeclasse_classes_v1';
  static const _viewModeKey = 'plandeclasse_students_view_mode_v1';
  static const _windowBoundsKey = 'plandeclasse_window_bounds_v1';

  Future<List<ClassGroup>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(ClassGroup.fromJson).toList();
    } catch (_) {
      // Données corrompues : on repart proprement plutôt que de planter.
      return [];
    }
  }

  Future<void> save(List<ClassGroup> classes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(classes.map((c) => c.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  /// Retourne le nom brut stocké (ex. `'complete'`/`'compact'`), ou `null` si
  /// jamais réglé. La conversion en [StudentsViewMode] se fait côté AppState.
  Future<String?> loadStudentsViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_viewModeKey);
  }

  Future<void> saveStudentsViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, mode);
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
    await prefs.setString(_windowBoundsKey, '$x,$y,$width,$height');
  }
}
