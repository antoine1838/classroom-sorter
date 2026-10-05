/// Mutations métier d'une classe, avec une notification/persistance explicite.
library;

import '../engine/seating_engine.dart';
import '../models/classroom.dart';
import '../models/room.dart';
import '../models/rule.dart';
import '../models/student.dart';

/// Regroupe les mutations qui portent un invariant ou sont partagées par
/// plusieurs onglets. Les widgets gardent leurs dialogues et leur état de
/// présentation ; ils appellent [commit] une seule fois par modification.
class ClassGroupOps {
  ClassGroupOps(this.cls, {required this.commit});

  final ClassGroup cls;
  final void Function() commit;

  /// Retire du plan les affectations qui ne désignent plus une place active.
  void afterRoomEdited() {
    cls.assignment.removeWhere((seat, _) {
      final (row, col) = Room.parse(seat);
      return !cls.room.isSeat(row, col);
    });
    commit();
  }

  void resizeRoom({int? rows, int? cols}) {
    if (rows != null) cls.room.rows = rows.clamp(1, 15);
    if (cols != null) cls.room.cols = cols.clamp(1, 15);
    cls.room
      ..pruneColAisles()
      ..pruneRowAisles()
      ..pruneFacing();
    afterRoomEdited();
  }

  void applyRoom(Room room, {String? savedRoomId}) {
    cls
      ..room = room
      ..savedRoomId = savedRoomId;
    afterRoomEdited();
  }

  void upsertStudent(Student data, {Student? existing}) {
    if (existing == null) {
      cls.students.add(data);
    } else {
      existing
        ..firstName = data.firstName
        ..lastName = data.lastName
        ..gender = data.gender
        ..level = data.level
        ..energy = data.energy
        ..size = data.size
        ..poorEyesight = data.poorEyesight
        ..notes = data.notes;
    }
    commit();
  }

  void removeStudent(Student student) {
    cls.purgeStudent(student.id);
    cls.students.remove(student);
    commit();
  }

  int importStudentsFromLines(String text, String Function() newStudentId) {
    var count = 0;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      cls.students.add(
        Student(
          id: newStudentId(),
          firstName: parts.first,
          lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
        ),
      );
      count++;
    }
    if (count > 0) commit();
    return count;
  }

  void addRule(Rule rule) {
    cls.rules.add(rule);
    commit();
  }

  void removeRule(Rule rule) {
    cls.rules.remove(rule);
    commit();
  }

  void updateBalance(void Function(BalanceSettings settings) update) {
    update(cls.balance);
    commit();
  }

  void rename(String name) {
    cls.name = name;
    commit();
  }

  PlanResult generatePlan() {
    final result = SeatingEngine(cls).generate();
    cls.assignment = result.assignment;
    commit();
    return result;
  }

  void swapSeats(String seatA, String seatB) {
    final first = cls.assignment[seatA];
    final second = cls.assignment[seatB];
    if (second == null) {
      cls.assignment.remove(seatA);
    } else {
      cls.assignment[seatA] = second;
    }
    if (first == null) {
      cls.assignment.remove(seatB);
    } else {
      cls.assignment[seatB] = first;
    }
    commit();
  }
}
