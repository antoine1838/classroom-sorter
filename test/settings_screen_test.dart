// Écran Réglages : le choix de vue Élèves doit se refléter dans l'état global
// et être persisté (c'est le même réglage que le raccourci dans l'onglet Élèves).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/screens/settings_screen.dart';

Future<AppState> _pump(WidgetTester tester) async {
  final state = AppState();
  await state.init();
  await tester.pumpWidget(MaterialApp(home: SettingsScreen(state: state)));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('affiche les deux vues, Complète sélectionnée par défaut',
      (t) async {
    final state = await _pump(t);

    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Vue Élèves'), findsOneWidget);
    expect(find.text('Complète'), findsOneWidget);
    expect(find.text('Compacte'), findsOneWidget);
    expect(state.studentsViewMode, StudentsViewMode.complete);
  });

  testWidgets('choisir Compacte met à jour l\'état global', (t) async {
    final state = await _pump(t);

    await t.tap(find.text('Compacte'));
    await t.pumpAndSettle();

    expect(state.studentsViewMode, StudentsViewMode.compact);

    // Le bouton segmenté doit refléter le nouveau choix.
    final button = t.widget<SegmentedButton<StudentsViewMode>>(
        find.byType(SegmentedButton<StudentsViewMode>));
    expect(button.selected, {StudentsViewMode.compact});

    // La persistance elle-même est vérifiée dans app_state_test.dart : ici on
    // ne teste que l'écran. (Attendre une écriture réelle dans un testWidgets
    // demanderait runAsync, l'horloge y étant factice.)
  });

  testWidgets('revenir à Complète refonctionne', (t) async {
    final state = await _pump(t);

    await t.tap(find.text('Compacte'));
    await t.pumpAndSettle();
    await t.tap(find.text('Complète'));
    await t.pumpAndSettle();

    expect(state.studentsViewMode, StudentsViewMode.complete);
  });
}
