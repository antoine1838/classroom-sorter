// Vérifie que les écrans « Salle » et « Élèves » s'affichent en entier sur un
// téléphone étroit (format vertical), sans défilement latéral :
//  - Salle : la grille est réduite pour tenir d'un coup à l'écran.
//  - Élèves : les largeurs de colonnes s'adaptent pour que le dernier attribut
//    (« Vue ») reste visible.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';

ClassGroup _demoClass({required int rows, required int cols, int nb = 6}) {
  return ClassGroup(
    id: 'c1',
    name: 'Test',
    room: Room(rows: rows, cols: cols),
    students: [
      for (var i = 0; i < nb; i++)
        Student(id: 'stu$i', firstName: 'Prenom$i', lastName: 'Nom$i'),
    ],
  );
}

Future<void> _pumpEditor(WidgetTester tester, ClassGroup cls) async {
  await tester.pumpWidget(MaterialApp(
    home: ClassEditorScreen(state: AppState(), cls: cls),
  ));
  await tester.pumpAndSettle();
}

/// Bord droit / bas à l'écran d'un élément (transformations d'ancêtres, dont le
/// FittedBox de la salle, incluses via localToGlobal).
({double left, double right, double bottom}) _globalEdges(Element el) {
  final box = el.renderObject! as RenderBox;
  final tl = box.localToGlobal(Offset.zero);
  final br = box.localToGlobal(box.size.bottomRight(Offset.zero));
  return (left: tl.dx, right: br.dx, bottom: br.dy);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Salle : une grille large tient dans un écran étroit',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Salle volontairement très large (12 colonnes) sur un petit écran.
    await _pumpEditor(tester, _demoClass(rows: 3, cols: 12));

    // L'onglet « Salle » est affiché par défaut : les 36 places sont là…
    final seats = find.byIcon(Icons.event_seat_outlined);
    expect(seats, findsNWidgets(36));

    // …et l'ensemble tient dans la largeur ET la hauteur de l'écran.
    var minLeft = double.infinity;
    var maxRight = -double.infinity;
    var maxBottom = -double.infinity;
    for (final el in tester.elementList(seats)) {
      final e = _globalEdges(el);
      minLeft = math.min(minLeft, e.left);
      maxRight = math.max(maxRight, e.right);
      maxBottom = math.max(maxBottom, e.bottom);
    }
    expect(minLeft, greaterThanOrEqualTo(-0.5));
    expect(maxRight, lessThanOrEqualTo(360 + 0.5));
    expect(maxBottom, lessThanOrEqualTo(740 + 0.5));
  });

  testWidgets('Élèves : le dernier attribut (« Vue ») est visible sans scroll',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpEditor(tester, _demoClass(rows: 5, cols: 7));

    await tester.tap(find.text('Élèves'));
    await tester.pumpAndSettle();

    // La colonne la plus à droite est l'attribut « Vue » (icône œil barré).
    final vue = find.byIcon(Icons.visibility_off);
    expect(vue, findsOneWidget);
    final right = _globalEdges(tester.element(vue)).right;
    expect(right, lessThanOrEqualTo(390 + 0.5));
  });

  testWidgets('Onglets : la barre remplit toute la largeur de l\'écran',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpEditor(tester, _demoClass(rows: 3, cols: 6));

    // Les 4 onglets sont présents…
    final tabs = find.byType(Tab);
    expect(tabs, findsNWidgets(4));

    // …la barre est en mode « réparti » (non scrollable) : elle occupe toute
    // la largeur au lieu de défiler / se tasser à gauche.
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.isScrollable, isFalse);

    // …et chaque onglet est entièrement dans l'écran (aucun coupé / hors champ).
    for (final el in tester.elementList(tabs)) {
      final e = _globalEdges(el);
      expect(e.left, greaterThanOrEqualTo(-0.5));
      expect(e.right, lessThanOrEqualTo(360 + 0.5));
    }
  });
}
