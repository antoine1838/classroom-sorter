/// Vérifie la sémantique du voisinage après l'ajout des couloirs :
///   - voisins = places orthogonalement adjacentes (gauche/droite/devant/derrière) ;
///   - pas de voisin en diagonale ;
///   - un couloir de colonne coupe le voisinage horizontal (jamais le vertical).
///
/// On teste via le résultat du moteur sur des salles minuscules où l'issue est
/// déterministe quel que soit l'aléatoire : une règle « dure » satisfiable
/// donne 0 violation, une règle « dure » insatisfiable en donne au moins une.
library;

import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:flutter_test/flutter_test.dart';

ClassGroup _group({
  required int rows,
  required int cols,
  Set<int>? colAisles,
  required RuleType ruleType,
}) {
  final a = Student(id: 'a', firstName: 'A');
  final b = Student(id: 'b', firstName: 'B');
  return ClassGroup(
    id: 'c',
    room: Room(rows: rows, cols: cols, colAisles: colAisles),
    students: [a, b],
    rules: [
      Rule(id: 'r', type: ruleType, studentAId: 'a', studentBId: 'b', hard: true),
    ],
  );
}

/// Génère avec une graine fixe (l'issue est de toute façon déterministe ici).
PlanResult _run(ClassGroup g) =>
    SeatingEngine(g, seed: 1).generate(restarts: 8, iterations: 200);

void main() {
  group('Voisinage sur le même rang', () {
    test('deux places adjacentes du même rang sont voisines (séparer échoue)',
        () {
      // 1x2, pas de couloir : les deux élèves sont forcément côte à côte.
      final res = _run(_group(rows: 1, cols: 2, ruleType: RuleType.separate));
      expect(res.violations, isNotEmpty,
          reason: 'sans couloir, les deux places sont voisines → séparer impossible');
    });

    test('rapprocher réussit quand les places sont adjacentes', () {
      final res =
          _run(_group(rows: 1, cols: 2, ruleType: RuleType.keepTogether));
      expect(res.violations, isEmpty);
    });
  });

  group('Couloir entre colonnes', () {
    test('un couloir coupe le voisinage (séparer réussit)', () {
      // 1x2 avec un couloir entre la colonne 0 et 1.
      final res = _run(_group(
          rows: 1, cols: 2, colAisles: {0}, ruleType: RuleType.separate));
      expect(res.violations, isEmpty,
          reason: 'avec un couloir, les places ne sont plus voisines');
    });

    test('rapprocher échoue à travers un couloir', () {
      final res = _run(_group(
          rows: 1, cols: 2, colAisles: {0}, ruleType: RuleType.keepTogether));
      expect(res.violations, isNotEmpty);
    });
  });

  group('Rangs contigus (devant/derrière)', () {
    test('devant/derrière sont voisins (rapprocher réussit)', () {
      // 2x1 : les deux élèves sont l'un devant l'autre → voisins.
      final res =
          _run(_group(rows: 2, cols: 1, ruleType: RuleType.keepTogether));
      expect(res.violations, isEmpty,
          reason: 'même colonne, rangs contigus → voisins');
    });

    test('séparer échoue entre deux rangs contigus', () {
      final res = _run(_group(rows: 2, cols: 1, ruleType: RuleType.separate));
      expect(res.violations, isNotEmpty);
    });
  });

  group('Diagonale', () {
    // 2x2 : deux élèves épinglés en diagonale, (0,0) et (1,1), avec une règle
    // « séparer » dure. Les diagonales n'étant pas voisines, séparer réussit.
    ClassGroup diag() {
      final a = Student(id: 'a', firstName: 'A');
      final b = Student(id: 'b', firstName: 'B');
      return ClassGroup(
        id: 'c',
        room: Room(rows: 2, cols: 2),
        students: [a, b],
        rules: [
          Rule(
              id: 'pa',
              type: RuleType.fixedSeat,
              studentAId: 'a',
              seatRow: 0,
              seatCol: 0,
              hard: true),
          Rule(
              id: 'pb',
              type: RuleType.fixedSeat,
              studentAId: 'b',
              seatRow: 1,
              seatCol: 1,
              hard: true),
          Rule(
              id: 's',
              type: RuleType.separate,
              studentAId: 'a',
              studentBId: 'b',
              hard: true),
        ],
      );
    }

    test('deux élèves en diagonale ne sont pas voisins (séparer réussit)', () {
      expect(_run(diag()).violations, isEmpty);
    });
  });

  group('Modèle Room', () {
    test('toggle / test / between des couloirs de colonnes', () {
      final room = Room(rows: 3, cols: 4);
      room.toggleColAisle(1);
      expect(room.hasColAisleAfter(1), isTrue);
      expect(room.colAisleBetween(1, 2), isTrue);
      expect(room.colAisleBetween(2, 1), isTrue); // ordre indifférent
      expect(room.colAisleBetween(0, 1), isFalse);
      room.toggleColAisle(1);
      expect(room.hasColAisleAfter(1), isFalse);
    });

    test('toggleColAisle ignore les frontières hors grille', () {
      final room = Room(rows: 2, cols: 3);
      room.toggleColAisle(2); // frontière valide max = cols-2 = 1
      room.toggleColAisle(-1);
      expect(room.colAisles, isEmpty);
    });

    test('pruneColAisles retire les couloirs devenus hors grille', () {
      final room = Room(rows: 2, cols: 4, colAisles: {0, 2});
      room.cols = 2; // frontières valides : {0}
      room.pruneColAisles();
      expect(room.colAisles, {0});
    });

    test('round-trip JSON préserve les couloirs', () {
      final room = Room(rows: 2, cols: 5, colAisles: {1, 3});
      final restored = Room.fromJson(room.toJson());
      expect(restored.colAisles, {1, 3});
    });

    test('anciennes données (sans colAisles) se chargent sans couloir', () {
      final restored = Room.fromJson({'rows': 2, 'cols': 3, 'disabled': []});
      expect(restored.colAisles, isEmpty);
    });
  });
}
