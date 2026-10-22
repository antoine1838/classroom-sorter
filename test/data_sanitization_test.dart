// Des données lues du stockage local ou d'un fichier importé (éventuellement
// modifié à la main, ou venu d'une version plus ancienne) peuvent désigner des
// élèves ou des places qui n'existent pas. Elles doivent être nettoyées à la
// lecture : sinon le moteur tombait plus tard sur un élève introuvable
// (`_byId[sid]!`) et l'écran de validation plantait.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/services/plan_file_service.dart';

Student _student(String id) => Student(id: id, firstName: id);

void main() {
  group('Room.tryParse', () {
    test('lit une clé bien formée', () {
      expect(Room.tryParse('1,2'), (1, 2));
    });

    test('rend null pour une clé mal formée', () {
      expect(Room.tryParse('a,b'), isNull);
      expect(Room.tryParse('1'), isNull);
      expect(Room.tryParse('1,2,3'), isNull);
      expect(Room.tryParse(''), isNull);
    });
  });

  group('Room.fromJson', () {
    test('ramène les dimensions dans les bornes de l\'éditeur', () {
      final room = Room.fromJson({'rows': 500, 'cols': 0});

      expect(room.rows, Room.maxSize);
      expect(room.cols, Room.minSize);
    });

    test('retire les couloirs et les orientations hors de la grille', () {
      final room = Room.fromJson({
        'rows': 2,
        'cols': 3,
        'colAisles': [0, 1, 2, 7, -1],
        'rowAisles': [0, 1, 5],
        'facing': {'0,0': 'est', 'abc': 'sud', '9,9': 'ouest', '1,2': 'sud'},
        'disabled': ['1,2'],
      });

      expect(room.colAisles, {0, 1}, reason: 'valides : 0 <= c <= cols - 2');
      expect(room.rowAisles, {0}, reason: 'valides : 0 <= r <= rows - 2');
      expect(room.facing.keys, [
        '0,0',
      ], reason: 'clé mal formée, hors grille ou place désactivée');
    });
  });

  group('ClassGroup.fromJson', () {
    ClassGroup load({
      List<Student>? students,
      List<Rule>? rules,
      Map<String, String>? assignment,
      Set<String> disabled = const {},
    }) => ClassGroup.fromJson(
      ClassGroup(
        id: 'c',
        name: '6ème B',
        room: Room(rows: 2, cols: 3, disabled: {...disabled}),
        students: students ?? [_student('ada'), _student('lin')],
        rules: rules,
        assignment: assignment,
      ).toJson(),
    );

    test('garde un plan cohérent tel quel', () {
      final cls = load(assignment: {'0,0': 'ada', '1,2': 'lin'});

      expect(cls.assignment, {'0,0': 'ada', '1,2': 'lin'});
    });

    test('retire les places du plan qui ne mènent nulle part', () {
      final cls = load(
        disabled: {'1,1'},
        assignment: {
          '0,0': 'ada',
          '0,1': 'fantôme', // élève inconnu
          'xx': 'lin', // clé mal formée
          '9,9': 'lin', // hors grille
          '1,1': 'lin', // place désactivée
          '0,2': 'ada', // ada est déjà placée en 0,0
          '1,0': 'lin',
        },
      );

      expect(cls.assignment, {'0,0': 'ada', '1,0': 'lin'});
    });

    test('retire les règles qui nomment un élève inconnu', () {
      final cls = load(
        rules: [
          Rule(
            id: 'ok',
            type: RuleType.separate,
            studentAId: 'ada',
            studentBId: 'lin',
          ),
          Rule(
            id: 'b-inconnu',
            type: RuleType.separate,
            studentAId: 'ada',
            studentBId: 'fantôme',
          ),
          Rule(
            id: 'a-inconnu',
            type: RuleType.keepTogether,
            studentAId: 'fantôme',
            studentBId: 'lin',
          ),
          Rule(id: 'devant', type: RuleType.frontZone, studentAId: 'ada'),
        ],
      );

      expect(cls.rules.map((r) => r.id), ['ok', 'devant']);
    });

    test('garde le premier de deux élèves qui partagent un id', () {
      final cls = load(
        students: [
          Student(id: 'ada', firstName: 'Ada'),
          Student(id: 'ada', firstName: 'Doublon'),
          _student('lin'),
        ],
      );

      expect(cls.students.map((s) => s.firstName), ['Ada', 'lin']);
    });
  });

  group('le moteur', () {
    test('évaluer un plan qui désigne un élève inconnu ne plante pas', () {
      // État incohérent construit en mémoire, sans passer par fromJson.
      final cls = ClassGroup(
        id: 'c',
        room: Room(rows: 1, cols: 3),
        students: [_student('ada'), _student('lin')],
        assignment: {'0,0': 'ada', '0,1': 'fantôme', '0,2': 'lin'},
      );

      final result = SeatingEngine(cls).evaluate();

      expect(result.unplacedStudentIds, isEmpty);
    });
  });

  group('un fichier de plan importé', () {
    test('est nettoyé, et le plan importé peut être évalué', () {
      final service = PlanFileService();
      final source = ClassGroup(
        id: 'c',
        name: '6ème B',
        room: Room(rows: 1, cols: 3),
        students: [_student('ada'), _student('lin')],
        rules: [
          Rule(
            id: 'r',
            type: RuleType.separate,
            studentAId: 'ada',
            studentBId: 'fantôme',
          ),
        ],
        assignment: {'0,0': 'ada', '0,1': 'fantôme', '0,2': 'lin'},
      );

      final imported = service.decode(service.encode(source));

      expect(imported.assignment, {'0,0': 'ada', '0,2': 'lin'});
      expect(imported.rules, isEmpty);
      expect(() => SeatingEngine(imported).evaluate(), returnsNormally);
    });
  });

  group('ce qui a été retiré à la lecture', () {
    ClassGroup dirty() => ClassGroup(
      id: 'c',
      name: '6ème B',
      room: Room(rows: 2, cols: 3, disabled: {'1,1'}),
      students: [_student('ada'), _student('lin'), _student('ada')],
      rules: [
        Rule(
          id: 'b-inconnu',
          type: RuleType.separate,
          studentAId: 'ada',
          studentBId: 'fantôme',
        ),
        Rule(
          id: 'a-inconnu',
          type: RuleType.keepTogether,
          studentAId: 'fantôme',
          studentBId: 'lin',
        ),
      ],
      assignment: {
        '0,0': 'ada',
        '0,1': 'fantôme',
        'xx': 'lin',
        '9,9': 'lin',
        '1,1': 'lin',
        '0,2': 'ada',
        '1,0': 'lin',
      },
    );

    test('une classe saine ne signale rien', () {
      final result = ClassGroup.fromJsonWithCleanup(
        ClassGroup(
          id: 'c',
          room: Room(rows: 1, cols: 2),
          students: [_student('ada')],
          assignment: {'0,0': 'ada'},
        ).toJson(),
      );

      expect(result.cleanup.isEmpty, isTrue);
    });

    test('les élèves, les règles et les places retirés sont comptés', () {
      final cleanup = ClassGroup.fromJsonWithCleanup(dirty().toJson()).cleanup;

      expect(cleanup.isEmpty, isFalse);
      expect(cleanup.studentsRemoved, 1);
      expect(cleanup.rulesRemoved, 2);
      expect(cleanup.placesRemoved, 5);
    });

    test('un fichier lu rapporte le même nettoyage', () {
      final service = PlanFileService();

      final result = service.decodeWithCleanup(service.encode(dirty()));

      expect(result.classGroup.assignment, {'0,0': 'ada', '1,0': 'lin'});
      expect(result.cleanup.placesRemoved, 5);
      expect(result.cleanup.rulesRemoved, 2);
      expect(result.cleanup.studentsRemoved, 1);
    });

    test(
      "importer rapporte le nettoyage, et rend null si l'on annule",
      () async {
        final bytes = utf8.encode(PlanFileService().encode(dirty()));
        final importing = PlanFileService(
          pickFile: () async => Uint8List.fromList(bytes),
        );
        final cancelled = PlanFileService(pickFile: () async => null);

        final imported = await importing.importClassWithCleanup();

        expect(imported?.cleanup.placesRemoved, 5);
        expect(await cancelled.importClassWithCleanup(), isNull);
      },
    );
  });
}
