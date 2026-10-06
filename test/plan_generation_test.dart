import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/engine/plan_evaluation_signature.dart';
import 'package:plandeclasse/engine/plan_generation.dart';
import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';

ClassGroup _classWith({
  String name = 'Classe',
  Map<String, String>? assignment,
}) => ClassGroup(
  id: 'class',
  name: name,
  room: Room(rows: 2, cols: 2),
  students: [
    Student(id: 'a', firstName: 'Ada'),
    Student(id: 'b', firstName: 'Benoît'),
    Student(id: 'c', firstName: 'Chloé'),
  ],
  assignment: assignment ?? {},
);

void main() {
  group('empreinte de plan', () {
    test('est stable quel que soit l’ordre des affectations', () {
      final first = _classWith(assignment: {'1,1': 'b', '0,0': 'a'});
      final second = _classWith(assignment: {'0,0': 'a', '1,1': 'b'});

      expect(planEvaluationSignature(first), planEvaluationSignature(second));
    });

    test('ignore le nom mais détecte un changement métier', () {
      final cls = _classWith();
      final signature = planEvaluationSignature(cls);

      cls.name = 'Classe renommée';
      expect(planEvaluationSignature(cls), signature);

      cls.balance.mixGender = true;
      expect(planEvaluationSignature(cls), isNot(signature));
    });
  });

  group('worker de génération', () {
    test('produit la même affectation que le moteur avec une graine', () {
      final cls = _classWith();
      final message = {
        'classGroup': cls.toJson(),
        'seed': 7,
        'restarts': 3,
        'iterations': 100,
      };

      final actual = seatingGenerateWorker(message);
      final expected = SeatingEngine(
        ClassGroup.fromJson(cls.toJson()),
        seed: 7,
      ).generate(restarts: 3, iterations: 100);

      expect(actual.assignment, expected.assignment);
    });

    test('le service retourne une affectation calculée hors de l’UI', () async {
      final cls = _classWith();

      final result = await const PlanGenerationService().generate(cls);

      expect(result.assignment, hasLength(cls.students.length));
      expect(result.assignment.values.toSet(), containsAll(['a', 'b', 'c']));
    });
  });

  group('application d’un résultat généré', () {
    test('refuse un jeton ou une empreinte périmés', () {
      expect(
        shouldApplyGeneratedPlan(
          requestSignature: 'a',
          currentSignature: 'a',
          requestToken: 1,
          currentToken: 1,
        ),
        isTrue,
      );
      expect(
        shouldApplyGeneratedPlan(
          requestSignature: 'a',
          currentSignature: 'b',
          requestToken: 1,
          currentToken: 1,
        ),
        isFalse,
      );
      expect(
        shouldApplyGeneratedPlan(
          requestSignature: 'a',
          currentSignature: 'a',
          requestToken: 1,
          currentToken: 2,
        ),
        isFalse,
      );
    });
  });
}
