// Écran Réglages : le choix de vue Élèves doit se refléter dans l'état global
// et être persisté (c'est le même réglage que le raccourci dans l'onglet Élèves).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/student.dart';
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

  testWidgets(
      'affiche les 5 palettes de couleurs, vert canard/corail sélectionnée par défaut',
      (t) async {
    final state = await _pump(t);

    expect(find.text('Couleurs garçon / fille'), findsOneWidget);
    for (final palette in GenderColorPalette.values) {
      expect(find.text(palette.label), findsOneWidget);
    }

    final chip = t.widget<ChoiceChip>(find.ancestor(
      of: find.text(GenderColorPalette.tealCorail.label),
      matching: find.byType(ChoiceChip),
    ));
    expect(chip.selected, isTrue);
    expect(state.genderColorPalette, GenderColorPalette.tealCorail);
  });

  testWidgets('choisir une palette met à jour l\'état global', (t) async {
    final state = await _pump(t);

    await t.tap(find.text(GenderColorPalette.vertRose.label));
    await t.pumpAndSettle();

    expect(state.genderColorPalette, GenderColorPalette.vertRose);
  });

  testWidgets('les 5 palettes tiennent sur un écran étroit sans débordement',
      (t) async {
    t.view.devicePixelRatio = 1.0;
    t.view.physicalSize = const Size(320, 800);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await _pump(t);

    expect(t.takeException(), isNull);
  });
}
