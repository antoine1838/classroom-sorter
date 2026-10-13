/// Écran d'accueil : la liste des classes.
library;

import 'package:flutter/material.dart';

import '../actions/class_group_ops.dart';
import '../app_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/classroom.dart';
import '../tutorial/tutorial_guide.dart';
import 'class_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myClasses),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: l10n.addDemoClass,
            onPressed: () => _addDemoClass(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsScreen(state: state)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: l10n.tutorialTitle,
            onPressed: () => _startTutorial(context),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: l10n.homeHelp,
            onPressed: () =>
                showTutorialGuide(context, topic: TutorialTopic.home),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addClass(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newClass),
      ),
      // L'AppBar traite déjà l'encoche supérieure. Le contenu et l'action de
      // création doivent en revanche rester hors des barres latérales et de
      // navigation quand Android impose le rendu bord à bord.
      body: SafeArea(
        top: false,
        child: ListenableBuilder(listenable: state, builder: _buildBody),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Widget? _) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final content = _buildClassesContent(context);
    final message = state.persistenceMessage;
    final body = message == null
        ? content
        : _withPersistenceBanner(
            context,
            content,
            _localizedPersistenceMessage(context, message),
          );
    return Stack(
      children: [
        body,
        if (!state.tutorialSeen) _FirstTutorialPrompt(state: state),
      ],
    );
  }

  String _localizedPersistenceMessage(BuildContext context, String fallback) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return fallback;
    final messages = state.persistenceNotices.map(
      (notice) => switch (notice) {
        PersistenceNotice.classesRecovered => l10n.persistenceClassesRecovered,
        PersistenceNotice.roomsRecovered => l10n.persistenceRoomsRecovered,
        PersistenceNotice.classesCorrupted => l10n.persistenceClassesCorrupted,
        PersistenceNotice.roomsCorrupted => l10n.persistenceRoomsCorrupted,
        PersistenceNotice.saveFailed => l10n.persistenceSaveFailed,
      },
    );
    return messages.isEmpty ? fallback : messages.join('\n');
  }

  Widget _buildClassesContent(BuildContext context) {
    if (state.classes.isEmpty) {
      return _EmptyState(
        onAdd: () => _addClass(context),
        onAddDemo: () => _addDemoClass(context),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: state.classes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _buildClassCard(context, state.classes[i]),
    );
  }

  Widget _buildClassCard(BuildContext context, ClassGroup c) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(child: Text('${c.students.length}')),
        title: Text(
          c.name.isEmpty
              ? AppLocalizations.of(context)!.classDefaultName
              : c.name,
        ),
        subtitle: Text(
          AppLocalizations.of(
            context,
          )!.classSummary(c.students.length, c.room.capacity),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: AppLocalizations.of(context)!.delete,
          onPressed: () => _confirmDelete(context, c),
        ),
        onTap: () => _open(context, c),
      ),
    );
  }

  Widget _withPersistenceBanner(
    BuildContext context,
    Widget content,
    String message,
  ) {
    final isError = state.persistenceMessageIsError;
    final cs = Theme.of(context).colorScheme;
    final foreground = isError ? cs.onErrorContainer : cs.onTertiaryContainer;
    return Column(
      children: [
        MaterialBanner(
          leading: Icon(
            isError ? Icons.error_outline : Icons.restore,
            color: foreground,
          ),
          backgroundColor: isError ? cs.errorContainer : cs.tertiaryContainer,
          content: Text(message, style: TextStyle(color: foreground)),
          actions: [
            if (state.canRetryPersistence)
              TextButton(
                onPressed: state.retryPersistence,
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            TextButton(
              onPressed: state.dismissPersistenceMessage,
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        ),
        Expanded(child: content),
      ],
    );
  }

  void _open(BuildContext context, ClassGroup c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassEditorScreen(state: state, cls: c),
      ),
    );
  }

  Future<void> _addClass(BuildContext context) async {
    final name = await _promptText(
      context,
      title: AppLocalizations.of(context)!.className,
      hint: AppLocalizations.of(context)!.classNameHint,
      okLabel: AppLocalizations.of(context)!.create,
    );
    if (name == null) return;
    final c = state.addClass(name);

    if (context.mounted) {
      // Salle neuve, aucun plan à perdre : la disposition est proposée tout
      // de suite plutôt que de laisser l'utilisateur la découvrir plus tard
      // dans l'onglet Salle. Annuler garde la salle par défaut.
      final result = await pickInitialRoomLayout(
        context,
        state: state,
        initialRows: c.room.rows,
        initialCols: c.room.cols,
      );
      if (result != null) {
        final (room, savedRoomId) = result;
        ClassGroupOps(
          c,
          commit: state.touch,
        ).applyRoom(room, savedRoomId: savedRoomId);
      }
    }

    if (context.mounted) _open(context, c);
  }

  Future<void> _addDemoClass(BuildContext context) async {
    final c = await state.addDemoClass();
    if (context.mounted) _open(context, c);
  }

  Future<void> _startTutorial(BuildContext context) async {
    state.markTutorialSeen();
    await showTutorialGuide(
      context,
      topic: TutorialTopic.home,
      continuesTutorial: true,
    );
    if (!context.mounted) return;
    final demo = await state.loadTemporaryDemoClass();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ClassEditorScreen(state: state, cls: demo, startTutorial: true),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ClassGroup c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteClassTitle),
        content: Text(
          AppLocalizations.of(context)!.deleteClassDescription(c.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    if (ok == true) state.deleteClass(c);
  }
}

class _FirstTutorialPrompt extends StatefulWidget {
  const _FirstTutorialPrompt({required this.state});

  final AppState state;

  @override
  State<_FirstTutorialPrompt> createState() => _FirstTutorialPromptState();
}

class _FirstTutorialPromptState extends State<_FirstTutorialPrompt> {
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.state.tutorialSeen) return;
      final start = await showTutorialWelcome(context);
      widget.state.markTutorialSeen();
      if (start != true || !mounted) return;
      await showTutorialGuide(
        context,
        topic: TutorialTopic.home,
        continuesTutorial: true,
      );
      if (!mounted) return;
      final demo = await widget.state.loadTemporaryDemoClass();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClassEditorScreen(
            state: widget.state,
            cls: demo,
            startTutorial: true,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: Text(okLabel),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onAddDemo;
  const _EmptyState({required this.onAdd, required this.onAddDemo});

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
            Text(
              AppLocalizations.of(context)!.noClasses,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.emptyClassesDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(AppLocalizations.of(context)!.createFirstClass),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onAddDemo,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(AppLocalizations.of(context)!.demoClass),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
