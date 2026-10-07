/// Écran Réglages : préférences globales de l'application.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/student.dart';
import '../widgets/seat_grid.dart' show genderPaletteColors;

/// Aperçu d'une palette (garçon, fille) pour le sélecteur ci-dessous. Doit
/// tenir dans la boîte 20×20 que [ChoiceChip] réserve à son avatar (sinon
/// débordement, voir issue #27 : plantage constaté sur écran étroit).
Widget _paletteIcon(GenderColorPalette palette) {
  final (garcon, fille) = genderPaletteColors(palette);
  Widget dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [dot(garcon), const SizedBox(width: 3), dot(fille)],
  );
}

class SettingsScreen extends StatelessWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.studentsView,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.studentsViewDescription, style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            SegmentedButton<StudentsViewMode>(
              segments: [
                ButtonSegment(
                  value: StudentsViewMode.complete,
                  label: Text(l10n.studentsViewComplete),
                  icon: const Icon(Icons.table_rows_outlined),
                ),
                ButtonSegment(
                  value: StudentsViewMode.compact,
                  label: Text(l10n.studentsViewCompact),
                  icon: const Icon(Icons.view_week_outlined),
                ),
              ],
              selected: {state.studentsViewMode},
              onSelectionChanged: (selection) =>
                  state.setStudentsViewMode(selection.first),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.genderColors,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.genderColorsDescription, style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final palette in GenderColorPalette.values)
                  ChoiceChip(
                    avatar: _paletteIcon(palette),
                    showCheckmark: false,
                    label: Text(_paletteLabel(palette, l10n)),
                    selected: state.genderColorPalette == palette,
                    onSelected: (_) => state.setGenderColorPalette(palette),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l10n.language, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.languageDescription,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            SegmentedButton<LocalePreference>(
              segments: [
                ButtonSegment(
                  value: LocalePreference.system,
                  label: Text(l10n.languageSystem),
                ),
                ButtonSegment(
                  value: LocalePreference.french,
                  label: Text(l10n.languageFrench),
                ),
                ButtonSegment(
                  value: LocalePreference.english,
                  label: Text(l10n.languageEnglish),
                ),
              ],
              selected: {state.localePreference},
              onSelectionChanged: (selection) =>
                  state.setLocalePreference(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}

String _paletteLabel(GenderColorPalette palette, AppLocalizations l10n) =>
    switch (palette) {
      GenderColorPalette.violetAmbre => l10n.paletteVioletAmber,
      GenderColorPalette.tealCorail => l10n.paletteTealCoral,
      GenderColorPalette.bleuRoseAdouci => l10n.paletteBlueSoftPink,
      GenderColorPalette.bleuOrange => l10n.paletteBlueOrange,
      GenderColorPalette.vertRose => l10n.paletteGreenPink,
    };
