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

class AppState extends ChangeNotifier {
  final Repository _repo = Repository();

  List<ClassGroup> classes = [];
  List<SavedRoom> savedRooms = [];
  bool loading = true;
  StudentsViewMode studentsViewMode = StudentsViewMode.complete;

  Future<void> init() async {
    classes = await _repo.load();
    savedRooms = await _repo.loadSavedRooms();
    final rawMode = await _repo.loadStudentsViewMode();
    if (rawMode == StudentsViewMode.compact.name) {
      studentsViewMode = StudentsViewMode.compact;
    }
    loading = false;
    notifyListeners();
  }

  void setStudentsViewMode(StudentsViewMode mode) {
    if (studentsViewMode == mode) return;
    studentsViewMode = mode;
    notifyListeners();
    _repo.saveStudentsViewMode(mode.name);
  }

  Future<void> _persist() => _repo.save(classes);

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
    notifyListeners();
    _persist();
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

  Future<void> _persistSavedRooms() => _repo.saveSavedRooms(savedRooms);

  void _touchSavedRooms() {
    notifyListeners();
    _persistSavedRooms();
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
}
