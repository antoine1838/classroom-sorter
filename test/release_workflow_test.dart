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

List<String> workflowNames() {
  final names = [
    for (final file in Directory('.github/workflows').listSync())
      if (file is File && file.path.endsWith('.yml'))
        file.uri.pathSegments.last,
  ];
  expect(names, isNotEmpty);
  return names;
}

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

  // La version X.Y.Z n'est plus figée ici : elle vient du pubspec (déjà lue et
  // validée par `version`) et chaque release la fait évoluer. Seul le
  // versionCode a un plancher, pour ne jamais repasser sous un code déjà publié.
  test('le build number dépasse le dernier versionCode généré', () {
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
    for (final name in workflowNames()) {
      for (final job in jobBlocks(readWorkflow(name)).entries) {
        expect(
          timeout.hasMatch(job.value),
          isTrue,
          reason: '$name : le job ${job.key} sans timeout-minutes',
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

  test('toutes les actions sont épinglées par SHA avec leur version', () {
    // `uses: owner/action@<sha40> # vX.Y.Z` : le commentaire permet à
    // Dependabot de mettre à jour le SHA et la version ensemble.
    final uses = RegExp(r'^\s*(?:-\s+)?uses:\s*(\S+)(.*)$', multiLine: true);
    final pinned = RegExp(r'^[\w.-]+/[\w./-]+@[0-9a-f]{40}$');
    for (final name in workflowNames()) {
      for (final match in uses.allMatches(readWorkflow(name))) {
        final reason = '$name : ${match.group(1)}';
        expect(pinned.hasMatch(match.group(1)!), isTrue, reason: reason);
        expect(match.group(2), matches(r'^ # v\d+(\.\d+)*$'), reason: reason);
      }
    }
  });

  test('la clé de signature n\'existe que dans le workflow de release', () {
    expect(ciWorkflow, isNot(contains('secrets.')));
    expect(releaseWorkflow, isNot(contains('pull_request')));
    expect(releaseWorkflow, contains("tags: [ 'v*' ]"));
  });

  test('la release analyse et teste avant d\'écrire le keystore', () {
    final analyze = releaseWorkflow.indexOf('run: flutter analyze');
    final tests = releaseWorkflow.indexOf('run: flutter test');
    final keystore = releaseWorkflow.indexOf('keystore.jks');
    final firstBuild = releaseWorkflow.indexOf('run: flutter build');

    expect(analyze, isNonNegative, reason: 'flutter analyze manquant');
    expect(tests, isNonNegative, reason: 'flutter test manquant');
    expect(analyze, lessThan(keystore));
    expect(tests, lessThan(keystore));
    expect(keystore, lessThan(firstBuild));
  });

  test('la release n\'a le droit d\'écriture que dans son job', () {
    expect(
      releaseWorkflow,
      contains('\npermissions:\n  contents: read\n'),
      reason: 'permissions par défaut du workflow = lecture seule',
    );
    final jobs = jobBlocks(releaseWorkflow);
    expect(jobs.keys, ['build-release', 'publish-play']);
    expect(jobs['build-release'], contains('contents: write'));
    expect(jobs['publish-play'], isNot(contains('contents: write')));
    expect(
      releaseWorkflow.indexOf('contents: write'),
      greaterThan(releaseWorkflow.indexOf('\njobs:\n')),
    );
  });

  test('une release n\'est jamais annulée en cours de route', () {
    expect(releaseWorkflow, contains('cancel-in-progress: false'));
    expect(releaseWorkflow, isNot(contains('cancel-in-progress: true')));
  });

  test('les secrets de signature ne sont pas exposés à tout le job', () {
    // Aucun `env:` avec secrets au niveau du job : seules les étapes de
    // contrôle et d'écriture du keystore les reçoivent (analyze/test non).
    final job = jobBlocks(releaseWorkflow)['build-release']!;
    final jobHeader = job.substring(0, job.indexOf('\n    steps:'));
    expect(jobHeader, isNot(contains('secrets.')));

    for (final step in job.split('\n      - name: ')) {
      if (step.startsWith('Analyser le projet') ||
          step.startsWith('Lancer les tests')) {
        expect(step, isNot(contains('secrets.')), reason: step);
      }
    }
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

  group('publication Play (brouillon en production, sans clé stockée)', () {
    late String publish;
    late String build;

    setUpAll(() {
      final jobs = jobBlocks(releaseWorkflow);
      publish = jobs['publish-play']!;
      build = jobs['build-release']!;
    });

    test(
      'attend la release, sur tag seulement, et reste inerte sans config',
      () {
        expect(publish, contains('needs: build-release'));
        expect(publish, contains("startsWith(github.ref, 'refs/tags/v')"));
        expect(
          publish,
          contains("vars.GCP_WORKLOAD_IDENTITY_PROVIDER != ''"),
          reason:
              'tant que la variable n\'est pas posée, la release reste telle '
              'qu\'avant',
        );
      },
    );

    test('dépose un brouillon sur la production de l\'appli', () {
      final applicationId = RegExp(r'applicationId\s*=\s*"([^"]+)"')
          .firstMatch(File('android/app/build.gradle.kts').readAsStringSync())!;

      expect(publish, contains('packageName: ${applicationId.group(1)}'));
      expect(publish, contains('track: production'));
      expect(
        publish,
        contains('status: draft'),
        reason: 'rien n\'atteint les utilisateurs sans le clic de l\'éditeur',
      );
      expect(publish, isNot(contains('status: completed')));
    });

    test('passe par un environnement et un jeton OIDC, jamais une clé', () {
      expect(publish, contains('environment: play-production'));
      expect(publish, contains('id-token: write'));
      expect(publish, contains('contents: read'));
      expect(publish, contains('google-github-actions/auth@'));
      expect(publish, contains('workload_identity_provider:'));
      expect(publish, isNot(contains('secrets.')));
      expect(publish, isNot(contains('serviceAccountJsonPlainText')));
      expect(publish, isNot(contains('credentials_json')));
      expect(
        build,
        isNot(contains('id-token')),
        reason: 'le job qui voit le keystore ne reçoit pas de jeton OIDC',
      );
    });

    test(
      'envoie l\'AAB et les notes du build courant, dans les deux langues',
      () {
        // Le nom de l'artefact est celui que le job de build publie, et le
        // numéro de build celui qu'il a validé : rien n'est redéduit ici.
        expect(
          build,
          contains(r'name: classroom-sorter-${{ env.APK_LABEL }}-aab'),
        );
        expect(
          publish,
          contains(
            r'name: classroom-sorter-${{ needs.build-release.outputs.version }}'
            '-aab',
          ),
        );
        expect(
          build,
          contains('build-number: \${{ steps.version.outputs.build-number }}'),
        );
        expect(
          publish,
          contains(r'${{ needs.build-release.outputs.build-number }}'),
        );
        expect(publish, contains('for locale in ${locales.join(' ')}; do'));
        expect(
          publish,
          contains(
            r'changelogs/$BUILD_NUMBER.txt" "build/whatsnew/whatsnew-$locale"',
          ),
        );
        expect(publish, contains('whatsNewDirectory: build/whatsnew'));
      },
    );
  });
}
