// Tests de la couche modèles : libellés affichés, sérialisation, et surtout
// RÉTROCOMPATIBILITÉ de lecture — une sauvegarde écrite par une version
// antérieure de l'app doit continuer à se relire sans perte.
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/saved_room.dart';
import 'package:plandeclasse/models/student.dart';

void main() {
  group('Student — nom affichable et initiales', () {
    test('fullName assemble prénom et nom', () {
      expect(Student(id: '1', firstName: 'Marie', lastName: 'Dupont').fullName,
          'Marie Dupont');
      expect(Student(id: '1', firstName: 'Marie').fullName, 'Marie');
      expect(Student(id: '1', lastName: 'Dupont').fullName, 'Dupont');
    });

    test('fullName n\'est jamais vide', () {
      expect(Student(id: '1').fullName, 'Élève sans nom');
      expect(Student(id: '1', firstName: '  ', lastName: '  ').fullName,
          'Élève sans nom');
    });

    test('initials prend la première lettre de chaque nom, en majuscules', () {
      expect(Student(id: '1', firstName: 'marie', lastName: 'dupont').initials,
          'MD');
      expect(Student(id: '1', firstName: 'Marie').initials, 'M');
      expect(Student(id: '1', lastName: 'Dupont').initials, 'D');
    });

    test('initials retombe sur « ? » quand il n\'y a aucun nom', () {
      expect(Student(id: '1').initials, '?');
    });
  });

  group('Student — libellés des attributs', () {
    test('chaque valeur a un libellé affichable', () {
      expect(Gender.fille.label, 'Fille');
      expect(Gender.garcon.label, 'Garçon');
      expect(Gender.autre.label, 'Non précisé');

      expect(Level.faible.label, 'Faible');
      expect(Level.moyen.label, 'Moyen');
      expect(Level.fort.label, 'Fort');

      expect(Energy.calme.label, 'Calme');
      expect(Energy.modere.label, 'Modéré');
      expect(Energy.agite.label, 'Agité');

      expect(StudentSize.petit.label, 'Petit');
      expect(StudentSize.moyen.label, 'Moyen');
      expect(StudentSize.grand.label, 'Grand');
    });
  });

  group('Student — sérialisation', () {
    test('aller-retour JSON sans perte', () {
      final s = Student(
        id: 'x',
        firstName: 'Léa',
        lastName: 'Martin',
        gender: Gender.fille,
        level: Level.fort,
        energy: Energy.agite,
        size: StudentSize.grand,
        poorEyesight: true,
        notes: 'Devant si possible',
      );

      final back = Student.fromJson(s.toJson());

      expect(back.id, s.id);
      expect(back.firstName, s.firstName);
      expect(back.lastName, s.lastName);
      expect(back.gender, s.gender);
      expect(back.level, s.level);
      expect(back.energy, s.energy);
      expect(back.size, s.size);
      expect(back.poorEyesight, s.poorEyesight);
      expect(back.notes, s.notes);
    });

    test('ancienne clé « temperament » relue comme energy', () {
      // Sauvegardes antérieures au renommage energy <- temperament.
      final s = Student.fromJson({'id': 'x', 'temperament': 'calme'});
      expect(s.energy, Energy.calme);
    });

    test('« size » absent des vieilles sauvegardes retombe sur Moyen', () {
      final s = Student.fromJson({'id': 'x'});
      expect(s.size, StudentSize.moyen);
    });

    test('valeurs inconnues retombent sur les défauts sans planter', () {
      final s = Student.fromJson({
        'id': 'x',
        'gender': 'martien',
        'level': 'genie',
        'energy': 'endormi',
        'size': 'gigantesque',
      });

      expect(s.gender, Gender.autre);
      expect(s.level, Level.moyen);
      expect(s.energy, Energy.modere);
      expect(s.size, StudentSize.moyen);
    });

    test('champs absents : poorEyesight et notes ont des défauts sûrs', () {
      final s = Student.fromJson({'id': 'x'});
      expect(s.poorEyesight, isFalse);
      expect(s.notes, '');
      expect(s.firstName, '');
      expect(s.lastName, '');
    });
  });

  group('compareStudentsByName', () {
    test('trie par nom de famille, puis par prénom', () {
      final list = [
        Student(id: '1', firstName: 'Zoé', lastName: 'Bernard'),
        Student(id: '2', firstName: 'Alice', lastName: 'Bernard'),
        Student(id: '3', firstName: 'Marc', lastName: 'Andre'),
      ]..sort(compareStudentsByName);

      expect(list.map((s) => s.id).toList(), ['3', '2', '1']);
    });

    test('insensible à la casse', () {
      final list = [
        Student(id: '1', lastName: 'bernard'),
        Student(id: '2', lastName: 'Andre'),
      ]..sort(compareStudentsByName);

      expect(list.first.id, '2');
    });
  });

  group('Rule', () {
    test('chaque type a un libellé et une description', () {
      for (final t in RuleType.values) {
        expect(t.label, isNotEmpty, reason: '${t.name} sans libellé');
        expect(t.description, isNotEmpty, reason: '${t.name} sans description');
      }
      expect(RuleType.fixedSeat.label, 'Place imposée');
      expect(RuleType.frontZone.label, 'Doit être devant');
      expect(RuleType.separate.label, 'Séparer');
      expect(RuleType.keepTogether.label, 'Rapprocher');
    });

    test('seules « séparer » et « rapprocher » demandent un second élève', () {
      expect(RuleType.separate.needsSecondStudent, isTrue);
      expect(RuleType.keepTogether.needsSecondStudent, isTrue);
      expect(RuleType.fixedSeat.needsSecondStudent, isFalse);
      expect(RuleType.frontZone.needsSecondStudent, isFalse);
    });

    test('aller-retour JSON sans perte', () {
      final r = Rule(
        id: 'r',
        type: RuleType.fixedSeat,
        studentAId: 'a',
        studentBId: 'b',
        seatRow: 2,
        seatCol: 3,
        frontRows: 2,
        hard: false,
      );

      final back = Rule.fromJson(r.toJson());

      expect(back.id, r.id);
      expect(back.type, r.type);
      expect(back.studentAId, r.studentAId);
      expect(back.studentBId, r.studentBId);
      expect(back.seatRow, r.seatRow);
      expect(back.seatCol, r.seatCol);
      expect(back.frontRows, r.frontRows);
      expect(back.hard, r.hard);
    });

    test('type inconnu retombe sur « séparer », défauts sûrs', () {
      final r = Rule.fromJson({'id': 'r', 'type': 'sortilege', 'studentAId': 'a'});

      expect(r.type, RuleType.separate);
      expect(r.studentBId, isNull);
      expect(r.frontRows, 1);
      expect(r.hard, isTrue, reason: 'une règle est obligatoire par défaut');
    });
  });

  group('Room', () {
    test('toggle désactive puis réactive une case', () {
      final room = Room(rows: 2, cols: 2);
      expect(room.capacity, 4);

      room.toggle(0, 0);
      expect(room.isSeat(0, 0), isFalse);
      expect(room.capacity, 3);

      room.toggle(0, 0);
      expect(room.isSeat(0, 0), isTrue);
      expect(room.capacity, 4);
    });

    test('toggleColAisle ajoute puis retire un couloir', () {
      final room = Room(rows: 2, cols: 3);
      expect(room.hasColAisleAfter(0), isFalse);

      room.toggleColAisle(0);
      expect(room.hasColAisleAfter(0), isTrue);

      room.toggleColAisle(0);
      expect(room.hasColAisleAfter(0), isFalse);
    });

    test('toggleRowAisle ajoute puis retire un couloir, miroir de colAisle',
        () {
      final room = Room(rows: 3, cols: 2);
      expect(room.hasRowAisleAfter(0), isFalse);

      room.toggleRowAisle(0);
      expect(room.hasRowAisleAfter(0), isTrue);
      expect(room.rowAisleBetween(0, 1), isTrue);
      expect(room.rowAisleBetween(1, 0), isTrue,
          reason: 'ordre indifférent, comme colAisleBetween');

      room.toggleRowAisle(0);
      expect(room.hasRowAisleAfter(0), isFalse);
    });

    test('rotateFacing cycle nord → est → sud → ouest → nord', () {
      final room = Room(rows: 1, cols: 1);
      expect(room.facingOf(0, 0), Facing.nord);

      room.rotateFacing(0, 0);
      expect(room.facingOf(0, 0), Facing.est);
      room.rotateFacing(0, 0);
      expect(room.facingOf(0, 0), Facing.sud);
      room.rotateFacing(0, 0);
      expect(room.facingOf(0, 0), Facing.ouest);
      room.rotateFacing(0, 0);
      expect(room.facingOf(0, 0), Facing.nord,
          reason: 'retour à nord => stocké de façon creuse (retiré de la map)');
    });

    test('toggle retire l\'orientation quand la place est désactivée', () {
      final room = Room(rows: 1, cols: 1);
      room.rotateFacing(0, 0);
      expect(room.facingOf(0, 0), Facing.est);

      room.toggle(0, 0);
      room.toggle(0, 0);
      expect(room.facingOf(0, 0), Facing.nord,
          reason: 'une place remise naît orientée vers le tableau');
    });

    test('toJson/fromJson conservent rowAisles et facing', () {
      final room = Room(rows: 2, cols: 2);
      room.toggleRowAisle(0);
      room.rotateFacing(1, 1);

      final restored = Room.fromJson(room.toJson());

      expect(restored.hasRowAisleAfter(0), isTrue);
      expect(restored.facingOf(1, 1), Facing.est);
      expect(restored.facingOf(0, 0), Facing.nord);
    });

    test('fromJson relit une salle enregistrée avant l\'orientation', () {
      final room = Room.fromJson({'rows': 2, 'cols': 2, 'disabled': []});

      expect(room.rowAisles, isEmpty);
      expect(room.facingOf(0, 0), Facing.nord);
      expect(room.facingOf(1, 1), Facing.nord);
    });
  });

  group('ClassGroup', () {
    test('studentById trouve, ou renvoie null', () {
      final cls = ClassGroup(
        id: 'c',
        name: 'Test',
        students: [Student(id: 'a'), Student(id: 'b')],
      );

      expect(cls.studentById('b')?.id, 'b');
      expect(cls.studentById('inconnu'), isNull);
      expect(cls.studentById(null), isNull);
    });

    test('purgeStudent retire les règles et la place de l\'élève', () {
      final cls = ClassGroup(
        id: 'c',
        name: 'Test',
        room: Room(rows: 2, cols: 2),
        students: [Student(id: 'a'), Student(id: 'b'), Student(id: 'c')],
        rules: [
          // Règle où l'élève supprimé est en position A.
          Rule(id: 'r1', type: RuleType.frontZone, studentAId: 'a'),
          // Règle où il est en position B : doit partir aussi.
          Rule(
              id: 'r2',
              type: RuleType.separate,
              studentAId: 'b',
              studentBId: 'a'),
          // Règle sans lien : doit survivre.
          Rule(
              id: 'r3',
              type: RuleType.keepTogether,
              studentAId: 'b',
              studentBId: 'c'),
        ],
        assignment: {
          Room.keyOf(0, 0): 'a',
          Room.keyOf(0, 1): 'b',
        },
      );

      cls.purgeStudent('a');

      expect(cls.rules.map((r) => r.id).toList(), ['r3']);
      expect(cls.assignment.containsValue('a'), isFalse);
      expect(cls.assignment[Room.keyOf(0, 1)], 'b',
          reason: 'les autres places ne doivent pas bouger');
    });

    test('aller-retour JSON d\'une classe complète', () {
      final cls = ClassGroup(
        id: 'c',
        name: '6ème B',
        room: Room(rows: 3, cols: 4),
        students: [Student(id: 'a', firstName: 'Léa')],
        rules: [Rule(id: 'r', type: RuleType.frontZone, studentAId: 'a')],
        balance: BalanceSettings(mixGender: true),
        assignment: {Room.keyOf(0, 0): 'a'},
      );

      final back = ClassGroup.fromJson(cls.toJson());

      expect(back.id, 'c');
      expect(back.name, '6ème B');
      expect(back.room.rows, 3);
      expect(back.room.cols, 4);
      expect(back.students.single.firstName, 'Léa');
      expect(back.rules.single.type, RuleType.frontZone);
      expect(back.balance.mixGender, isTrue);
      expect(back.assignment[Room.keyOf(0, 0)], 'a');
    });

    test('classe minimale : les défauts s\'appliquent', () {
      final cls = ClassGroup(id: 'c', name: 'Vide');

      expect(cls.students, isEmpty);
      expect(cls.rules, isEmpty);
      expect(cls.assignment, isEmpty);
      expect(cls.room.capacity, greaterThan(0));
      expect(cls.savedRoomId, isNull);
    });

    test('savedRoomId survit à l\'aller-retour JSON', () {
      final cls = ClassGroup(id: 'c', name: 'Test', savedRoomId: 'salle-1');
      final back = ClassGroup.fromJson(cls.toJson());
      expect(back.savedRoomId, 'salle-1');
    });

    test('savedRoomId absent d\'une sauvegarde antérieure : null', () {
      final json = ClassGroup(id: 'c', name: 'Test').toJson();
      json.remove('savedRoomId');
      final back = ClassGroup.fromJson(json);
      expect(back.savedRoomId, isNull);
    });
  });

  group('SavedRoom', () {
    test('aller-retour JSON conserve id, nom et géométrie', () {
      final saved = SavedRoom(
        id: 's1',
        name: 'B204',
        room: Room(rows: 3, cols: 4, disabled: {Room.keyOf(0, 0)}),
      );

      final back = SavedRoom.fromJson(saved.toJson());

      expect(back.id, 's1');
      expect(back.name, 'B204');
      expect(back.room.rows, 3);
      expect(back.room.cols, 4);
      expect(back.room.isSeat(0, 0), isFalse);
    });
  });
}
