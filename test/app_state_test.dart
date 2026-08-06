// Vérifie la persistance du réglage global de vue Élèves (Complète/Compacte).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('StudentsViewMode : défaut Complète, persiste après changement',
      () async {
    final state = AppState();
    await state.init();
    expect(state.studentsViewMode, StudentsViewMode.complete);

    state.setStudentsViewMode(StudentsViewMode.compact);
    expect(state.studentsViewMode, StudentsViewMode.compact);

    // Une nouvelle instance (ex. redémarrage de l'appli) doit relire le
    // choix persisté plutôt que de retomber sur le défaut.
    final reloaded = AppState();
    await reloaded.init();
    expect(reloaded.studentsViewMode, StudentsViewMode.compact);
  });
}
