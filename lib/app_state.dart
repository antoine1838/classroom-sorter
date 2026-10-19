/// État global de l'application (liste des classes) + persistance.
///
/// On utilise un simple [ChangeNotifier] du cœur de Flutter : les écrans
/// écoutent via [ListenableBuilder]. Les objets (classe, élève, règle…) sont
/// modifiés directement dans l'UI, puis on appelle [touch] pour notifier et
/// sauvegarder.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale;

import 'data/repository.dart';
import 'models/classroom.dart';
import 'models/plan_snapshot.dart';
import 'models/room.dart';
import 'models/saved_room.dart';
import 'models/student.dart' show GenderColorPalette;

/// Classe d'exemple prête à l'emploi, pour découvrir l'appli ou refaire des
/// captures d'écran sans ressaisir des données à la main.
const String demoClassAsset = 'assets/demo/demo_class_6emeb.json';

/// Identifiant unique simple (horodatage + aléatoire), sans dépendance externe.
///
/// Le tirage reste sous 2^31 : en dart2js `1 << 32` vaut 0 (décalage sur
/// 32 bits) et `nextInt` lève alors une `RangeError`.
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${Random().nextInt(0x7fffffff).toRadixString(36)}';

/// Vue de l'onglet Élèves : [complete] (une colonne par valeur possible, à
/// cocher) ou [compact] (une colonne par attribut, tap pour cycler).
enum StudentsViewMode { complete, compact }

enum LocalePreference { system, french, english }

enum ThemePreference { system, light, dark }

/// Types de messages de persistance affichés par l'interface.
///
/// L'état conserve l'événement, l'écran fournit le texte localisé.
enum PersistenceNotice {
  classesRecovered,
  roomsRecovered,
  classesCorrupted,
  roomsCorrupted,
  saveFailed,
}

typedef _PersistenceBatch = ({
  bool saveClasses,
  bool saveRooms,
  String? viewMode,
  String? palette,
  String? localePreference,
  String? themePreference,
  bool? tutorialSeen,
});

class AppState extends ChangeNotifier {
  final Repository _repo;

  AppState({Repository? repository}) : _repo = repository ?? Repository();

  List<ClassGroup> classes = [];
  List<SavedRoom> savedRooms = [];
  bool loading = true;
  StudentsViewMode studentsViewMode = StudentsViewMode.complete;
  GenderColorPalette genderColorPalette = GenderColorPalette.tealCorail;
  LocalePreference localePreference = LocalePreference.system;
  ThemePreference themePreference = ThemePreference.system;
  bool tutorialSeen = false;

  String? _loadNotice;
  bool _loadNoticeIsError = false;
  List<PersistenceNotice> _loadNotices = const [];
  String? _saveError;
  Object? _lastPersistenceError;

  bool _classesDirty = false;
  bool _savedRoomsDirty = false;
  String? _pendingStudentsViewMode;
  String? _pendingGenderColorPalette;
  String? _pendingLocalePreference;
  String? _pendingThemePreference;
  bool? _pendingTutorialSeen;
  // Parties dont la dernière écriture a échoué : réécrites au prochain lot.
  _PersistenceBatch? _failedParts;
  Future<void>? _persistenceLoop;

  String? get persistenceMessage => _saveError ?? _loadNotice;
  List<PersistenceNotice> get persistenceNotices => _saveError != null
      ? const [PersistenceNotice.saveFailed]
      : List.unmodifiable(_loadNotices);
  bool get persistenceMessageIsError =>
      _saveError != null || _loadNoticeIsError;
  bool get canRetryPersistence => _saveError != null;
  Object? get lastPersistenceError => _lastPersistenceError;

  Future<void> init() async {
    final classLoad = await _repo.loadClassesWithStatus();
    final roomLoad = await _repo.loadSavedRoomsWithStatus();
    classes = classLoad.data;
    savedRooms = roomLoad.data;
    _setLoadNotice(classLoad.status, roomLoad.status);

    final rawMode = await _repo.loadStudentsViewMode();
    if (rawMode == StudentsViewMode.compact.name) {
      studentsViewMode = StudentsViewMode.compact;
    }
    final rawPalette = await _repo.loadGenderColorPalette();
    genderColorPalette = GenderColorPalette.values.firstWhere(
      (p) => p.name == rawPalette,
      orElse: () => GenderColorPalette.tealCorail,
    );
    final rawLocalePreference = await _repo.loadLocalePreference();
    localePreference = LocalePreference.values.firstWhere(
      (preference) => preference.name == rawLocalePreference,
      orElse: () => LocalePreference.system,
    );
    final rawThemePreference = await _repo.loadThemePreference();
    themePreference = ThemePreference.values.firstWhere(
      (preference) => preference.name == rawThemePreference,
      orElse: () => ThemePreference.system,
    );
    tutorialSeen = await _repo.loadTutorialSeen();
    loading = false;
    notifyListeners();
  }

