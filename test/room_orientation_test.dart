// Vérifie l'orientation « vue du professeur » : le bandeau DEVANT (tableau) et
// le rang de devant (rang logique 0) sont affichés EN BAS, les rangs du fond
// EN HAUT — tout en conservant l'index logique des places (r=0 reste le devant).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/widgets/seat_grid.dart';

void main() {
  testWidgets('Salle : le devant (tableau) est affiché en bas (vue prof)',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cls = ClassGroup(
      id: 'c1',
      name: 'Test',
      room: Room(rows: 3, cols: 2),
      students: [
        Student(id: 'front', firstName: 'Avant', lastName: 'Zero'),
        Student(id: 'back', firstName: 'Arriere', lastName: 'Deux'),
      ],
    );
    // « Avant » au rang 0 (devant), « Arriere » au rang 2 (fond).
    cls.assignment[Room.keyOf(0, 0)] = 'front';
    cls.assignment[Room.keyOf(2, 0)] = 'back';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
    ));
    await tester.pumpAndSettle();

    // Centre vertical à l'écran (transformations d'ancêtres, dont le FittedBox
    // de la salle, incluses via localToGlobal).
    double centerDy(Finder f) {
      final box = tester.renderObject<RenderBox>(f);
      return box.localToGlobal(box.size.center(Offset.zero)).dy;
    }

    final frontDy = centerDy(find.text('Avant'));
    final backDy = centerDy(find.text('Arriere'));
    final bannerDy = centerDy(find.textContaining('DEVANT'));

    // Le rang de devant (r=0) est plus BAS à l'écran que le rang du fond (r=2)…
    expect(frontDy, greaterThan(backDy));
    // …et le bandeau DEVANT (tableau) est tout en bas, sous le rang de devant.
    expect(bannerDy, greaterThan(frontDy));
  });

  testWidgets(
      'Mauvaise vue : l\'élève est placé au rang 0 ET rendu en bas, près du '
      'tableau (règle non inversée, cohérente avec la vue prof)',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cls = ClassGroup(
      id: 'c2',
      name: 'Test',
      room: Room(rows: 2, cols: 1), // moitié avant = rang 0 uniquement
      students: [
        Student(id: 'myope', firstName: 'Myope', poorEyesight: true),
        Student(id: 'normal', firstName: 'Normal'),
      ],
      // Objectif d'équilibre « mauvaise vue -> devant » activé.
      balance: BalanceSettings(frontForPoorEyesight: true),
    );

    // Avec l'objectif activé, le moteur place l'élève à mauvaise vue au rang 0.
    final res = SeatingEngine(cls, seed: 2).generate();
    final seatMyope =
        res.assignment.entries.firstWhere((e) => e.value == 'myope').key;
    expect(Room.parse(seatMyope).$1, 0,
        reason: 'mauvaise vue -> rang logique 0 (devant), règle inchangée');
    expect(res.violations, isEmpty);
    cls.assignment.addAll(res.assignment);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
    ));
    await tester.pumpAndSettle();

    double centerDy(Finder f) {
      final box = tester.renderObject<RenderBox>(f);
      return box.localToGlobal(box.size.center(Offset.zero)).dy;
    }

    final myopeDy = centerDy(find.text('Myope'));
    final normalDy = centerDy(find.text('Normal'));
    final bannerDy = centerDy(find.textContaining('DEVANT'));

    // Devant en bas : l'élève à mauvaise vue (rang 0) est rendu plus BAS que
    // l'élève du fond…
    expect(myopeDy, greaterThan(normalDy));
    // …et juste au-dessus du bandeau tableau, tout en bas de la salle.
    expect(bannerDy, greaterThan(myopeDy));
  });

  testWidgets(
      'Règle « doit être devant » : élève placé au rang 0 ET rendu en bas, '
      'près du tableau (indépendant de l\'orientation)', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cls = ClassGroup(
      id: 'c3',
      name: 'Test',
      room: Room(rows: 2, cols: 1),
      students: [
        Student(id: 'avant', firstName: 'Avant'),
        Student(id: 'fond', firstName: 'Fond'),
      ],
      rules: [
        Rule(
          id: 'r',
          type: RuleType.frontZone,
          studentAId: 'avant',
          frontRows: 1, // premier rang uniquement
          hard: true,
        ),
      ],
    );

    // Le moteur place l'élève « devant » au rang LOGIQUE 0.
    final res = SeatingEngine(cls, seed: 3).generate();
    final seatAvant =
        res.assignment.entries.firstWhere((e) => e.value == 'avant').key;
    expect(Room.parse(seatAvant).$1, 0,
        reason: 'règle « devant » -> rang logique 0');
    expect(res.violations, isEmpty);
    cls.assignment.addAll(res.assignment);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanGrid(cls: cls, onSwap: (_, _) {})),
    ));
    await tester.pumpAndSettle();

    double centerDy(Finder f) {
      final box = tester.renderObject<RenderBox>(f);
      return box.localToGlobal(box.size.center(Offset.zero)).dy;
    }

    final avantDy = centerDy(find.text('Avant'));
    final fondDy = centerDy(find.text('Fond'));
    final bannerDy = centerDy(find.textContaining('DEVANT'));

    // Devant en bas : l'élève « devant » (rang 0) est rendu plus BAS que l'élève
    // du fond, et juste au-dessus du bandeau tableau.
    expect(avantDy, greaterThan(fondDy));
    expect(bannerDy, greaterThan(avantDy));
  });
}
