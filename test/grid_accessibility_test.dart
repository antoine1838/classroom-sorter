import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/widgets/plan_viewport.dart';
import 'package:plandeclasse/widgets/seat_grid.dart';

void main() {
  testWidgets('la salle expose une place et ses actions au lecteur d’écran', (
    tester,
  ) async {
    final room = Room(rows: 1, cols: 2);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomEditorGrid(room: room, onChanged: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final seat = tester.getSemantics(
      find.bySemanticsLabel('Place, rang devant, colonne 1, face au tableau'),
    );
    expect(
      seat.getSemanticsData().label,
      'Place, rang devant, colonne 1, face au tableau',
    );
    expect(seat.getSemanticsData().hint, contains('Suppr'));
    expect(seat.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      seat.getSemanticsData().hasAction(SemanticsAction.customAction),
      isTrue,
    );

    final aisle = tester.getSemantics(
      find.bySemanticsLabel('Couloir entre colonne 1 et colonne 2, inactif'),
    );
    expect(aisle.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('le clavier fait tourner puis retire une place de la salle', (
    tester,
  ) async {
    final room = Room(rows: 1, cols: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomEditorGrid(room: room, onChanged: () {}),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(room.facingOf(0, 0), Facing.est);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(room.isSeat(0, 0), isFalse);
  });

  testWidgets('le plan expose le nom complet et la position de chaque élève', (
    tester,
  ) async {
    final cls = ClassGroup(
      id: 'class',
      room: Room(rows: 1, cols: 1),
      students: [Student(id: 'ada', firstName: 'Ada', lastName: 'Lovelace')],
      assignment: {Room.keyOf(0, 0): 'ada'},
    );
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanGrid(cls: cls, onSwap: (_, _) {}),
        ),
      ),
    );

    final seat = tester.getSemantics(find.byKey(const ValueKey('seat_ada')));
    expect(seat.getSemanticsData().label, contains('Élève Ada Lovelace'));
    expect(seat.getSemanticsData().hint, contains('Appuyer sur M'));
    semantics.dispose();
  });

  testWidgets('le clavier échange deux élèves du plan sans glisser-déposer', (
    tester,
  ) async {
    final cls = ClassGroup(
      id: 'class',
      room: Room(rows: 1, cols: 2),
      students: [
        Student(id: 'ada', firstName: 'Ada'),
        Student(id: 'lin', firstName: 'Lin'),
      ],
      assignment: {Room.keyOf(0, 0): 'ada', Room.keyOf(0, 1): 'lin'},
    );
    (String, String)? swap;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanGrid(
            cls: cls,
            onSwap: (source, target) => swap = (source, target),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(swap, (Room.keyOf(0, 0), Room.keyOf(0, 1)));
  });

  testWidgets('le clavier zoome et recentre la fenêtre du plan', (
    tester,
  ) async {
    final key = GlobalKey<PlanViewportState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: PlanViewport(
              key: key,
              tracker: PointerTracker(),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    expect(key.currentState!.scale, greaterThan(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    expect(key.currentState!.scale, 1);
  });

  testWidgets('les libellés d’accessibilité de la salle sont localisés', (
    tester,
  ) async {
    final room = Room(rows: 1, cols: 1);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RoomEditorGrid(room: room, onChanged: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('⬇  FRONT (board)'), findsOneWidget);
    semantics.dispose();
  });
}
