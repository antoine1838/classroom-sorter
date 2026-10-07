/// Problèmes rapportés sur un plan, rattachés aux élèves concernés.
///
/// Le moteur ne se contente pas d'un libellé lisible : il retient QUI est
/// concerné, pour que le plan puisse marquer les places fautives et en donner
/// les motifs.
library;

/// Gravité d'un problème, qui détermine son rendu sur le plan.
enum IssueSeverity {
  /// Contrainte dure non respectée : le plan est invalide.
  hard,

  /// Contrainte souple ou objectif d'équilibre non atteint : le plan est
  /// utilisable mais perfectible.
  soft,
}

/// Identifiant stable d'un problème de plan.
///
/// Les textes associés sont choisis dans la couche d'affichage afin que le
/// moteur reste indépendant de Flutter et de la langue active.
enum PlanIssueKind {
  fixedSeatMissing,
  fixedSeatOccupied,
  multipleFixedSeats,
  separateStudents,
  studentsNotTogether,
  studentNotNearBoard,
  studentNotAtFixedSeat,
  unplacedStudents,
  sameGenderNeighbors,
  sameLevelNeighbors,
  restlessNeighbors,
  poorEyesightAtBack,
  tallBlocksShort,
}

/// Un problème rapporté, avec les élèves qu'il concerne.
class PlanIssue {
  final IssueSeverity severity;

  /// Nature du problème, localisée par la couche d'affichage.
  final PlanIssueKind kind;

  /// Quantité concernée quand elle est utile au message (paires ou élèves).
  final int count;

  /// Élèves concernés. Vide quand le problème ne désigne personne en
  /// particulier — « la salle manque de places » n'a aucune place à marquer.
  final List<String> studentIds;

  const PlanIssue({
    required this.severity,
    required this.kind,
    this.count = 0,
    this.studentIds = const [],
  });

  bool get isHard => severity == IssueSeverity.hard;
}

/// Bilan d'un objectif d'équilibre activé.
class BalanceNote {
  /// Objectif atteint.
  final bool ok;

  /// Nature de l'objectif, localisée par la couche d'affichage.
  final PlanIssueKind kind;

  /// Nombre de paires ou d'élèves qui empêchent de satisfaire l'objectif.
  final int count;

  /// Élèves concernés quand [ok] est faux ; vide sinon.
  final List<String> studentIds;

  const BalanceNote({
    required this.ok,
    required this.kind,
    this.count = 0,
    this.studentIds = const [],
  });
}
