// Garde-fous statiques pour que la version du pubspec reste l'unique source
// de vérité des artefacts Android/iOS et des métadonnées Play Store.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String pubspec;
  late String androidWorkflow;
  late String iosWorkflow;
  late RegExpMatch version;

  setUpAll(() {
    pubspec = File('pubspec.yaml').readAsStringSync();
    androidWorkflow = File(
      '.github/workflows/build-apk.yml',
    ).readAsStringSync();
    iosWorkflow = File('.github/workflows/build-ios.yml').readAsStringSync();
    version = RegExp(
      r'^version:\s+([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$',
      multiLine: true,
    ).firstMatch(pubspec)!;
  });

  test('la version migre au-dessus du dernier versionCode généré', () {
    expect(version.group(1), '1.12.0');
    expect(int.parse(version.group(2)!), greaterThan(118));
  });

  const locales = ['fr-FR', 'en-US'];

  test('le changelog du build courant existe et respecte la limite Play', () {
    final buildNumber = version.group(2)!;
    for (final locale in locales) {
      final changelog = File(
        'store/play/metadata/$locale/changelogs/$buildNumber.txt',
      );

      expect(changelog.existsSync(), isTrue, reason: locale);
      expect(changelog.readAsStringSync().trim(), isNotEmpty, reason: locale);
      expect(
        changelog.readAsStringSync().runes.length,
        lessThanOrEqualTo(500),
        reason: locale,
      );
    }
  });

  test('chaque langue de la fiche Play respecte les limites de caractères', () {
    const limits = {
      'title.txt': 30,
      'short_description.txt': 80,
      'full_description.txt': 4000,
    };
    for (final locale in locales) {
      for (final entry in limits.entries) {
        final file = File('store/play/metadata/$locale/${entry.key}');
        expect(file.existsSync(), isTrue, reason: '$locale/${entry.key}');
        final text = file.readAsStringSync().trim();
        expect(text, isNotEmpty, reason: '$locale/${entry.key}');
        expect(
          text.runes.length,
          lessThanOrEqualTo(entry.value),
          reason: '$locale/${entry.key}',
        );
      }
    }
  });

  test('Android et iOS lisent le pubspec sans remplacer ses versions', () {
    for (final workflow in [androidWorkflow, iosWorkflow]) {
      expect(workflow, contains('Lire et valider la version du pubspec'));
      expect(
        workflow,
        contains(r"tr -d '\r'"),
        reason: 'les runners Linux doivent retirer le CR des fichiers CRLF',
      );
      expect(workflow, contains(r'$GITHUB_REF_NAME" != "v$APP_VERSION'));
      expect(workflow, isNot(contains('--build-number=')));
      expect(workflow, isNot(contains('--build-name=')));
    }
  });

  test('la release Android exige changelog et secrets de signature', () {
    expect(androidWorkflow, contains(r'changelogs/$APP_BUILD_NUMBER.txt'));
    expect(
      androidWorkflow,
      contains('Vérifier les secrets de signature Play Store'),
    );
    for (final secret in [
      'KEYSTORE_BASE64',
      'KEYSTORE_PASSWORD',
      'KEY_ALIAS',
      'KEY_PASSWORD',
    ]) {
      expect(androidWorkflow, contains(secret));
    }
    expect(androidWorkflow, contains('Secret de signature manquant'));
    expect(androidWorkflow, contains('flutter build appbundle --release'));
  });
}
