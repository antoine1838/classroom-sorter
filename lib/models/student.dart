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

/// Étiquettes courtes et, autant que possible, NON AMBIGUËS pour le plan.
///
/// Deux élèves peuvent partager leurs initiales — « Marie Dupont » et « Marc
/// Durand » donnent tous deux `MD`, ce qui ne désigne personne. On allonge donc
/// le nom de famille lettre à lettre pour les seuls groupes en conflit :
/// `M.Du` / `M.Da`, puis `M.Dup` / `M.Dur` s'il le faut.
///
/// En cas d'homonymie complète on s'arrête : deux « Marie Dupont » sont
/// réellement indiscernables sur une case, et c'est le détail de l'élève qui
/// tranchera. Renvoie `id de l'élève -> étiquette`.
Map<String, String> disambiguatedInitials(List<Student> students) {
  final labels = <String, String>{
    for (final s in students) s.id: s.initials,
  };

  // Groupe les élèves par étiquette, et n'allonge que là où ça collide.
  final byLabel = <String, List<Student>>{};
  for (final s in students) {
    (byLabel[labels[s.id]!] ??= []).add(s);
  }

  for (final group in byLabel.values) {
    if (group.length < 2) continue;
    for (var keep = 2;; keep++) {
      final attempt = {for (final s in group) s.id: _longerLabel(s, keep)};
      final distinct = attempt.values.toSet().length == group.length;
      // Plus rien à allonger : les noms restants sont identiques.
      final exhausted = group.every((s) => s.lastName.trim().length <= keep);
      if (distinct || exhausted) {
        labels.addAll(attempt);
        break;
      }
    }
  }

  return labels;
}

/// Initiale du prénom + [keep] premières lettres du nom : `M.Du`.
String _longerLabel(Student s, int keep) {
  final f = s.firstName.trim();
  final l = s.lastName.trim();
  if (l.isEmpty) return s.initials;
  final head = l.length <= keep ? l : l.substring(0, keep);
  final capitalised = head[0].toUpperCase() + head.substring(1).toLowerCase();
  if (f.isEmpty) return capitalised;
  return '${f[0].toUpperCase()}.$capitalised';
}

/// Trie par nom de famille puis prénom, insensible à la casse.
int compareStudentsByName(Student a, Student b) {
  final byLast = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
  return byLast != 0
      ? byLast
      : a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
}
