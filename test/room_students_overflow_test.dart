// Onglets Salle et Élèves sur fenêtre courte (issue #17). Les deux tabs
// empilent du contenu fixe (compteurs, aide, toolbar, en-tête) au-dessus
// d'une zone souple, et débordaient nettement à 700×250 (mesuré sur le code
// non corrigé : Salle -139px, Élèves -103px — bien plus que les 14/51px de
// l'issue, restée en retard de la marge de sécurité ajoutée par #11). On
// vérifie ici que le paragraphe d'aide de Salle et les instructions/en-tête
// d'Élèves cèdent la place avant de déborder, et qu'un filet
// (CustomScrollView) absorbe le reste plutôt que de laisser échapper un
// RenderFlex overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';

const _helpText = 'Touchez une case vide';

ClassGroup _cls() => ClassGroup(
      id: 'c',
      name: '6ème B',
      room: Room(rows: 5, cols: 7),
      students: [
        for (var i = 0; i < 35; i++)
          Student(id: 's$i', firstName: 'Prenom$i', lastName: 'Nom$i'),
      ],
    );

/// Vrai si Flutter a signalé un débordement de mise en page : un débordement
/// ne fait pas échouer un test par lui-même, il faut inspecter
/// `takeException()` (voir plan_landscape_test.dart).
bool _hasOverflow(WidgetTester t) =>
    t.takeException().toString().toLowerCase().contains('overflow');

Future<void> _pump(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final cls = _cls();
  final state = AppState()..classes.add(cls);
  await t.pumpWidget(
      MaterialApp(home: ClassEditorScreen(state: state, cls: cls)));
  await t.pumpAndSettle();
}

Future<void> _toStudents(WidgetTester t) async {
  await t.tap(find.descendant(
      of: find.byType(TabBar),
      matching: find.byIcon(Icons.people_alt_outlined)));
  await t.pumpAndSettle();
}

void main() {
  group('Fenêtre courte (#17)', () {
    for (final size in [
      const Size(700, 250), // mesure exacte de l'issue
      const Size(500, 220),
      const Size(900, 300),
      const Size(300, 900), // portrait très étroit : plancher hors scope, mais pas de crash
    ]) {
      testWidgets(
          'Salle et Élèves ne débordent pas à '
          '${size.width.toInt()}×${size.height.toInt()}', (t) async {
        await _pump(t, size);
        // DefaultTabController démarre sur Salle, mais TabBarView construit
        // aussi son voisin (Élèves) : un débordement ici peut appartenir à
        // l'un ou l'autre.
        expect(_hasOverflow(t), isFalse, reason: 'Salle (et son voisin Élèves)');

        await _toStudents(t);
        expect(_hasOverflow(t), isFalse, reason: 'Élèves');
      });
    }

    testWidgets('à 700×250, le paragraphe d\'aide de Salle cède la place',
        (t) async {
      await _pump(t, const Size(700, 250));
      expect(find.textContaining(_helpText), findsNothing);
    });

    testWidgets('en confort, le paragraphe d\'aide de Salle reste visible',
        (t) async {
      await _pump(t, const Size(1000, 800));
      expect(find.textContaining(_helpText), findsOneWidget);
    });
  });
}
