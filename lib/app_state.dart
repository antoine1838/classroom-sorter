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
  bool loading = true;
  StudentsViewMode studentsViewMode = StudentsViewMode.complete;

  Future<void> init() async {
    classes = await _repo.load();
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
}
