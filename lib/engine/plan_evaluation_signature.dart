import 'dart:convert';

import '../models/classroom.dart';

/// Empreinte des données dont dépend un [PlanResult].
///
/// Le nom de la classe et les préférences globales d'affichage sont
/// volontairement absents : ils peuvent changer sans rendre le rapport faux.
String planEvaluationSignature(ClassGroup cls) {
  final assignment = cls.assignment.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return jsonEncode({
    'room': cls.room.toJson(),
    'students': [for (final student in cls.students) student.toJson()],
    'rules': [for (final rule in cls.rules) rule.toJson()],
    'balance': cls.balance.toJson(),
    'assignment': {for (final entry in assignment) entry.key: entry.value},
  });
}
