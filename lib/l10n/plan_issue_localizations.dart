/// Display-layer translations for issue identifiers produced by the engine.
library;

import '../engine/plan_issue.dart';
import '../models/student.dart';
import 'generated/app_localizations.dart';

String localizedPlanIssue(
  PlanIssue issue,
  AppLocalizations l10n,
  Student? Function(String id) studentById,
) {
  String nameAt(int index) => issue.studentIds.length > index
      ? (studentById(issue.studentIds[index])?.fullName ?? '?')
      : '?';

  return switch (issue.kind) {
    PlanIssueKind.fixedSeatMissing => l10n.planIssueFixedSeatMissing(nameAt(0)),
    PlanIssueKind.fixedSeatOccupied => l10n.planIssueFixedSeatOccupied(
      nameAt(0),
    ),
    PlanIssueKind.multipleFixedSeats => l10n.planIssueMultipleFixedSeats(
      nameAt(0),
    ),
    PlanIssueKind.separateStudents => l10n.planIssueSeparateStudents(
      nameAt(0),
      nameAt(1),
    ),
    PlanIssueKind.studentsNotTogether => l10n.planIssueStudentsNotTogether(
      nameAt(0),
      nameAt(1),
    ),
    PlanIssueKind.studentNotNearBoard => l10n.planIssueStudentNotNearBoard(
      nameAt(0),
    ),
    PlanIssueKind.studentNotAtFixedSeat => l10n.planIssueStudentNotAtFixedSeat(
      nameAt(0),
    ),
    PlanIssueKind.unplacedStudents => l10n.planIssueUnplacedStudents(
      issue.count,
    ),
    _ => localizedBalanceIssue(
      kind: issue.kind,
      ok: false,
      count: issue.count,
      l10n: l10n,
    ),
  };
}

String localizedBalanceNote(BalanceNote note, AppLocalizations l10n) =>
    localizedBalanceIssue(
      kind: note.kind,
      ok: note.ok,
      count: note.count,
      l10n: l10n,
    );

String localizedBalanceIssue({
  required PlanIssueKind kind,
  required bool ok,
  required int count,
  required AppLocalizations l10n,
}) => switch (kind) {
  PlanIssueKind.sameGenderNeighbors =>
    ok ? l10n.balanceSameGenderOk : l10n.balanceSameGenderIssue(count),
  PlanIssueKind.sameLevelNeighbors =>
    ok ? l10n.balanceSameLevelOk : l10n.balanceSameLevelIssue(count),
  PlanIssueKind.restlessNeighbors =>
    ok ? l10n.balanceRestlessOk : l10n.balanceRestlessIssue(count),
  PlanIssueKind.poorEyesightAtBack =>
    ok ? l10n.balancePoorEyesightOk : l10n.balancePoorEyesightIssue(count),
  PlanIssueKind.tallBlocksShort =>
    ok
        ? l10n.balanceTallBlocksShortOk
        : l10n.balanceTallBlocksShortIssue(count),
  _ => '',
};
