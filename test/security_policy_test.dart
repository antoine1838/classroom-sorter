import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la politique fournit un canal privé sans données d’élèves', () {
    final file = File('SECURITY.md');

    expect(file.existsSync(), isTrue);
    final policy = file.readAsStringSync();
    expect(
      policy,
      contains(
        'https://github.com/antoine1838/classroom-sorter/'
        'security/advisories/new',
      ),
    );
    expect(policy, contains("N'ouvrez pas de rapport public"));
    expect(policy, contains('Ne joignez jamais de vrais noms'));
    expect(policy, contains('français ou en anglais'));
  });
}
