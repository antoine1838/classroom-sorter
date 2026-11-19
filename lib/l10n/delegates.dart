/// Délégués de localisation pour [MaterialApp].
///
/// Le fichier généré par `flutter gen-l10n` référence encore les délégués du
/// SDK ; on regroupe ici l'app + Material/Cupertino/Widgets via `material_ui`.
library;

import 'package:material_ui/material_ui.dart';

import 'generated/app_localizations.dart';

const List<LocalizationsDelegate<dynamic>> appLocalizationDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
