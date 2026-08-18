// Vérifie que le moteur ne se contente pas d'un libellé lisible mais retient
// QUI est concerné par chaque problème — ce dont le plan a besoin pour marquer
// les places fautives (issue #8).
//
// On passe par `evaluate()` avec une affectation fabriquée à la main plutôt que
// par `generate()` : le recuit cherche justement à éviter les violations, donc
// il faudrait dépendre d'une graine pour en obtenir une. Ici le plan fautif est
// posé explicitement, et le test dit exactement ce qu'il vérifie.
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/engine/plan_issue.dart';
import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';

ClassGroup _cls({
  required List<Student> students,
  List<Rule> rules = const [],
  Room? room,
  BalanceSettings? balance,
  Map<String, String>? assignment,
}) =>
    ClassGroup(
      id: 'c',
      name: 'Test',
      room: room ?? Room(rows: 4, cols: 4),
      students: students,
      rules: rules,
      balance: balance,
      assignment: assignment,
    );

Student _s(String id, {
  Gender gender = Gender.autre,
  Level level = Level.moyen,
  Energy energy = Energy.modere,
  StudentSize size = StudentSize.moyen,
  bool poorEyesight = false,
}) =>
    Student(
      id: id,
      firstName: id.toUpperCase(),
      lastName: 'Nom$id',
      gender: gender,
      level: level,
      energy: energy,
      size: size,
      poorEyesight: poorEyesight,
    );

/// Élèves concernés par les problèmes de [res], sans doublons.
Set<String> _flagged(PlanResult res) => res.flaggedStudentIds;

