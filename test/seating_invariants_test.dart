// Invariants du moteur, vérifiés sur de nombreuses graines (la graine rend
// chaque exécution reproductible : ces tests ne sont pas aléatoires).
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';

const _seeds = 60;

// Recherche allégée pour garder la suite rapide : mesurée à 0 violation sur
// 200 graines pour le scénario le plus dur ci-dessous (réglages par défaut,
// 40 × 1000 : environ 4 fois plus lent, même résultat).
const _restarts = 15;
const _iterations = 800;

Rule _separate(String a, String b) => Rule(
  id: 'sep-$a-$b',
  type: RuleType.separate,
  studentAId: a,
  studentBId: b,
);

/// Règles « séparer » obligatoires entre tous les élèves [ids] pris deux à deux.
List<Rule> _pairwiseSeparate(List<String> ids) => [
  for (var i = 0; i < ids.length; i++)
    for (var j = i + 1; j < ids.length; j++) _separate(ids[i], ids[j]),
];

/// Invariants de tout plan, quel que soit l'état de la salle.
void _expectConsistentPlan(ClassGroup cls, PlanResult res, String reason) {
  final seats = cls.room.seatKeys.toSet();
  final studentIds = cls.students.map((s) => s.id).toSet();
  final seated = res.assignment.values;

  expect(
    res.assignment.keys.every(seats.contains),
    isTrue,
    reason: '$reason : une place n\'existe pas dans la salle',
  );
  expect(
    seated.toSet(),
    hasLength(seated.length),
    reason: '$reason : un élève occupe deux places',
  );
  expect(
    seated.every(studentIds.contains),
    isTrue,
    reason: '$reason : un élève inconnu est placé',
  );
  // Deux élèves sur la même place feraient perdre une entrée à `assignment` :
  // placés + non placés doivent donc retomber sur l'effectif de la classe.
  expect(
    res.assignment.length + res.unplacedStudentIds.length,
    cls.students.length,
    reason: '$reason : un élève est perdu ou compté deux fois',
  );
  expect(
    res.unplacedStudentIds.toSet().intersection(seated.toSet()),
    isEmpty,
    reason: '$reason : un élève est à la fois placé et non placé',
  );
  expect(
    res.unplacedStudentIds,
    hasLength(
      cls.students.length > seats.length
          ? cls.students.length - seats.length
          : 0,
    ),
    reason: '$reason : on ne laisse sans place que le surplus',
  );
}

