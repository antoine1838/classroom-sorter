/// Écran d'accueil : la liste des classes.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/classroom.dart';
import 'class_editor_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes classes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addClass(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle classe'),
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.classes.isEmpty) {
            return _EmptyState(onAdd: () => _addClass(context));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: state.classes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = state.classes[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(child: Text('${c.students.length}')),
                  title: Text(c.name.isEmpty ? 'Classe' : c.name),
                  subtitle: Text(
                      '${c.students.length} élève(s) · ${c.room.capacity} place(s)'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Supprimer',
                    onPressed: () => _confirmDelete(context, c),
                  ),
                  onTap: () => _open(context, c),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _open(BuildContext context, ClassGroup c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClassEditorScreen(state: state, cls: c),
    ));
  }

  Future<void> _addClass(BuildContext context) async {
    final name = await _promptText(
      context,
      title: 'Nom de la classe',
      hint: 'Ex. 6ème B',
      okLabel: 'Créer',
    );
    if (name == null) return;
    final c = state.addClass(name);
    if (context.mounted) _open(context, c);
  }

  Future<void> _confirmDelete(BuildContext context, ClassGroup c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la classe ?'),
        content: Text('« ${c.name} » sera définitivement supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) state.deleteClass(c);
  }
}

/// Petite boîte de dialogue « saisir un texte », réutilisable.
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  String hint = '',
  String initial = '',
  String okLabel = 'OK',
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(okLabel)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chair_alt_outlined, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text('Aucune classe pour le moment',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Créez une classe, ajoutez vos élèves, définissez vos règles, '
              'puis générez un plan de classe automatiquement.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Créer ma première classe'),
            ),
          ],
        ),
      ),
    );
  }
}
