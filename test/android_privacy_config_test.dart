// Garde-fous statiques pour que les données élèves ne réintègrent pas
// accidentellement les sauvegardes système Android.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _section(String xml, String opening, String closing) {
  final start = xml.indexOf(opening);
  expect(start, greaterThanOrEqualTo(0), reason: '$opening absent');
  final end = xml.indexOf(closing, start);
  expect(end, greaterThan(start), reason: '$closing absent');
  return xml.substring(start, end);
}

void main() {
  late String manifest;
  late String legacyRules;
  late String extractionRules;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    legacyRules =
        File('android/app/src/main/res/xml/backup_rules.xml').readAsStringSync();
    extractionRules = File(
            'android/app/src/main/res/xml/data_extraction_rules.xml')
        .readAsStringSync();
  });

  test('le manifeste désactive explicitement Auto Backup', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
  });

  test('Android 11 et antérieurs excluent les préférences locales', () {
    expect(legacyRules, contains('<full-backup-content>'));
    expect(legacyRules,
        contains('<exclude domain="sharedpref" path="." />'));
  });

  test('Android 12+ exclut les préférences du cloud et du transfert', () {
    final cloud =
        _section(extractionRules, '<cloud-backup>', '</cloud-backup>');
    final transfer =
        _section(extractionRules, '<device-transfer>', '</device-transfer>');

    for (final section in [cloud, transfer]) {
      expect(section, contains('<exclude domain="sharedpref" path="." />'));
      expect(section,
          contains('<exclude domain="device_sharedpref" path="." />'));
    }
  });

  test('la politique de confidentialité décrit la protection Android', () {
    final policy = File('docs/index.html').readAsStringSync();

    expect(policy, contains('dernière mise à jour : 18 septembre 2026'));
    expect(
        RegExp(r'La sauvegarde\s+automatique Android est désactivée')
            .hasMatch(policy),
        isTrue);
    expect(
        RegExp(
                r'exclues des\s+sauvegardes cloud et des transferts automatiques')
            .hasMatch(policy),
        isTrue);
  });
}