void main() {
  group('plus de places que d\'élèves', () {
    // 4 × 7 = 28 places pour 20 élèves ; des règles obligatoires de chaque
    // type, toutes satisfiables ensemble.
    ClassGroup build() {
      final students = [for (var i = 0; i < 20; i++) Student(id: 's$i')];
      return ClassGroup(
        id: 'c',
        name: 'Test',
        room: Room(rows: 4, cols: 7),
        students: students,
        rules: [
          ..._pairwiseSeparate(['s0', 's1', 's2', 's3', 's4', 's5']),
          Rule(
            id: 'together',
            type: RuleType.keepTogether,
            studentAId: 's6',
            studentBId: 's7',
          ),
          Rule(
            id: 'front',
            type: RuleType.frontZone,
            studentAId: 's8',
            frontRows: 1,
          ),
          Rule(
            id: 'fixed',
            type: RuleType.fixedSeat,
            studentAId: 's9',
            seatRow: 3,
            seatCol: 6,
          ),
        ],
        balance: BalanceSettings(separateAgites: false),
      );
    }

    test('places cohérentes et règles obligatoires respectées', () {
      for (var seed = 0; seed < _seeds; seed++) {
        final cls = build();
        final res = SeatingEngine(
          cls,
          seed: seed,
        ).generate(restarts: _restarts, iterations: _iterations);

        _expectConsistentPlan(cls, res, 'graine $seed');
        expect(res.unplacedStudentIds, isEmpty, reason: 'graine $seed');
        expect(res.violations, isEmpty, reason: 'graine $seed');
        expect(res.assignment[Room.keyOf(3, 6)], 's9', reason: 'graine $seed');
      }
    });
  });

  group('plus d\'élèves que de places', () {
    // 4 × 7 = 28 places pour 30 élèves : 2 non placés. Les 14 premiers élèves
    // sont deux à deux « séparer » (obligatoire) : satisfiable seulement si
    // tous occupent les 14 places d'un même damier. Écarter l'un d'eux
    // « satisferait » la règle gratuitement : c'est le biais à exclure.
    ClassGroup build() => ClassGroup(
      id: 'c',
      name: 'Test',
      room: Room(rows: 4, cols: 7),
      students: [for (var i = 0; i < 30; i++) Student(id: 's$i')],
      rules: _pairwiseSeparate([for (var i = 0; i < 14; i++) 's$i']),
      balance: BalanceSettings(separateAgites: false),
    );

    test('places cohérentes, règle satisfiable respectée', () {
      for (var seed = 0; seed < _seeds; seed++) {
        final cls = build();
        final res = SeatingEngine(
          cls,
          seed: seed,
        ).generate(restarts: _restarts, iterations: _iterations);

        _expectConsistentPlan(cls, res, 'graine $seed');
        expect(res.violations, isEmpty, reason: 'graine $seed');
      }
    });

    test(
      'un élève visé par une règle obligatoire n\'est pas laissé de côté',
      () {
        final ruled = {for (var i = 0; i < 14; i++) 's$i'};
        var unplaced = 0;
        var unplacedRuled = 0;
        for (var seed = 0; seed < _seeds; seed++) {
          final res = SeatingEngine(
            build(),
            seed: seed,
          ).generate(restarts: _restarts, iterations: _iterations);
          unplaced += res.unplacedStudentIds.length;
          unplacedRuled += res.unplacedStudentIds.where(ruled.contains).length;
        }

        expect(unplaced, 2 * _seeds);
        expect(
          unplacedRuled,
          0,
          reason: 'les 16 autres élèves suffisent à absorber le surplus',
        );
      },
    );

    test('le surplus est tiré sans biais selon les attributs des élèves', () {
      // 30 élèves, 25 places : 5 non placés. Tous les objectifs d'équilibre
      // sont actifs, et 8 élèves ont une règle « séparer » obligatoire.
      // Chaque attribut est réparti en tiers (niveau, taille) ou presque
      // (agité 1/5, mauvaise vue 1/7) sans lien avec les règles.
      const students = 30;
      const hardPairs = [(2, 3), (4, 6), (9, 11), (12, 13)];
      final ruled = {
        for (final (a, b) in hardPairs) ...['s$a', 's$b'],
      };
      ClassGroup build() => ClassGroup(
        id: 'c',
        name: 'Test',
        room: Room(rows: 5, cols: 5),
        students: [
          for (var i = 0; i < students; i++)
            Student(
              id: 's$i',
              gender: i % 2 == 0 ? Gender.fille : Gender.garcon,
              level: Level.values[i % 3],
              size: StudentSize.values[i % 3],
              energy: i % 5 == 0 ? Energy.agite : Energy.calme,
              poorEyesight: i % 7 == 1,
            ),
        ],
        rules: [for (final (a, b) in hardPairs) _separate('s$a', 's$b')],
        balance: BalanceSettings(
          mixGender: true,
          mixLevel: true,
          separateAgites: true,
          frontForPoorEyesight: true,
          avoidTallInFrontOfShort: true,
        ),
      );

      final byId = {for (final s in build().students) s.id: s};
      final pool = byId.values.where((s) => !ruled.contains(s.id)).toList();
      final unplacedStudents = <Student>[];
      for (var seed = 0; seed < _seeds; seed++) {
        final cls = build();
        final res = SeatingEngine(
          cls,
          seed: seed,
        ).generate(restarts: _restarts, iterations: _iterations);
        _expectConsistentPlan(cls, res, 'graine $seed');
        unplacedStudents.addAll(res.unplacedStudentIds.map((id) => byId[id]!));
      }

      // Aucun élève à règle obligatoire (il y a assez d'élèves sans règle).
      expect(unplacedStudents.where((s) => ruled.contains(s.id)), isEmpty);

      // Part de chaque groupe parmi les non-placés, comparée à sa part parmi
      // les élèves qui peuvent l'être. 300 tirages : l'écart-type d'une part
      // est d'environ 3 points ; 10 points laissent une marge de plus de
      // 3 écarts-types, alors que l'optimiseur sans tirage neutre laissait de
      // côté 85 % de niveaux Faible/Fort pour 64 % dans le vivier.
      void expectUnbiased(String group, bool Function(Student) inGroup) {
        final expected = pool.where(inGroup).length / pool.length;
        final observed =
            unplacedStudents.where(inGroup).length / unplacedStudents.length;
        expect(
          (observed - expected).abs(),
          lessThan(0.10),
          reason:
              '$group : ${(observed * 100).toStringAsFixed(0)} % des non-placés '
              'pour ${(expected * 100).toStringAsFixed(0)} % des candidats',
        );
      }

      expectUnbiased('niveau Moyen', (s) => s.level == Level.moyen);
      expectUnbiased('niveau Faible', (s) => s.level == Level.faible);
      expectUnbiased('niveau Fort', (s) => s.level == Level.fort);
      expectUnbiased('taille Moyen', (s) => s.size == StudentSize.moyen);
      expectUnbiased('agités', (s) => s.energy == Energy.agite);
      expectUnbiased('mauvaise vue', (s) => s.poorEyesight);
    });
  });
}
