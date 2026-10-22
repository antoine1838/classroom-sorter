/// Texte affiché quand l'import d'un fichier a dû retirer des données
/// incohérentes.
library;

import '../models/classroom.dart';
import 'generated/app_localizations.dart';

/// Phrase qui énumère ce que [cleanup] a retiré, dans la langue de [l10n].
/// À n'appeler que si [DataCleanup.isEmpty] est faux.
String localizedDataCleanup(DataCleanup cleanup, AppLocalizations l10n) {
  final parts = [
    if (cleanup.placesRemoved > 0)
      l10n.importCleanedPlaces(cleanup.placesRemoved),
    if (cleanup.rulesRemoved > 0) l10n.importCleanedRules(cleanup.rulesRemoved),
    if (cleanup.studentsRemoved > 0)
      l10n.importCleanedStudents(cleanup.studentsRemoved),
  ];
  return l10n.importCleanedIntro(parts.join(', '));
}
