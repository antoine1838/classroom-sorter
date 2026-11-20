// Le texte qui prévient, après un import, que des données incohérentes ont été
// retirées : singulier, pluriel, énumération, dans les deux langues.
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/l10n/data_cleanup_localizations.dart';
import 'package:plandeclasse/l10n/generated/app_localizations_en.dart';
import 'package:plandeclasse/l10n/generated/app_localizations_fr.dart';
import 'package:plandeclasse/models/classroom.dart';

void main() {
  final fr = AppLocalizationsFr();
  final en = AppLocalizationsEn();

  test('une seule place retirée, au singulier', () {
    const cleanup = DataCleanup(placesRemoved: 1);

    expect(
      localizedDataCleanup(cleanup, fr),
      'Pour rester cohérent, l’import a retiré 1 place du plan incohérente.',
    );
    expect(
      localizedDataCleanup(cleanup, en),
      'To stay consistent, the import removed 1 inconsistent seat assignment.',
    );
  });

  test('plusieurs éléments, au pluriel et dans l\'ordre places, règles, élèves', () {
    const cleanup = DataCleanup(
      placesRemoved: 3,
      rulesRemoved: 2,
      studentsRemoved: 4,
    );

    expect(
      localizedDataCleanup(cleanup, fr),
      'Pour rester cohérent, l’import a retiré 3 places du plan incohérentes, '
      '2 règles qui nommaient un élève absent, 4 élèves en double.',
    );
    expect(
      localizedDataCleanup(cleanup, en),
      'To stay consistent, the import removed 3 inconsistent seat assignments, '
      '2 rules naming a missing student, 4 duplicate students.',
    );
  });

  test('un type qui n\'a rien retiré n\'apparaît pas', () {
    const cleanup = DataCleanup(rulesRemoved: 1);

    final text = localizedDataCleanup(cleanup, fr);

    expect(text, contains('1 règle'));
    expect(text, isNot(contains('place')));
    expect(text, isNot(contains('élève en double')));
  });

  test('les archives illisibles ont leur compteur dans les deux langues', () {
    const cleanup = DataCleanup(snapshotsRemoved: 2);

    expect(
      localizedDataCleanup(cleanup, fr),
      'Pour rester cohérent, l’import a retiré 2 archives illisibles.',
    );
    expect(
      localizedDataCleanup(cleanup, en),
      'To stay consistent, the import removed 2 unreadable archives.',
    );
  });

  test('le chargement local précise que les classes restent disponibles', () {
    const cleanup = DataCleanup(snapshotsRemoved: 1);

    expect(
      localizedPersistenceCleanup(cleanup, fr),
      'Certaines données incohérentes ont été ignorées au chargement : '
      '1 archive illisible. Les classes concernées restent disponibles.',
    );
    expect(
      localizedPersistenceCleanup(cleanup, en),
      'Some inconsistent data was ignored while loading: '
      '1 unreadable archive. The affected classes remain available.',
    );
  });
}
