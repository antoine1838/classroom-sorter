// Chaque type de problème et chaque bilan d'équilibre produit par le moteur doit
// avoir un texte, en français comme en anglais. Les `switch` de
// plan_issue_localizations.dart se terminent par un cas par défaut qui rend une
// chaîne vide : un nouveau `PlanIssueKind` oublié s'afficherait sans texte, sans
// aucune erreur de compilation.
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/engine/plan_issue.dart';
import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/l10n/generated/app_localizations_en.dart';
import 'package:plandeclasse/l10n/generated/app_localizations_fr.dart';
import 'package:plandeclasse/l10n/plan_issue_localizations.dart';
import 'package:plandeclasse/models/student.dart';

/// Objectifs d'équilibre : leur texte dépend aussi de [BalanceNote.ok].
const _balanceKinds = {
  PlanIssueKind.sameGenderNeighbors,
  PlanIssueKind.sameLevelNeighbors,
  PlanIssueKind.restlessNeighbors,
  PlanIssueKind.poorEyesightAtBack,
  PlanIssueKind.tallBlocksShort,
};

/// Problèmes qui nomment les deux élèves d'une paire.
const _pairKinds = {
  PlanIssueKind.separateStudents,
  PlanIssueKind.studentsNotTogether,
};

/// Problèmes qui ne nomment personne : un compte, ou un objectif de classe.
final _anonymousKinds = {PlanIssueKind.unplacedStudents, ..._balanceKinds};

final _students = {
  'ada': Student(id: 'ada', firstName: 'Ada', lastName: 'Lovelace'),
  'lin': Student(id: 'lin', firstName: 'Linus', lastName: 'Torvalds'),
};

Student? _byId(String id) => _students[id];

PlanIssue _issue(PlanIssueKind kind, {List<String>? studentIds}) => PlanIssue(
  severity: IssueSeverity.soft,
  kind: kind,
  count: 3,
  studentIds: studentIds ?? const ['ada', 'lin'],
);

void main() {
  final locales = <String, AppLocalizations>{
    'fr': AppLocalizationsFr(),
    'en': AppLocalizationsEn(),
  };

  for (final MapEntry(key: locale, value: l10n) in locales.entries) {
    group('textes des problèmes ($locale)', () {
      test('chaque type de problème a un texte non vide', () {
        for (final kind in PlanIssueKind.values) {
          final text = localizedPlanIssue(_issue(kind), l10n, _byId);

          expect(text.trim(), isNotEmpty, reason: '$kind');
        }
      });

      test('deux types de problèmes ne partagent jamais le même texte', () {
        final texts = {
          for (final kind in PlanIssueKind.values)
            kind: localizedPlanIssue(_issue(kind), l10n, _byId),
        };

        expect(texts.values.toSet(), hasLength(PlanIssueKind.values.length));
      });

      test('le problème nomme le ou les élèves concernés', () {
        for (final kind in PlanIssueKind.values) {
          if (_anonymousKinds.contains(kind)) continue;
          final text = localizedPlanIssue(_issue(kind), l10n, _byId);

          expect(text, contains('Ada Lovelace'), reason: '$kind');
          if (_pairKinds.contains(kind)) {
            expect(text, contains('Linus Torvalds'), reason: '$kind');
          }
        }
      });

      test('les élèves non placés sont comptés dans le texte', () {
        final text = localizedPlanIssue(
          _issue(PlanIssueKind.unplacedStudents),
          l10n,
          _byId,
        );

        expect(text, contains('3'));
      });

      test('un élève introuvable ou absent est remplacé par un point d\'interrogation', () {
        final unknown = localizedPlanIssue(
          _issue(PlanIssueKind.studentNotNearBoard, studentIds: ['inconnu']),
          l10n,
          _byId,
        );
        final missing = localizedPlanIssue(
          _issue(PlanIssueKind.studentNotNearBoard, studentIds: const []),
          l10n,
          _byId,
        );
        final secondMissing = localizedPlanIssue(
          _issue(PlanIssueKind.separateStudents, studentIds: ['ada']),
          l10n,
          _byId,
        );

        expect(unknown, contains('?'));
        expect(missing, contains('?'));
        expect(secondMissing, allOf(contains('Ada Lovelace'), contains('?')));
      });
    });

    group('textes des bilans d\'équilibre ($locale)', () {
      BalanceNote note(PlanIssueKind kind, {required bool ok}) =>
          BalanceNote(ok: ok, kind: kind, count: 2);

      test('chaque objectif a un texte atteint et un texte non atteint', () {
        for (final kind in _balanceKinds) {
          final reached = localizedBalanceNote(note(kind, ok: true), l10n);
          final missed = localizedBalanceNote(note(kind, ok: false), l10n);

          expect(reached.trim(), isNotEmpty, reason: '$kind atteint');
          expect(missed.trim(), isNotEmpty, reason: '$kind non atteint');
          expect(reached, isNot(missed), reason: '$kind');
        }
      });

      test('le texte non atteint donne le nombre de cas', () {
        for (final kind in _balanceKinds) {
          final missed = localizedBalanceNote(note(kind, ok: false), l10n);

          expect(missed, contains('2'), reason: '$kind');
        }
      });

      test(
        'un type qui n\'est pas un objectif d\'équilibre n\'a pas de bilan',
        () {
          expect(
            localizedBalanceNote(
              note(PlanIssueKind.separateStudents, ok: true),
              l10n,
            ),
            isEmpty,
          );
        },
      );
    });
  }
}