void main() {
  group('règles — les élèves concernés remontent', () {
    test('« séparer » dure : les DEUX élèves voisins sont marqués', () {
      final cls = _cls(
        students: [_s('a'), _s('b'), _s('c')],
        rules: [
          Rule(
              id: 'r',
              type: RuleType.separate,
              studentAId: 'a',
              studentBId: 'b',
              hard: true),
        ],
        // a et b côte à côte au premier rang : la règle est violée.
        assignment: {
          Room.keyOf(0, 0): 'a',
          Room.keyOf(0, 1): 'b',
          Room.keyOf(2, 3): 'c',
        },
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a', 'b'});
      expect(res.severityFor('a'), IssueSeverity.hard);
      expect(res.severityFor('b'), IssueSeverity.hard);
      expect(res.severityFor('c'), isNull,
          reason: 'C n\'est concerné par rien');
      expect(res.reasonsFor('a').single, contains('à séparer'));
      expect(res.violations, hasLength(1),
          reason: 'le libellé reste dérivé des problèmes');
    });

    test('« séparer » souple : marquage souple, pas dur', () {
      final cls = _cls(
        students: [_s('a'), _s('b')],
        rules: [
          Rule(
              id: 'r',
              type: RuleType.separate,
              studentAId: 'a',
              studentBId: 'b',
              hard: false),
        ],
        assignment: {Room.keyOf(0, 0): 'a', Room.keyOf(0, 1): 'b'},
      );

      final res = SeatingEngine(cls).evaluate();

      expect(res.severityFor('a'), IssueSeverity.soft);
      expect(res.violations, isEmpty);
      expect(res.warnings, hasLength(1));
    });

    test('« rapprocher » : les deux élèves éloignés sont marqués', () {
      final cls = _cls(
        students: [_s('a'), _s('b')],
        rules: [
          Rule(
              id: 'r',
              type: RuleType.keepTogether,
              studentAId: 'a',
              studentBId: 'b',
              hard: true),
        ],
        // Aux deux coins opposés : la règle est violée.
        assignment: {Room.keyOf(0, 0): 'a', Room.keyOf(3, 3): 'b'},
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a', 'b'});
      expect(res.reasonsFor('b').single, contains('ne sont pas voisins'));
    });

    test('« devant » : seul l\'élève visé est marqué', () {
      final cls = _cls(
        students: [_s('a'), _s('b')],
        rules: [
          Rule(
              id: 'r',
              type: RuleType.frontZone,
              studentAId: 'a',
              frontRows: 1,
              hard: true),
        ],
        // a au dernier rang : la règle est violée. b n'est pas concerné.
        assignment: {Room.keyOf(3, 0): 'a', Room.keyOf(0, 0): 'b'},
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a'},
          reason: 'une règle à un seul élève ne doit pas marquer le voisin');
      expect(res.reasonsFor('a').single, contains('premiers rangs'));
    });

    test('« place imposée » non honorée : l\'élève est marqué', () {
      final cls = _cls(
        students: [_s('a'), _s('b')],
        rules: [
          Rule(
            id: 'r',
            type: RuleType.fixedSeat,
            studentAId: 'a',
            seatRow: 0,
            seatCol: 2,
            hard: true,
          ),
        ],
        assignment: {Room.keyOf(1, 1): 'a', Room.keyOf(0, 2): 'b'},
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a'});
      expect(res.severityFor('a'), IssueSeverity.hard);
      expect(res.reasonsFor('a').single, contains('place imposée'));
    });

    test('deux places imposées identiques : le second élève est marqué', () {
      final cls = _cls(
        students: [_s('a'), _s('b')],
        rules: [
          Rule(
              id: 'r1',
              type: RuleType.fixedSeat,
              studentAId: 'a',
              seatRow: 0,
              seatCol: 0),
          Rule(
              id: 'r2',
              type: RuleType.fixedSeat,
              studentAId: 'b',
              seatRow: 0,
              seatCol: 0),
        ],
      );

      final res = SeatingEngine(cls, seed: 1).generate();

      expect(res.severityFor('b'), IssueSeverity.hard,
          reason: 'B est celui dont la place imposée était déjà prise');
      expect(res.reasonsFor('b').single, contains('déjà occupée'));
    });

    test('plan correct : aucun élève marqué', () {
      final cls = _cls(
        students: [_s('a'), _s('b')],
        rules: [
          Rule(
              id: 'r',
              type: RuleType.separate,
              studentAId: 'a',
              studentBId: 'b',
              hard: true),
        ],
        assignment: {Room.keyOf(0, 0): 'a', Room.keyOf(3, 3): 'b'},
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), isEmpty);
      expect(res.severityFor('a'), isNull);
      expect(res.reasonsFor('a'), isEmpty);
      expect(res.hasHardViolations, isFalse);
    });

    test('élèves non placés : personne n\'est marqué (problème de salle)', () {
      final cls = _cls(
        room: Room(rows: 1, cols: 2),
        students: [_s('a'), _s('b'), _s('c')],
      );

      final res = SeatingEngine(cls, seed: 1).generate();

      expect(res.unplacedStudentIds, hasLength(1));
      expect(res.warnings, isNotEmpty, reason: 'le rapport doit le dire');
      expect(_flagged(res), isEmpty,
          reason: 'un élève non placé n\'occupe aucune place à marquer');
    });

    test('dur et souple sur le même élève : le dur gagne et passe devant', () {
      final cls = _cls(
        students: [_s('a'), _s('b'), _s('c')],
        rules: [
          // Souple : a doit être devant, il ne l'est pas.
          Rule(
              id: 'r1',
              type: RuleType.frontZone,
              studentAId: 'a',
              frontRows: 1,
              hard: false),
          // Dure : a et b doivent être séparés, ils sont voisins.
          Rule(
              id: 'r2',
              type: RuleType.separate,
              studentAId: 'a',
              studentBId: 'b',
              hard: true),
        ],
        assignment: {
          Room.keyOf(3, 0): 'a',
          Room.keyOf(3, 1): 'b',
          Room.keyOf(0, 0): 'c',
        },
      );

      final res = SeatingEngine(cls).evaluate();

      expect(res.severityFor('a'), IssueSeverity.hard);
      expect(res.severityFor('b'), IssueSeverity.hard);
      final reasons = res.reasonsFor('a');
      expect(reasons, hasLength(2));
      expect(reasons.first, contains('à séparer'),
          reason: 'les motifs les plus graves passent devant');
    });
  });

  group('objectifs d\'équilibre — les élèves concernés remontent', () {
    test('agités voisins : les deux sont marqués en souple', () {
      final cls = _cls(
        room: Room(rows: 1, cols: 4),
        students: [
          _s('a', energy: Energy.agite),
          _s('b', energy: Energy.agite),
          _s('c'),
        ],
        balance: BalanceSettings(separateAgites: true),
        assignment: {
          Room.keyOf(0, 0): 'a',
          Room.keyOf(0, 1): 'b',
          Room.keyOf(0, 3): 'c',
        },
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a', 'b'});
      expect(res.severityFor('a'), IssueSeverity.soft);
      expect(res.reasonsFor('a').single, contains('agités'));
      final note = res.balance.firstWhere((n) => n.label.contains('agités'));
      expect(note.ok, isFalse);
      expect(note.studentIds.toSet(), {'a', 'b'});
    });

    test('mixité des genres : la paire de même genre est marquée', () {
      final cls = _cls(
        room: Room(rows: 1, cols: 4),
        students: [
          _s('a', gender: Gender.fille),
          _s('b', gender: Gender.fille),
          _s('c', gender: Gender.garcon),
        ],
        balance: BalanceSettings(mixGender: true),
        assignment: {
          Room.keyOf(0, 0): 'a',
          Room.keyOf(0, 1): 'b',
          Room.keyOf(0, 3): 'c',
        },
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a', 'b'});
      expect(res.severityFor('c'), isNull);
    });

    test('mélange des niveaux : la paire de même niveau est marquée', () {
      final cls = _cls(
        room: Room(rows: 1, cols: 4),
        students: [
          _s('a', level: Level.fort),
          _s('b', level: Level.fort),
          _s('c', level: Level.moyen),
        ],
        balance: BalanceSettings(mixLevel: true),
        assignment: {
          Room.keyOf(0, 0): 'a',
          Room.keyOf(0, 1): 'b',
          Room.keyOf(0, 3): 'c',
        },
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a', 'b'});
    });

    test('mauvaise vue : seul l\'élève trop en arrière est marqué', () {
      final cls = _cls(
        room: Room(rows: 4, cols: 2),
        students: [
          _s('a', poorEyesight: true),
          _s('b', poorEyesight: true),
          _s('c'),
        ],
        balance: BalanceSettings(frontForPoorEyesight: true),
        // Moitié avant = rangs 0 et 1. a est au rang 3, b au rang 0.
        assignment: {
          Room.keyOf(3, 0): 'a',
          Room.keyOf(0, 0): 'b',
          Room.keyOf(2, 1): 'c',
        },
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a'},
          reason: 'b est déjà dans la moitié avant, c n\'a pas ce critère');
      expect(res.reasonsFor('a').single, contains('Mauvaise vue'));
    });

    test('grand devant petit : les deux élèves de la paire sont marqués', () {
      final cls = _cls(
        room: Room(rows: 3, cols: 2),
        students: [
          _s('a', size: StudentSize.grand),
          _s('b', size: StudentSize.petit),
          _s('c'),
        ],
        balance: BalanceSettings(avoidTallInFrontOfShort: true),
        // a (grand) au rang 0, b (petit) juste derrière au rang 1.
        assignment: {
          Room.keyOf(0, 0): 'a',
          Room.keyOf(1, 0): 'b',
          Room.keyOf(2, 1): 'c',
        },
      );

      final res = SeatingEngine(cls).evaluate();

      expect(_flagged(res), {'a', 'b'},
          reason: 'c\'est la position relative qui pose problème, pas un seul');
      expect(res.reasonsFor('b').single, contains('Tailles'));
    });

    test('objectif atteint : la note existe mais ne marque personne', () {
      final cls = _cls(
        room: Room(rows: 1, cols: 4),
        students: [
          _s('a', energy: Energy.agite),
          _s('b', energy: Energy.agite),
        ],
        balance: BalanceSettings(separateAgites: true),
        // Séparés par deux places : l'objectif est atteint.
        assignment: {Room.keyOf(0, 0): 'a', Room.keyOf(0, 3): 'b'},
      );

      final res = SeatingEngine(cls).evaluate();

      final note = res.balance.single;
      expect(note.ok, isTrue);
      expect(note.studentIds, isEmpty);
      expect(_flagged(res), isEmpty);
    });
  });
}
