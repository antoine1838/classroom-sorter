/// Un élève et ses attributs utiles à l'affectation.
library;

enum Gender { fille, garcon, autre }

enum Level { faible, moyen, fort }

enum Energy { calme, modere, agite }

// Nommé StudentSize (et non « Size ») pour ne pas entrer en conflit avec
// dart:ui/Flutter Size, importé partout via package:flutter/material.dart.
enum StudentSize { petit, moyen, grand }

extension GenderLabel on Gender {
  String get label => switch (this) {
        Gender.fille => 'Fille',
        Gender.garcon => 'Garçon',
        Gender.autre => 'Non précisé',
      };
}

extension LevelLabel on Level {
  String get label => switch (this) {
        Level.faible => 'Faible',
        Level.moyen => 'Moyen',
        Level.fort => 'Fort',
      };
}

extension EnergyLabel on Energy {
  String get label => switch (this) {
        Energy.calme => 'Calme',
        Energy.modere => 'Modéré',
        Energy.agite => 'Agité',
      };
}

extension StudentSizeLabel on StudentSize {
  String get label => switch (this) {
        StudentSize.petit => 'Petit',
        StudentSize.moyen => 'Moyen',
        StudentSize.grand => 'Grand',
      };
}

class Student {
  final String id;
  String firstName;
  String lastName;
  Gender gender;
  Level level;
  Energy energy;
  StudentSize size;

  /// Mauvaise vue : à rapprocher du tableau (moitié avant) si l'objectif
  /// d'équilibre « frontForPoorEyesight » est activé. Préférence souple ;
  /// ce n'est plus une contrainte dure.
  bool poorEyesight;

  String notes;

  Student({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.gender = Gender.autre,
    this.level = Level.moyen,
    this.energy = Energy.modere,
    this.size = StudentSize.moyen,
    this.poorEyesight = false,
    this.notes = '',
  });

  /// Nom affichable, jamais vide.
  String get fullName {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? 'Élève sans nom' : n;
  }

  /// Initiales pour l'affichage compact sur une place.
  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    final s = ('${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}').toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'gender': gender.name,
        'level': level.name,
        'energy': energy.name,
        'size': size.name,
        'poorEyesight': poorEyesight,
        'notes': notes,
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String,
        firstName: (j['firstName'] ?? '') as String,
        lastName: (j['lastName'] ?? '') as String,
        gender: Gender.values.firstWhere(
          (g) => g.name == j['gender'],
          orElse: () => Gender.autre,
        ),
        level: Level.values.firstWhere(
          (l) => l.name == j['level'],
          orElse: () => Level.moyen,
        ),
        energy: Energy.values.firstWhere(
          // Rétrocompat : lit aussi l'ancienne clé « temperament ».
          (t) => t.name == (j['energy'] ?? j['temperament']),
          orElse: () => Energy.modere,
        ),
        // Absent des sauvegardes antérieures à ce critère : repli sur Moyen.
        size: StudentSize.values.firstWhere(
          (t) => t.name == j['size'],
          orElse: () => StudentSize.moyen,
        ),
        poorEyesight: (j['poorEyesight'] ?? false) as bool,
        notes: (j['notes'] ?? '') as String,
      );
}
