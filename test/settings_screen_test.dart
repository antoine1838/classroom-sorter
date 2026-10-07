// Écran Réglages : le choix de vue Élèves doit se refléter dans l'état global
// et être persisté (c'est le même réglage que le raccourci dans l'onglet Élèves).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/settings_screen.dart';

Future<AppState> _pump(WidgetTester tester) async {
  final state = AppState();
  await state.init();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(state: state),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

Future<void> _pumpEnglishSettings(WidgetTester tester, AppState state) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(state: state),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('affiche les deux vues, Complète sélectionnée par défaut', (
    t,
  ) async {
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
      find.byType(SegmentedButton<StudentsViewMode>),
    );
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
      for (final label in const [
        'Violet / ambre',
        'Vert canard / corail',
        'Bleu / rose',
        'Bleu / orange',
        'Vert / rose',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      final chip = t.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('Vert canard / corail'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(chip.selected, isTrue);
      expect(state.genderColorPalette, GenderColorPalette.tealCorail);
    },
  );

  testWidgets('choisir une palette met à jour l\'état global', (t) async {
    final state = await _pump(t);

    await t.tap(find.text('Vert / rose'));
    await t.pumpAndSettle();

    expect(state.genderColorPalette, GenderColorPalette.vertRose);
  });

  testWidgets('choisir English met à jour la préférence de langue', (t) async {
    final state = await _pump(t);

    await t.tap(find.text('English'));
    await t.pumpAndSettle();

    expect(state.localePreference, LocalePreference.english);
    expect(state.locale?.languageCode, 'en');
  });

  testWidgets('les réglages sont affichés en anglais', (t) async {
    final state = AppState();
    await state.init();

    await _pumpEnglishSettings(t, state);
    await t.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Students view'), findsOneWidget);
  });

  testWidgets('les 5 palettes tiennent sur un écran étroit sans débordement', (
    t,
  ) async {
    t.view.devicePixelRatio = 1.0;
    t.view.physicalSize = const Size(320, 800);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await _pump(t);

    expect(t.takeException(), isNull);
  });
}
