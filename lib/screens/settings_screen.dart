/// Écran Réglages : préférences globales de l'application.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
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
  return Row(mainAxisSize: MainAxisSize.min, children: [
    dot(garcon),
    const SizedBox(width: 3),
    dot(fille),
  ]);
}

class SettingsScreen extends StatelessWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Vue Élèves', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Choisissez comment les attributs des élèves (genre, niveau, '
              'énergie, taille, vue) s\'affichent dans l\'onglet Élèves.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            SegmentedButton<StudentsViewMode>(
              segments: const [
                ButtonSegment(
                  value: StudentsViewMode.complete,
                  label: Text('Complète'),
                  icon: Icon(Icons.table_rows_outlined),
                ),
                ButtonSegment(
                  value: StudentsViewMode.compact,
                  label: Text('Compacte'),
                  icon: Icon(Icons.view_week_outlined),
                ),
              ],
              selected: {state.studentsViewMode},
              onSelectionChanged: (selection) =>
                  state.setStudentsViewMode(selection.first),
            ),
            const SizedBox(height: 24),
            Text('Couleurs garçon / fille',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Choisissez les couleurs du liseré affiché sur la carte de '
              'chaque élève dans le plan de classe.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final palette in GenderColorPalette.values)
                  ChoiceChip(
                    avatar: _paletteIcon(palette),
                    showCheckmark: false,
                    label: Text(palette.label),
                    selected: state.genderColorPalette == palette,
                    onSelected: (_) => state.setGenderColorPalette(palette),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
