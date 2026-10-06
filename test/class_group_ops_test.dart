import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/actions/class_group_ops.dart';
import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';

void main() {
  ClassGroup group({
    Room? room,
    List<Student>? students,
    List<Rule>? rules,
    Map<String, String>? assignment,
  }) => ClassGroup(
    id: 'class',
    room: room ?? Room(rows: 2, cols: 2),
    students: students ?? [],
    rules: rules ?? [],
    assignment: assignment ?? {},
  );

  test('redimensionner la salle supprime les affectations hors plan', () {
    var commits = 0;
    final cls = group(assignment: {'0,0': 'a', '1,1': 'b'});

    ClassGroupOps(cls, commit: () => commits++).resizeRoom(rows: 1);

    expect(cls.room.rows, 1);
    expect(cls.assignment, {'0,0': 'a'});
    expect(commits, 1);
  });

  test('supprimer un élève purge règles et affectation associées', () {
    var commits = 0;
    final alice = Student(id: 'alice');
    final bob = Student(id: 'bob');
    final cls = group(
      students: [alice, bob],
      rules: [
        Rule(
          id: 'rule',
          type: RuleType.separate,
          studentAId: alice.id,
          studentBId: bob.id,
        ),
      ],
      assignment: {'0,0': alice.id, '0,1': bob.id},
    );

    ClassGroupOps(cls, commit: () => commits++).removeStudent(alice);

    expect(cls.students, [bob]);
    expect(cls.rules, isEmpty);
    expect(cls.assignment, {'0,1': bob.id});
    expect(commits, 1);
  });

  test('importer ignore les lignes vides et ne valide qu’une fois', () {
    var commits = 0;
    final cls = group();
    var nextId = 0;

    final count = ClassGroupOps(cls, commit: () => commits++)
        .importStudentsFromLines(
          '\nAda Lovelace\n\nJean Claude Van Damme\n',
          () {
            nextId++;
            return '$nextId';
          },
        );

    expect(count, 2);
    expect(cls.students.map((student) => student.fullName), [
      'Ada Lovelace',
      'Jean Claude Van Damme',
    ]);
    expect(commits, 1);
  });

  test(
    'appliquer une génération valide une seule fois puis évalue le plan',
    () {
      var commits = 0;
      final alice = Student(id: 'alice');
      final cls = group(students: [alice]);
      final ops = ClassGroupOps(cls, commit: () => commits++);

      final result = ops.applyGeneratedPlan(
        SeatingEngine(cls, seed: 1).generate(restarts: 1, iterations: 1),
      );

      expect(cls.assignment, result.assignment);
      expect(commits, 1);
      expect(result.assignment.values.single, alice.id);
    },
  );
}
