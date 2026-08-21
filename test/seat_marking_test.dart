// Étape 4 de la refonte de l'écran Plan (notes/refonte-ecran-plan.md) :
// marquage des élèves fautifs sur la place elle-même, et tap pour ouvrir la
// feuille de détail. Ce fichier couvre le RENDU (fond de sévérité, liseré de
// genre) et le CALLBACK de tap au niveau de PlanGrid — le contenu de la
// feuille et l'enchaînement vers le formulaire d'édition sont couverts dans
// class_editor_screen_test.dart, qui a accès à l'écran complet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/engine/plan_issue.dart';
import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/widgets/seat_grid.dart';

/// Le Container qui porte le fond/la bordure d'une place, retrouvé par la clé
/// stable `seat_<id>` — la place n'a plus de Tooltip de nom depuis que la
/// feuille au tap a pris ce rôle.
Container _seatContainer(WidgetTester t, String studentId) {
  return t.widget<Container>(find
      .descendant(
        of: find.byKey(ValueKey('seat_$studentId')),
        matching: find.byType(Container),
      )
      .first);
}

void main() {
  testWidgets('le fond marque la sévérité : dur, souple et neutre diffèrent',
      (t) async {
    final cls = ClassGroup(
      id: 'c',
      name: 'Test',
      room: Room(rows: 1, cols: 3),
      students: [
        Student(id: 'hard', firstName: 'Hard'),
        Student(id: 'soft', firstName: 'Soft'),
        Student(id: 'clean', firstName: 'Clean'),
      ],
    )
      ..assignment[Room.keyOf(0, 0)] = 'hard'
      ..assignment[Room.keyOf(0, 1)] = 'soft'
      ..assignment[Room.keyOf(0, 2)] = 'clean';

    final result = PlanResult(
      assignment: cls.assignment,
      unplacedStudentIds: const [],
      issues: const [
        PlanIssue(
            severity: IssueSeverity.hard, label: 'dur', studentIds: ['hard']),
        PlanIssue(
            severity: IssueSeverity.soft,
            label: 'souple',
            studentIds: ['soft']),
      ],
      balance: const [],
      score: 0,
    );

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: PlanGrid(cls: cls, onSwap: (_, _) {}, result: result)),
    ));
    await t.pumpAndSettle();

    Color bg(String id) =>
        (_seatContainer(t, id).decoration as BoxDecoration).color!;

    final hard = bg('hard');
    final soft = bg('soft');
    final clean = bg('clean');
    expect(hard, isNot(equals(soft)));
    expect(hard, isNot(equals(clean)));
    expect(soft, isNot(equals(clean)));
  });

  testWidgets(
      'le genre se replie sur un liseré de 4px au bord gauche, muet pour « autre »',
      (t) async {
    final cls = ClassGroup(
      id: 'c',
      name: 'Test',
      room: Room(rows: 1, cols: 3),
      students: [
        Student(id: 'f', firstName: 'F', gender: Gender.fille),
        Student(id: 'g', firstName: 'G', gender: Gender.garcon),
        Student(id: 'a', firstName: 'A', gender: Gender.autre),
      ],
    )
      ..assignment[Room.keyOf(0, 0)] = 'f'
      ..assignment[Room.keyOf(0, 1)] = 'g'
      ..assignment[Room.keyOf(0, 2)] = 'a';

    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
    ));
    await t.pumpAndSettle();

    Color? stripe(String id) {
      final finder = find.byKey(ValueKey('gender_stripe_$id'));
      if (finder.evaluate().isEmpty) return null;
      return (t.widget<Container>(finder).color);
    }

    final fille = stripe('f');
    final garcon = stripe('g');
    final autre = stripe('a');

    expect(fille, isNotNull);
    expect(garcon, isNotNull);
    expect(fille, isNot(equals(garcon)));
    // « autre » reste muet, comme les autres indicateurs de coin (Moyen /
    // Modéré / Bonne vue) : pas de liseré du tout.
    expect(autre, isNull);
  });

  testWidgets('le tap sur une place occupée transmet l\'élève à onTapSeat',
      (t) async {
    final cls = ClassGroup(
      id: 'c',
      name: 'Test',
      room: Room(rows: 1, cols: 2),
      students: [Student(id: 'stu', firstName: 'Stu')],
    )..assignment[Room.keyOf(0, 0)] = 'stu';

    Student? tapped;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlanGrid(
          cls: cls,
          onSwap: (_, _) {},
          onTapSeat: (s) => tapped = s,
        ),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('seat_stu')));
    await t.pumpAndSettle();

    expect(tapped?.id, 'stu');
  });

  testWidgets('le tap sur une place vide ne déclenche rien', (t) async {
    final cls = ClassGroup(
      id: 'c',
      name: 'Test',
      room: Room(rows: 1, cols: 1),
      students: const [],
    );

    var tappedCount = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlanGrid(
          cls: cls,
          onSwap: (_, _) {},
          onTapSeat: (_) => tappedCount++,
        ),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byIcon(Icons.event_seat_outlined));
    await t.pumpAndSettle();

    expect(tappedCount, 0);
  });

  group('Bord de dossier (orientation)', () {
    Alignment backrestAlignment(WidgetTester t, String studentId) {
      final align = t.widget<Align>(find.ancestor(
        of: find.byKey(ValueKey('backrest_$studentId')),
        matching: find.byType(Align),
      ));
      return align.alignment as Alignment;
    }

    testWidgets('nord (par défaut) place le dossier en haut', (t) async {
      final cls = ClassGroup(
        id: 'c',
        name: 'Test',
        room: Room(rows: 1, cols: 1),
        students: [Student(id: 'stu', firstName: 'A')],
      );
      cls.assignment[Room.keyOf(0, 0)] = 'stu';

      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
      ));
      await t.pumpAndSettle();

      expect(backrestAlignment(t, 'stu'), Alignment.topCenter);
    });

    testWidgets('chaque orientation place le dossier sur le bord opposé',
        (t) async {
      final expected = {
        Facing.nord: Alignment.topCenter,
        Facing.est: Alignment.centerLeft,
        Facing.sud: Alignment.bottomCenter,
        Facing.ouest: Alignment.centerRight,
      };

      for (final entry in expected.entries) {
        final room = Room(rows: 1, cols: 1);
        if (entry.key != Facing.nord) {
          room.facing[Room.keyOf(0, 0)] = entry.key;
        }
        final cls = ClassGroup(
          id: 'c',
          name: 'Test',
          room: room,
          students: [Student(id: 'stu', firstName: 'A')],
        );
        cls.assignment[Room.keyOf(0, 0)] = 'stu';

        await t.pumpWidget(MaterialApp(
          home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
        ));
        await t.pumpAndSettle();

        expect(backrestAlignment(t, 'stu'), entry.value,
            reason: 'orientation ${entry.key}');
      }
    });

    testWidgets(
        'facing est + liseré de genre : le dossier reste visible, '
        'peint par-dessus le liseré', (t) async {
      final room = Room(rows: 1, cols: 1)
        ..facing[Room.keyOf(0, 0)] = Facing.est;
      final cls = ClassGroup(
        id: 'c',
        name: 'Test',
        room: room,
        students: [
          Student(id: 'stu', firstName: 'A', gender: Gender.fille),
        ],
      );
      cls.assignment[Room.keyOf(0, 0)] = 'stu';

      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
      ));
      await t.pumpAndSettle();

      // Le dossier n'est pas décalé (un seul rendu pour toutes les
      // orientations, pas de cas particulier) : les deux se superposent, et
      // l'ordre de peinture dans le Stack tranche en faveur du dossier,
      // peint après — sinon l'orientation d'un élève genré serait invisible.
      expect(backrestAlignment(t, 'stu'), Alignment.centerLeft);

      final seatStack = t.widget<Stack>(find
          .ancestor(
            of: find.byKey(const ValueKey('backrest_stu')),
            matching: find.byType(Stack),
          )
          .first);
      int indexOf(Key key) => seatStack.children.indexWhere((w) => find
          .descendant(of: find.byWidget(w), matching: find.byKey(key))
          .evaluate()
          .isNotEmpty);
      final dossierIndex = indexOf(const ValueKey('backrest_stu'));
      final genderIndex = indexOf(const ValueKey('gender_stripe_stu'));

      expect(genderIndex, isNot(-1));
      expect(dossierIndex, greaterThan(genderIndex),
          reason: 'le dossier doit être peint après le liseré pour rester visible');
    });

    testWidgets('facing est sans genre marqué : le dossier reste au bord',
        (t) async {
      final room = Room(rows: 1, cols: 1)
        ..facing[Room.keyOf(0, 0)] = Facing.est;
      final cls = ClassGroup(
        id: 'c',
        name: 'Test',
        room: room,
        students: [Student(id: 'stu', firstName: 'A')], // Gender.autre
      );
      cls.assignment[Room.keyOf(0, 0)] = 'stu';

      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
      ));
      await t.pumpAndSettle();

      expect(backrestAlignment(t, 'stu'), Alignment.centerLeft,
          reason: 'rien à éviter : pas de liseré de genre pour "autre"');
    });
  });

  testWidgets('une place libre affiche l\'icône pivotée selon son orientation',
      (t) async {
    final room = Room(rows: 1, cols: 1)..facing[Room.keyOf(0, 0)] = Facing.sud;
    final cls = ClassGroup(id: 'c', name: 'Test', room: room, students: []);

    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
    ));
    await t.pumpAndSettle();

    final rotate = t.widget<Transform>(find.ancestor(
      of: find.byIcon(Icons.event_seat_outlined),
      matching: find.byType(Transform),
    ));
    expect(rotate.transform.getRotation()[0], closeTo(-1, 0.001),
        reason: 'sud = 180°, cos(π) = -1 sur la diagonale de la matrice');
  });
}
