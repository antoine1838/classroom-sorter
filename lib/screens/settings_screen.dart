/// Écran Réglages : préférences globales de l'application.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';

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
          ],
        ),
      ),
    );
  }
}