  void setStudentsViewMode(StudentsViewMode mode) {
    if (studentsViewMode == mode) return;
    studentsViewMode = mode;
    _pendingStudentsViewMode = mode.name;
    notifyListeners();
    _startPersistence();
  }

  void setGenderColorPalette(GenderColorPalette palette) {
    if (genderColorPalette == palette) return;
    genderColorPalette = palette;
    _pendingGenderColorPalette = palette.name;
    notifyListeners();
    _startPersistence();
  }

  Locale? get locale => switch (localePreference) {
    LocalePreference.system => null,
    LocalePreference.french => const Locale('fr'),
    LocalePreference.english => const Locale('en'),
  };

  void setLocalePreference(LocalePreference preference) {
    if (localePreference == preference) return;
    localePreference = preference;
    _pendingLocalePreference = preference.name;
    notifyListeners();
    _startPersistence();
  }

  ThemeMode get themeMode => switch (themePreference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  void setThemePreference(ThemePreference preference) {
    if (themePreference == preference) return;
    themePreference = preference;
    _pendingThemePreference = preference.name;
    notifyListeners();
    _startPersistence();
  }

  void markTutorialSeen() {
    if (tutorialSeen) return;
    tutorialSeen = true;
    _pendingTutorialSeen = true;
    notifyListeners();
    _startPersistence();
  }

  ClassGroup addClass(String name) {
    final c = ClassGroup(
      id: newId(),
      name: name.trim().isEmpty ? 'Nouvelle classe' : name.trim(),
    );
    classes.add(c);
    touch();
    return c;
  }

  /// Ajoute la classe de démo (6ème B, 20 élèves déjà remplis) depuis
  /// [demoClassAsset], avec un nouvel id pour ne jamais entrer en conflit
  /// avec une classe déjà ajoutée.
  Future<ClassGroup> addDemoClass() async {
    final c = await loadTemporaryDemoClass();
    classes.add(c);
    touch();
    return c;
  }

  /// Charge la démo pour le tutoriel sans l'ajouter ni la sauvegarder.
  ///
  /// L'éditeur peut la modifier normalement, mais [touch] ne sérialise que
  /// [classes] : fermer le tutoriel ne laisse donc aucune classe d'exemple.
  Future<ClassGroup> loadTemporaryDemoClass() async {
    final raw = await rootBundle.loadString(demoClassAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ClassGroup.fromJson({...json, 'id': newId()});
  }

  void deleteClass(ClassGroup c) {
    classes.remove(c);
    touch();
  }

  /// Archive explicitement l'état actuel de [source].
  ///
  /// Cette opération ne dépend pas de la validation du plan : l'utilisateur
  /// choisit lui-même quand une version mérite d'être conservée.
  PlanSnapshot archivePlan(ClassGroup source, String label) {
    final snapshot = PlanSnapshot.fromClassGroup(
      id: newId(),
      label: label.trim(),
      source: source,
    );
    source.snapshots.add(snapshot);
    touch();
    return snapshot;
  }

  void deletePlanSnapshot(ClassGroup source, String snapshotId) {
    source.snapshots.removeWhere((snapshot) => snapshot.id == snapshotId);
    touch();
  }

  /// Restaure un instantané dans une nouvelle classe, sans toucher à la classe
  /// qui porte l'archive ni à l'archive elle-même.
  ClassGroup restorePlanSnapshot(ClassGroup source, PlanSnapshot snapshot) {
    final restored = snapshot.toClassGroup(
      id: newId(),
      name: _restoredClassName(source.name, snapshot.label),
    );
    classes.add(restored);
    touch();
    return restored;
  }

  /// Ajoute une classe importée sans réutiliser son identifiant local.
  ClassGroup importClass(ClassGroup source) {
    final base = source.name.trim().isEmpty ? 'Classe importée' : source.name;
    final imported = ClassGroup.fromJson(source.toJson())
      ..name = _uniqueClassName('$base (importée)');
    // [id] est final : on recrée donc l'objet en remplaçant uniquement son id.
    final data = imported.toJson()..['id'] = newId();
    final copy = ClassGroup.fromJson(data);
    classes.add(copy);
    touch();
    return copy;
  }

  String _restoredClassName(String sourceName, String snapshotLabel) {
    final base = snapshotLabel.isEmpty
        ? '$sourceName (copie)'
        : '$sourceName — $snapshotLabel (copie)';
    if (!classes.any((cls) => cls.name == base)) return base;
    var suffix = 2;
    while (classes.any((cls) => cls.name == '$base $suffix')) {
      suffix++;
    }
    return '$base $suffix';
  }

  String _uniqueClassName(String base) {
    if (!classes.any((cls) => cls.name == base)) return base;
    var suffix = 2;
    while (classes.any((cls) => cls.name == '$base $suffix')) {
      suffix++;
    }
    return '$base $suffix';
  }

  /// À appeler après toute modification d'une classe pour rafraîchir + sauver.
  void touch() {
    _classesDirty = true;
    notifyListeners();
    _startPersistence();
  }

  SavedRoom? savedRoomById(String? id) {
    if (id == null) return null;
    for (final r in savedRooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  bool savedRoomNameExists(String name, {String? excludingId}) =>
      savedRooms.any((r) => r.name == name && r.id != excludingId);

  void _touchSavedRooms() {
    _savedRoomsDirty = true;
    notifyListeners();
    _startPersistence();
  }

  /// Enregistre [room] (copiée, jamais partagée) comme une nouvelle salle
  /// nommée [name]. Si une salle porte déjà ce nom, l'appelant doit d'abord
  /// proposer de la remplacer via [updateSavedRoom] — cette méthode ajoute
  /// toujours une entrée distincte.
  SavedRoom addSavedRoom(String name, Room room) {
    final saved = SavedRoom(
      id: newId(),
      name: name,
      room: Room.fromJson(room.toJson()),
    );
    savedRooms.add(saved);
    _touchSavedRooms();
    return saved;
  }

  /// Remplace la géométrie d'une salle enregistrée existante par une copie
  /// de [room], en conservant son id et son nom.
  void updateSavedRoom(String id, Room room) {
    final saved = savedRoomById(id);
    if (saved == null) return;
    saved.room = Room.fromJson(room.toJson());
    _touchSavedRooms();
  }

  void renameSavedRoom(String id, String name) {
    final saved = savedRoomById(id);
    if (saved == null) return;
    saved.name = name;
    _touchSavedRooms();
  }

  void deleteSavedRoom(String id) {
    savedRooms.removeWhere((r) => r.id == id);
    _touchSavedRooms();
  }

  bool get _hasPendingPersistence =>
      _classesDirty ||
      _savedRoomsDirty ||
      _pendingStudentsViewMode != null ||
      _pendingGenderColorPalette != null ||
      _pendingLocalePreference != null ||
      _pendingThemePreference != null ||
      _pendingTutorialSeen != null;

  /// Une seule boucle d'écriture à la fois. Les modifications reçues pendant
  /// une sauvegarde sont regroupées dans le passage suivant, avec l'état le
  /// plus récent, plutôt que de lancer des écritures concurrentes.
  void _startPersistence() {
    if (!_hasPendingPersistence) return;
    _persistenceLoop ??= _drainPersistence();
  }

  Future<void> _drainPersistence() async {
    try {
      while (_hasPendingPersistence) {
        final result = await _persistBatch(_takePersistenceBatch());
        _applyPersistenceResult(result);
      }
    } finally {
      _persistenceLoop = null;
      // Défensif : une nouvelle mutation peut avoir été notifiée pendant la
      // finalisation de la boucle.
      if (_hasPendingPersistence) _startPersistence();
    }
  }

  /// Prend les modifications en attente, plus les parties dont la précédente
  /// écriture a échoué ([_failedParts]) : elles sont réessayées avec ce lot,
  /// une valeur plus récente l'emportant sur celle qui avait échoué.
  _PersistenceBatch _takePersistenceBatch() {
    final failed = _failedParts;
    final batch = (
      saveClasses: _classesDirty || (failed?.saveClasses ?? false),
      saveRooms: _savedRoomsDirty || (failed?.saveRooms ?? false),
      viewMode: _pendingStudentsViewMode ?? failed?.viewMode,
      palette: _pendingGenderColorPalette ?? failed?.palette,
      localePreference: _pendingLocalePreference ?? failed?.localePreference,
      themePreference: _pendingThemePreference ?? failed?.themePreference,
      tutorialSeen: _pendingTutorialSeen ?? failed?.tutorialSeen,
    );
    _failedParts = null;
    _classesDirty = false;
    _savedRoomsDirty = false;
    _pendingStudentsViewMode = null;
    _pendingGenderColorPalette = null;
    _pendingLocalePreference = null;
    _pendingThemePreference = null;
    _pendingTutorialSeen = null;
    return batch;
  }

  /// Écrit [batch] et renvoie la première erreur ainsi que les parties qui
  /// n'ont pas pu être écrites.
  Future<({Object? error, _PersistenceBatch failed})> _persistBatch(
    _PersistenceBatch batch,
  ) async {
    Object? firstError;
    Future<bool> attempt(Future<void> Function() save) async {
      try {
        await save();
        return true;
      } catch (error) {
        firstError ??= error;
        return false;
      }
    }

    Future<T?> attemptValue<T extends Object>(
      T? value,
      Future<void> Function(T value) save,
    ) async {
      if (value == null) return null;
      return await attempt(() => save(value)) ? null : value;
    }

    final failed = (
      saveClasses:
          batch.saveClasses && !await attempt(() => _repo.save(classes)),
      saveRooms:
          batch.saveRooms &&
          !await attempt(() => _repo.saveSavedRooms(savedRooms)),
      viewMode: await attemptValue(batch.viewMode, _repo.saveStudentsViewMode),
      palette: await attemptValue(batch.palette, _repo.saveGenderColorPalette),
      localePreference: await attemptValue(
        batch.localePreference,
        _repo.saveLocalePreference,
      ),
      themePreference: await attemptValue(
        batch.themePreference,
        _repo.saveThemePreference,
      ),
      tutorialSeen: await attemptValue(
        batch.tutorialSeen,
        _repo.saveTutorialSeen,
      ),
    );
    return (error: firstError, failed: failed);
  }

  /// Conserve les parties en échec pour le prochain lot (sans réessai
  /// automatique, pour ne pas boucler) et n'efface l'erreur affichée qu'une
  /// fois qu'il n'en reste plus aucune.
  void _applyPersistenceResult(
    ({Object? error, _PersistenceBatch failed}) result,
  ) {
    final failed = result.failed;
    final hasFailure =
        failed.saveClasses ||
        failed.saveRooms ||
        failed.viewMode != null ||
        failed.palette != null ||
        failed.localePreference != null ||
        failed.themePreference != null ||
        failed.tutorialSeen != null;
    _failedParts = hasFailure ? failed : null;
    final error = result.error;
    if (error == null) {
      _clearSaveError();
    } else {
      _setSaveError(error);
    }
  }

  /// Attend que l'état actuellement en attente soit écrit. Utile avant une
  /// opération qui dépend immédiatement des données persistées et dans les
  /// tests ; les interactions UI ordinaires restent non bloquantes.
  Future<void> flushPendingSaves() async {
    while (_persistenceLoop != null) {
      final loop = _persistenceLoop;
      if (loop != null) await loop;
    }
  }

  /// Retente une sauvegarde complète après une erreur signalée à l'écran.
  void retryPersistence() {
    _classesDirty = true;
    _savedRoomsDirty = true;
    _pendingStudentsViewMode = studentsViewMode.name;
    _pendingGenderColorPalette = genderColorPalette.name;
    _pendingLocalePreference = localePreference.name;
    _pendingThemePreference = themePreference.name;
    _pendingTutorialSeen = tutorialSeen;
    _startPersistence();
  }

  void dismissPersistenceMessage() {
    if (_saveError != null) {
      _saveError = null;
      _lastPersistenceError = null;
    } else {
      _loadNotice = null;
      _loadNoticeIsError = false;
      _loadNotices = const [];
    }
    notifyListeners();
  }

  void _setLoadNotice(
    RepositoryLoadStatus classStatus,
    RepositoryLoadStatus roomStatus,
  ) {
    final messages = <String>[];
    final notices = <PersistenceNotice>[];
    var hasError = false;

    void addStatus(
      RepositoryLoadStatus status,
      String label,
      PersistenceNotice recovered,
      PersistenceNotice corrupted,
    ) {
      switch (status) {
        case RepositoryLoadStatus.ok:
          break;
        case RepositoryLoadStatus.recoveredFromBackup:
          notices.add(recovered);
          messages.add(
            'Les données $label étaient endommagées. La dernière sauvegarde '
            'valide a été chargée.',
          );
          break;
        case RepositoryLoadStatus.corrupted:
          hasError = true;
          notices.add(corrupted);
          messages.add(
            'Les données $label sont illisibles et aucune sauvegarde valide '
            'n\'a été trouvée. Une copie de récupération a été conservée '
            'si possible.',
          );
          break;
      }
    }

    addStatus(
      classStatus,
      'des classes',
      PersistenceNotice.classesRecovered,
      PersistenceNotice.classesCorrupted,
    );
    addStatus(
      roomStatus,
      'des salles enregistrées',
      PersistenceNotice.roomsRecovered,
      PersistenceNotice.roomsCorrupted,
    );
    _loadNotice = messages.isEmpty ? null : messages.join('\n');
    _loadNotices = notices;
    _loadNoticeIsError = hasError;
  }

  void _setSaveError(Object error) {
    _lastPersistenceError = error;
    const message =
        'La sauvegarde locale a échoué. Vos dernières modifications ne sont '
        'peut-être pas enregistrées.';
    if (_saveError == message) return;
    _saveError = message;
    notifyListeners();
  }

  void _clearSaveError() {
    if (_saveError == null) return;
    _saveError = null;
    _lastPersistenceError = null;
    notifyListeners();
  }
}
