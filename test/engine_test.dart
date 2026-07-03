// Tests unitaires du moteur d'affectation.
import 'package:flutter_test/flutter_test.dart';

import 'package:classroom_sort/engine/seating_engine.dart';
import 'package:classroom_sort/models/classroom.dart';
import 'package:classroom_sort/models/room.dart';
import 'package:classroom_sort/models/rule.dart';
import 'package:classroom_sort/models/student.dart';

ClassGroup _classWith({
  required List<Student> students,
  required List<Rule> rules,
  Room? room,
  BalanceSettings? balance,
}) =>
    ClassGroup(
      id: 'c',
      name: 'Test',
      room: room ?? Room(rows: 4, cols: 4),
      students: students,
      rules: rules,
      balance: balance,
    );

void main() {
  test('contrainte dure « séparer » respectée', () {
    final cls = _classWith(
      students: [
        Student(id: 'a', firstName: 'A'),
        Student(id: 'b', firstName: 'B'),
        Student(id: 'c', firstName: 'C'),
        Student(id: 'd', firstName: 'D'),
      ],
      rules: [
        Rule(
            id: 'r',
            type: RuleType.separate,
            studentAId: 'a',
            studentBId: 'b',
            hard: true),
      ],
    );

    final res = SeatingEngine(cls, seed: 7).generate();

    expect(res.violations, isEmpty,
        reason: 'A et B ne devraient pas être côte à côte');
    expect(res.unplacedStudentIds, isEmpty);
    expect(res.assignment.length, 4);
  });

  test('place imposée (fixedSeat) honorée', () {
    final cls = _classWith(
      students: [
        Student(id: 'a', firstName: 'A'),
        Student(id: 'b', firstName: 'B'),
      ],
      rules: [
        Rule(
          id: 'r',
          type: RuleType.fixedSeat,
          studentAId: 'a',
          seatRow: 0,
          seatCol: 2,
        ),
      ],
    );

    final res = SeatingEngine(cls, seed: 1).generate();

    expect(res.assignment[Room.keyOf(0, 2)], 'a');
    expect(res.violations, isEmpty);
  });

  test('contrainte « devant » respectée', () {
    final cls = _classWith(
      room: Room(rows: 4, cols: 4),
      students: [
        Student(id: 'a', firstName: 'A'),
        Student(id: 'b', firstName: 'B'),
        Student(id: 'c', firstName: 'C'),
      ],
      rules: [
        Rule(
          id: 'r',
          type: RuleType.frontZone,
          studentAId: 'a',
          frontRows: 1,
          hard: true,
        ),
      ],
    );

    final res = SeatingEngine(cls, seed: 3).generate();
    final seatA = res.assignment.entries.firstWhere((e) => e.value == 'a').key;
    final (row, _) = Room.parse(seatA);

    expect(row, 0, reason: 'A doit être au premier rang');
    expect(res.violations, isEmpty);
  });

  test('trop d\'élèves : les surnuméraires sont signalés', () {
    final cls = _classWith(
      room: Room(rows: 1, cols: 2), // 2 places
      students: [
        Student(id: 'a'),
        Student(id: 'b'),
        Student(id: 'c'),
      ],
      rules: [],
    );

    final res = SeatingEngine(cls, seed: 1).generate();

    expect(res.assignment.length, 2);
    expect(res.unplacedStudentIds.length, 1);
    expect(res.warnings, isNotEmpty);
  });
}
