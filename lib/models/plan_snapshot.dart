/// Instantané immuable d'un plan de classe.
///
/// Les données sont conservées sous leur forme JSON afin que l'archive reste
/// indépendante des objets mutables de l'éditeur. Une restauration recrée donc
/// toujours de nouveaux modèles plutôt que de partager des références.
library;

import 'dart:convert';

import 'classroom.dart';

class PlanSnapshot {
  static const currentSchemaVersion = 1;

  final String id;
  final String label;
  final DateTime createdAt;
  final int schemaVersion;
  final Map<String, dynamic> classData;

  PlanSnapshot({
    required this.id,
    required this.label,
    required this.createdAt,
    this.schemaVersion = currentSchemaVersion,
    required Map<String, dynamic> classData,
  }) : classData = _deepCopy(classData);

  factory PlanSnapshot.fromClassGroup({
    required String id,
    required String label,
    required ClassGroup source,
    DateTime? createdAt,
  }) {
    final data = source.toJson()..remove('snapshots');
    return PlanSnapshot(
      id: id,
      label: label,
      createdAt: createdAt ?? DateTime.now(),
      classData: data,
    );
  }

  /// Reconstruit une classe indépendante, sans recopier l'historique de la
  /// classe d'origine dans la copie restaurée.
  ClassGroup toClassGroup({required String id, required String name}) {
    final data = _deepCopy(classData)
      ..['id'] = id
      ..['name'] = name
      ..['snapshots'] = <Object?>[];
    return ClassGroup.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
    'schemaVersion': schemaVersion,
    'classData': _deepCopy(classData),
  };

  factory PlanSnapshot.fromJson(Map<String, dynamic> json) {
    final rawData = json['classData'];
    if (rawData is! Map) {
      throw const FormatException('Instantané sans données de classe.');
    }
    final rawDate = json['createdAt'];
    final createdAt = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (createdAt == null) {
      throw const FormatException('Instantané avec date invalide.');
    }
    return PlanSnapshot(
      id: json['id'] as String,
      label: (json['label'] ?? '') as String,
      createdAt: createdAt,
      schemaVersion: (json['schemaVersion'] ?? currentSchemaVersion) as int,
      classData: rawData.cast<String, dynamic>(),
    );
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
      (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();
}
