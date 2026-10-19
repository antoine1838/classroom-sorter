/// Historique local des plans archivés pour une classe.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/classroom.dart';
import '../models/plan_snapshot.dart';
import '../models/student.dart';
import '../services/plan_pdf_service.dart';

typedef SnapshotPdfExporter = Future<void> Function(
  ClassGroup classGroup,
  GenderColorPalette palette,
);

class PlanHistoryScreen extends StatelessWidget {
  const PlanHistoryScreen({
    super.key,
    required this.state,
    required this.classGroup,
    this.exportPdf = _defaultExportPdf,
  });

  final AppState state;
  final ClassGroup classGroup;
  final SnapshotPdfExporter exportPdf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.planHistory)),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final snapshots = classGroup.snapshots.reversed.toList();
          final sameDayCounts = <String, int>{};
          for (final snapshot in snapshots) {
            final key = _dayKey(snapshot.createdAt.toLocal());
            sameDayCounts[key] = (sameDayCounts[key] ?? 0) + 1;
          }
          if (snapshots.isEmpty) {
            return Center(child: Text(l10n.noPlanArchives));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: snapshots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final snapshot = snapshots[index];
              return _snapshotCard(
                context,
                snapshot,
                showTime:
                    sameDayCounts[_dayKey(snapshot.createdAt.toLocal())]! > 1,
              );
            },
          );
        },
      ),
    );
  }

  Widget _snapshotCard(
    BuildContext context,
    PlanSnapshot snapshot, {
    required bool showTime,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(snapshot.createdAt.toLocal());
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(snapshot.createdAt.toLocal()));
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(snapshot.label.isEmpty ? l10n.planTab : snapshot.label),
        subtitle: Text(l10n.archiveDate(showTime ? '$date · $time' : date)),
        onTap: () => _exportPdf(snapshot),
        trailing: PopupMenuButton<_SnapshotAction>(
          onSelected: (action) => switch (action) {
            _SnapshotAction.exportPdf => _exportPdf(snapshot),
            _SnapshotAction.restore => _restore(context, snapshot),
            _SnapshotAction.delete => _delete(context, snapshot),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _SnapshotAction.exportPdf,
              child: Text(l10n.exportPdf),
            ),
            PopupMenuItem(
              value: _SnapshotAction.restore,
              child: Text(l10n.restoreArchive),
            ),
            PopupMenuItem(
              value: _SnapshotAction.delete,
              child: Text(l10n.delete),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(PlanSnapshot snapshot) {
    final preview = snapshot.toClassGroup(id: 'preview', name: classGroup.name);
    return exportPdf(preview, state.genderColorPalette);
  }

  static Future<void> _defaultExportPdf(
    ClassGroup classGroup,
    GenderColorPalette genderPalette,
  ) => PlanPdfService().export(classGroup, genderPalette: genderPalette);

  Future<void> _restore(BuildContext context, PlanSnapshot snapshot) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreArchive),
        content: Text(l10n.restoreArchiveDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restoreArchive),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    state.restorePlanSnapshot(classGroup, snapshot);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.archiveRestored)));
  }

  Future<void> _delete(BuildContext context, PlanSnapshot snapshot) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteArchiveTitle),
        content: Text(l10n.deleteArchiveDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) state.deletePlanSnapshot(classGroup, snapshot.id);
  }

  String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

enum _SnapshotAction { exportPdf, restore, delete }
