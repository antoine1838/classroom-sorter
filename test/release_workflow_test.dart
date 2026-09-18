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
    androidWorkflow =
        File('.github/workflows/build-apk.yml').readAsStringSync();
    iosWorkflow =
        File('.github/workflows/build-ios.yml').readAsStringSync();
    version = RegExp(
      r'^version:\s+([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$',
      multiLine: true,
    ).firstMatch(pubspec)!;
  });

  test('la version migre au-dessus du dernier versionCode généré', () {
    expect(version.group(1), '1.12.0');
    expect(int.parse(version.group(2)!), greaterThan(118));
  });

  test('le changelog du build courant existe et respecte la limite Play',
      () {
    final buildNumber = version.group(2)!;
    final changelog = File(
        'store/play/metadata/fr-FR/changelogs/$buildNumber.txt');

    expect(changelog.existsSync(), isTrue);
    expect(changelog.readAsStringSync().trim(), isNotEmpty);
    expect(changelog.readAsStringSync().runes.length, lessThanOrEqualTo(500));
  });

  test('Android et iOS lisent le pubspec sans remplacer ses versions', () {
    for (final workflow in [androidWorkflow, iosWorkflow]) {
      expect(workflow, contains('Lire et valider la version du pubspec'));
      expect(workflow, contains(r"tr -d '\r'"),
          reason: 'les runners Linux doivent retirer le CR des fichiers CRLF');
      expect(workflow, contains(r'$GITHUB_REF_NAME" != "v$APP_VERSION'));
      expect(workflow, isNot(contains('--build-number=')));
      expect(workflow, isNot(contains('--build-name=')));
    }
  });

  test('la release Android exige changelog et secrets de signature', () {
    expect(androidWorkflow,
        contains(r'changelogs/$APP_BUILD_NUMBER.txt'));
    expect(androidWorkflow,
        contains('Vérifier les secrets de signature Play Store'));
    for (final secret in [
      'KEYSTORE_BASE64',
      'KEYSTORE_PASSWORD',
      'KEY_ALIAS',
      'KEY_PASSWORD',
    ]) {
      expect(androidWorkflow, contains(secret));
    }
    expect(androidWorkflow,
        contains('Secret de signature manquant'));
    expect(androidWorkflow, contains('flutter build appbundle --release'));
  });
}
