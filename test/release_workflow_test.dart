// Garde-fous statiques pour que la version du pubspec reste l'unique source
// de vérité des artefacts Android/iOS et des métadonnées Play Store.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Découpe un workflow en blocs `job -> texte` (le fichier peut être en CRLF,
// d'où la normalisation à la lecture).
Map<String, String> jobBlocks(String workflow) {
  final jobs = workflow.substring(workflow.indexOf('\njobs:\n'));
  final headers = RegExp(
    r'^  ([a-z][\w-]*):[ \t]*$',
    multiLine: true,
  ).allMatches(jobs).toList();
  return {
    for (var i = 0; i < headers.length; i++)
      headers[i].group(1)!: jobs.substring(
        headers[i].end,
        i + 1 < headers.length ? headers[i + 1].start : jobs.length,
      ),
  };
}

String readWorkflow(String name) =>
    File('.github/workflows/$name').readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  late String pubspec;
  late String releaseWorkflow;
  late String ciWorkflow;
  late RegExpMatch version;

  setUpAll(() {
    pubspec = File('pubspec.yaml').readAsStringSync();
    releaseWorkflow = readWorkflow('release.yml');
    ciWorkflow = readWorkflow('ci.yml');
    version = RegExp(
      r'^version:\s+([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$',
      multiLine: true,
    ).firstMatch(pubspec)!;
  });

  test('la version migre au-dessus du dernier versionCode généré', () {
    expect(version.group(1), '1.13.1');
    expect(int.parse(version.group(2)!), greaterThan(120));
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
    for (final workflow in [releaseWorkflow, ciWorkflow]) {
      expect(workflow, contains('Lire et valider la version du pubspec'));
      expect(
        workflow,
        contains(r"tr -d '\r'"),
        reason: 'les runners Linux doivent retirer le CR des fichiers CRLF',
      );
      expect(workflow, isNot(contains('--build-number=')));
      expect(workflow, isNot(contains('--build-name=')));
    }
    expect(releaseWorkflow, contains(r'$GITHUB_REF_NAME" != "v$APP_VERSION'));
  });

  test('la CI compile toutes les cibles après format, analyse et tests', () {
    expect(ciWorkflow, contains('pull_request:'));
    final jobs = jobBlocks(ciWorkflow);
    for (final job in [
      'build-web',
      'build-windows',
      'build-android',
      'build-ios',
      'benchmark-seating-engine',
    ]) {
      expect(jobs, contains(job));
      expect(
        jobs[job],
        contains('needs: [ format, analyze, test ]'),
        reason: '$job doit attendre format, analyze et test',
      );
    }
  });

  test('la CI lance flutter test dans son propre job', () {
    expect(jobBlocks(ciWorkflow)['test'], contains('run: flutter test'));
  });

  test('chaque job a un timeout, la CI annule les PR obsolètes', () {
    final timeout = RegExp(r'^    timeout-minutes: \d+$', multiLine: true);
    for (final entry in {'ci.yml': ciWorkflow}.entries) {
      for (final job in jobBlocks(entry.value).entries) {
        expect(
          timeout.hasMatch(job.value),
          isTrue,
          reason: '${entry.key} : le job ${job.key} sans timeout-minutes',
        );
      }
    }
    expect(
      ciWorkflow,
      contains(
        r"cancel-in-progress: ${{ github.event_name == 'pull_request' }}",
      ),
    );
  });

  test('la clé de signature n\'existe que dans le workflow de release', () {
    expect(ciWorkflow, isNot(contains('secrets.')));
    expect(releaseWorkflow, isNot(contains('pull_request')));
    expect(releaseWorkflow, contains("tags: [ 'v*' ]"));
  });

  test('la release Android exige changelog et secrets de signature', () {
    expect(releaseWorkflow, contains(r'changelogs/$APP_BUILD_NUMBER.txt'));
    expect(
      releaseWorkflow,
      contains('Vérifier les secrets de signature Play Store'),
    );
    for (final secret in [
      'KEYSTORE_BASE64',
      'KEYSTORE_PASSWORD',
      'KEY_ALIAS',
      'KEY_PASSWORD',
    ]) {
      expect(releaseWorkflow, contains(secret));
    }
    expect(releaseWorkflow, contains('Secret de signature manquant'));
    expect(releaseWorkflow, contains('flutter build appbundle --release'));
  });
}
