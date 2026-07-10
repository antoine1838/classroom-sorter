/// Une classe : une salle, une liste d'élèves, des règles, des objectifs
/// d'équilibre, et le dernier plan généré.
library;

import 'room.dart';
import 'rule.dart';
import 'student.dart';

/// Objectifs souples appliqués à toute la classe (mixité / mélange).
class BalanceSettings {
  bool mixGender; // alterner filles / garçons dans le voisinage
  bool mixLevel; // alterner les niveaux dans le voisinage
  bool separateAgites; // éviter deux élèves agités côte à côte
  bool frontForPoorEyesight; // rapprocher du tableau les élèves à mauvaise vue

  BalanceSettings({
    this.mixGender = false,
    this.mixLevel = false,
    this.separateAgites = true,
    this.frontForPoorEyesight = false,
  });

  Map<String, dynamic> toJson() => {
        'mixGender': mixGender,
        'mixLevel': mixLevel,
        'separateAgites': separateAgites,
        'frontForPoorEyesight': frontForPoorEyesight,
      };

  factory BalanceSettings.fromJson(Map<String, dynamic> j) => BalanceSettings(
        mixGender: (j['mixGender'] ?? false) as bool,
        mixLevel: (j['mixLevel'] ?? false) as bool,
        separateAgites: (j['separateAgites'] ?? true) as bool,
        // Repli à false pour les anciennes sauvegardes (attribut jadis « dur »).
        frontForPoorEyesight: (j['frontForPoorEyesight'] ?? false) as bool,
      );
}

class ClassGroup {
  final String id;
  String name;
  Room room;
  List<Student> students;
  List<Rule> rules;
  BalanceSettings balance;

  /// Dernier plan généré : clé de place "r,c" -> id de l'élève.
  Map<String, String> assignment;

  ClassGroup({
    required this.id,
    this.name = '',
    Room? room,
    List<Student>? students,
    List<Rule>? rules,
    BalanceSettings? balance,
    Map<String, String>? assignment,
  })  : room = room ?? Room(),
        students = students ?? [],
        rules = rules ?? [],
        balance = balance ?? BalanceSettings(),
        assignment = assignment ?? {};

  Student? studentById(String? id) {
    if (id == null) return null;
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Supprime tout ce qui référence un élève supprimé (règles, plan).
  void purgeStudent(String studentId) {
    rules.removeWhere(
        (r) => r.studentAId == studentId || r.studentBId == studentId);
    assignment.removeWhere((seat, sid) => sid == studentId);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room.toJson(),
        'students': students.map((s) => s.toJson()).toList(),
        'rules': rules.map((r) => r.toJson()).toList(),
        'balance': balance.toJson(),
        'assignment': assignment,
      };

  factory ClassGroup.fromJson(Map<String, dynamic> j) => ClassGroup(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        room: Room.fromJson((j['room'] ?? const {}) as Map<String, dynamic>),
        students: ((j['students'] ?? const []) as List)
            .map((e) => Student.fromJson(e as Map<String, dynamic>))
            .toList(),
        rules: ((j['rules'] ?? const []) as List)
            .map((e) => Rule.fromJson(e as Map<String, dynamic>))
            .toList(),
        balance: BalanceSettings.fromJson(
            (j['balance'] ?? const {}) as Map<String, dynamic>),
        assignment: ((j['assignment'] ?? const {}) as Map)
            .map((k, v) => MapEntry(k as String, v as String)),
      );
}
