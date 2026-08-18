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

/// Un problème rapporté, avec les élèves qu'il concerne.
class PlanIssue {
  final IssueSeverity severity;

  /// Libellé lisible, tel qu'affiché dans le rapport.
  final String label;

  /// Élèves concernés. Vide quand le problème ne désigne personne en
  /// particulier — « la salle manque de places » n'a aucune place à marquer.
  final List<String> studentIds;

  const PlanIssue({
    required this.severity,
    required this.label,
    this.studentIds = const [],
  });

  bool get isHard => severity == IssueSeverity.hard;
}

/// Bilan d'un objectif d'équilibre activé.
class BalanceNote {
  /// Objectif atteint.
  final bool ok;

  final String label;

  /// Élèves concernés quand [ok] est faux ; vide sinon.
  final List<String> studentIds;

  const BalanceNote({
    required this.ok,
    required this.label,
    this.studentIds = const [],
  });
}
