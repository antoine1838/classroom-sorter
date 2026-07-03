/// Une règle/contrainte d'affectation.
///
/// - [fixedSeat]    : un élève doit occuper une place précise.
/// - [frontZone]    : un élève doit être dans les premiers rangs.
/// - [separate]     : deux élèves ne doivent PAS être côte à côte.
/// - [keepTogether] : deux élèves doivent être côte à côte.
///
/// Chaque règle est « dure » (obligatoire) ou « souple » (préférence).
library;

enum RuleType { fixedSeat, frontZone, separate, keepTogether }

extension RuleTypeInfo on RuleType {
  String get label => switch (this) {
        RuleType.fixedSeat => 'Place imposée',
        RuleType.frontZone => 'Doit être devant',
        RuleType.separate => 'Séparer',
        RuleType.keepTogether => 'Rapprocher',
      };

  String get description => switch (this) {
        RuleType.fixedSeat => 'Assigner un élève à une place précise',
        RuleType.frontZone =>
          'Placer un élève dans les premiers rangs (vue, audition, PMR…)',
        RuleType.separate => "Empêcher deux élèves d'être côte à côte",
        RuleType.keepTogether => "Garder deux élèves l'un à côté de l'autre",
      };

  /// Nombre d'élèves concernés (1 ou 2).
  bool get needsSecondStudent =>
      this == RuleType.separate || this == RuleType.keepTogether;
}

class Rule {
  final String id;
  RuleType type;
  String studentAId;
  String? studentBId; // pour separate / keepTogether
  int? seatRow; // pour fixedSeat
  int? seatCol; // pour fixedSeat
  int frontRows; // pour frontZone : dans les N premiers rangs
  bool hard; // true = obligatoire, false = préférence

  Rule({
    required this.id,
    required this.type,
    required this.studentAId,
    this.studentBId,
    this.seatRow,
    this.seatCol,
    this.frontRows = 1,
    this.hard = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'studentAId': studentAId,
        'studentBId': studentBId,
        'seatRow': seatRow,
        'seatCol': seatCol,
        'frontRows': frontRows,
        'hard': hard,
      };

  factory Rule.fromJson(Map<String, dynamic> j) => Rule(
        id: j['id'] as String,
        type: RuleType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => RuleType.separate,
        ),
        studentAId: j['studentAId'] as String,
        studentBId: j['studentBId'] as String?,
        seatRow: j['seatRow'] as int?,
        seatCol: j['seatCol'] as int?,
        frontRows: (j['frontRows'] ?? 1) as int,
        hard: (j['hard'] ?? true) as bool,
      );
}
