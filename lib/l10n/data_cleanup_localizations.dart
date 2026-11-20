/// Texte affiché quand l'import d'un fichier a dû retirer des données
/// incohérentes.
library;

import '../models/classroom.dart';
import 'generated/app_localizations.dart';

/// Phrase qui énumère ce que [cleanup] a retiré, dans la langue de [l10n].
/// À n'appeler que si [DataCleanup.isEmpty] est faux.
String localizedDataCleanup(DataCleanup cleanup, AppLocalizations l10n) {
  return l10n.importCleanedIntro(_localizedCleanupParts(cleanup, l10n));
}

/// Texte du bandeau affiché quand le stockage local contenait des éléments
/// internes incohérents, mais que les classes elles-mêmes ont pu être gardées.
String localizedPersistenceCleanup(DataCleanup cleanup, AppLocalizations l10n) {
  return l10n.persistenceClassesCleaned(_localizedCleanupParts(cleanup, l10n));
}

String _localizedCleanupParts(DataCleanup cleanup, AppLocalizations l10n) {
  final parts = <String>[
    if (cleanup.placesRemoved > 0)
      l10n.importCleanedPlaces(cleanup.placesRemoved),
    if (cleanup.rulesRemoved > 0) l10n.importCleanedRules(cleanup.rulesRemoved),
    if (cleanup.studentsRemoved > 0)
      l10n.importCleanedStudents(cleanup.studentsRemoved),
    if (cleanup.snapshotsRemoved > 0)
      l10n.importCleanedSnapshots(cleanup.snapshotsRemoved),
  ];
  return parts.join(', ');
}
