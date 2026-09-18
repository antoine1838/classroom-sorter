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
import 'package:flutter/services.dart' show rootBundle;

import 'data/repository.dart';
import 'models/classroom.dart';
import 'models/room.dart';
import 'models/saved_room.dart';
import 'models/student.dart' show GenderColorPalette;

/// Classe d'exemple prête à l'emploi, pour découvrir l'appli ou refaire des
/// captures d'écran sans ressaisir des données à la main.
const String demoClassAsset = 'assets/demo/demo_class_6emeb.json';

/// Identifiant unique simple (horodatage + aléatoire), sans dépendance externe.
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${Random().nextInt(1 << 32).toRadixString(36)}';

/// Vue de l'onglet Élèves : [complete] (une colonne par valeur possible, à
/// cocher) ou [compact] (une colonne par attribut, tap pour cycler).
enum StudentsViewMode { complete, compact }

typedef _PersistenceBatch = ({
  bool saveClasses,
  bool saveRooms,
  String? viewMode,
  String? palette,
});

class AppState extends ChangeNotifier {
  final Repository _repo;

  AppState({Repository? repository}) : _repo = repository ?? Repository();

  List<ClassGroup> classes = [];
  List<SavedRoom> savedRooms = [];
  bool loading = true;
  StudentsViewMode studentsViewMode = StudentsViewMode.complete;
  GenderColorPalette genderColorPalette = GenderColorPalette.tealCorail;

  String? _loadNotice;
  bool _loadNoticeIsError = false;
  String? _saveError;
  Object? _lastPersistenceError;

  bool _classesDirty = false;
  bool _savedRoomsDirty = false;
  String? _pendingStudentsViewMode;
  String? _pendingGenderColorPalette;
  Future<void>? _persistenceLoop;

  String? get persistenceMessage => _saveError ?? _loadNotice;
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
    final raw = await rootBundle.loadString(demoClassAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final c = ClassGroup.fromJson({...json, 'id': newId()});
    classes.add(c);
    touch();
    return c;
  }

  void deleteClass(ClassGroup c) {
    classes.remove(c);
    touch();
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

  bool savedRoomNameExists(String name, {String? excludingId}) => savedRooms
      .any((r) => r.name == name && r.id != excludingId);

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
      _pendingGenderColorPalette != null;

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
        final error = await _persistBatch(_takePersistenceBatch());
        _applyPersistenceResult(error);
      }
    } finally {
      _persistenceLoop = null;
      // Défensif : une nouvelle mutation peut avoir été notifiée pendant la
      // finalisation de la boucle.
      if (_hasPendingPersistence) _startPersistence();
    }
  }

  _PersistenceBatch _takePersistenceBatch() {
    final batch = (
      saveClasses: _classesDirty,
      saveRooms: _savedRoomsDirty,
      viewMode: _pendingStudentsViewMode,
      palette: _pendingGenderColorPalette,
    );
    _classesDirty = false;
    _savedRoomsDirty = false;
    _pendingStudentsViewMode = null;
    _pendingGenderColorPalette = null;
    return batch;
  }

  Future<Object?> _persistBatch(_PersistenceBatch batch) async {
    Object? firstError;
    Future<void> attempt(Future<void> Function() save) async {
      try {
        await save();
      } catch (error) {
        firstError ??= error;
      }
    }

    if (batch.saveClasses) {
      await attempt(() => _repo.save(classes));
    }
    if (batch.saveRooms) {
      await attempt(() => _repo.saveSavedRooms(savedRooms));
    }
    if (batch.viewMode != null) {
      await attempt(() => _repo.saveStudentsViewMode(batch.viewMode!));
    }
    if (batch.palette != null) {
      await attempt(() => _repo.saveGenderColorPalette(batch.palette!));
    }
    return firstError;
  }

  void _applyPersistenceResult(Object? error) {
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
    _startPersistence();
  }

  void dismissPersistenceMessage() {
    if (_saveError != null) {
      _saveError = null;
      _lastPersistenceError = null;
    } else {
      _loadNotice = null;
      _loadNoticeIsError = false;
    }
    notifyListeners();
  }

  void _setLoadNotice(
    RepositoryLoadStatus classStatus,
    RepositoryLoadStatus roomStatus,
  ) {
    final messages = <String>[];
    var hasError = false;

    void addStatus(RepositoryLoadStatus status, String label) {
      switch (status) {
        case RepositoryLoadStatus.ok:
          break;
        case RepositoryLoadStatus.recoveredFromBackup:
          messages.add(
              'Les données $label étaient endommagées. La dernière sauvegarde '
              'valide a été chargée.');
          break;
        case RepositoryLoadStatus.corrupted:
          hasError = true;
          messages.add(
              'Les données $label sont illisibles et aucune sauvegarde valide '
              'n\'a été trouvée. Une copie de récupération a été conservée '
              'si possible.');
          break;
      }
    }

    addStatus(classStatus, 'des classes');
    addStatus(roomStatus, 'des salles enregistrées');
    _loadNotice = messages.isEmpty ? null : messages.join('\n');
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
