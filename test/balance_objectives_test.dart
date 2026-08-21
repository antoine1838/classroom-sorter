// Vérifie l'onglet Règles : l'en-tête « Objectifs d'équilibre » est une
// étiquette de section (pas un ListTile qui se confondrait avec un objectif
// juste en dessous, cf. issue #7), et chaque objectif a une icône distincte
// permettant de le reconnaître d'un coup d'œil.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';

Future<void> _pumpRulesTab(WidgetTester tester, ClassGroup cls) async {
  final state = AppState();
  await tester.pumpWidget(MaterialApp(
    home: ClassEditorScreen(state: state, cls: cls),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Règles'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Règles : l\'en-tête « Objectifs d\'équilibre » n\'est plus un ListTile '
      'identique aux objectifs qu\'il coiffe', (tester) async {
    final cls =
        ClassGroup(id: 'c1', name: 'Test', room: Room(rows: 2, cols: 2));
    await _pumpRulesTab(tester, cls);

    final title = find.text('Objectifs d\'équilibre');
    expect(title, findsOneWidget);
    expect(find.ancestor(of: title, matching: find.byType(ListTile)),
        findsNothing);
    expect(find.text('Appliqués à toute la classe (préférences).'),
        findsOneWidget);
  });

  testWidgets('Règles : chaque objectif d\'équilibre a une icône distincte',
      (tester) async {
    final cls =
        ClassGroup(id: 'c1', name: 'Test', room: Room(rows: 2, cols: 2));
    await _pumpRulesTab(tester, cls);

    IconData iconFor(String title) {
      final tile = tester.widget<SwitchListTile>(find.ancestor(
        of: find.text(title),
        matching: find.byType(SwitchListTile),
      ));
      return (tile.secondary as Icon).icon!;
    }

    final expected = {
      'Mixer filles / garçons': Icons.diversity_3,
      'Mélanger les niveaux': Icons.swap_vert,
      'Séparer les élèves agités': Icons.bolt,
      'Rapprocher du tableau': Icons.visibility_off,
      'Éviter qu\'un grand gêne la vue d\'un petit': Icons.height,
    };
    for (final entry in expected.entries) {
      expect(iconFor(entry.key), entry.value, reason: entry.key);
    }
    // Cinq icônes bien distinctes (pas de copier-coller resté sur la même).
    expect(expected.values.toSet(), hasLength(5));
  });

  testWidgets('Règles : basculer un objectif d\'équilibre met à jour le modèle',
      (tester) async {
    final cls =
        ClassGroup(id: 'c1', name: 'Test', room: Room(rows: 2, cols: 2));
    await _pumpRulesTab(tester, cls);

    expect(cls.balance.mixGender, isFalse);
    await tester.tap(find.text('Mixer filles / garçons'));
    await tester.pumpAndSettle();
    expect(cls.balance.mixGender, isTrue);
  });
}
