/// Un élève et ses attributs utiles à l'affectation.
library;

enum Gender { fille, garcon, autre }

enum Level { faible, moyen, fort, nonDefini }

enum Energy { calme, agite, nonDefini }

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
        Level.nonDefini => 'Non défini',
      };
}

extension EnergyLabel on Energy {
  String get label => switch (this) {
        Energy.calme => 'Calme',
        Energy.agite => 'Agité',
        Energy.nonDefini => 'Non défini',
      };
}

class Student {
  final String id;
  String firstName;
  String lastName;
  Gender gender;
  Level level;
  Energy energy;

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
    this.level = Level.nonDefini,
    this.energy = Energy.nonDefini,
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
          orElse: () => Level.nonDefini,
        ),
        energy: Energy.values.firstWhere(
          // Rétrocompat : lit aussi l'ancienne clé « temperament ».
          (t) => t.name == (j['energy'] ?? j['temperament']),
          orElse: () => Energy.nonDefini,
        ),
        poorEyesight: (j['poorEyesight'] ?? false) as bool,
        notes: (j['notes'] ?? '') as String,
      );
}
