// Vérifie que la classe de démo (6ème B) se charge correctement depuis l'asset
// embarqué et reçoit un id frais à chaque ajout (pas de collision si on
// l'ajoute plusieurs fois).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Classe de démo : 20 élèves, un nouvel id à chaque ajout', () async {
    final state = AppState();
    await state.init();

    final c1 = await state.addDemoClass();
    expect(c1.name, '6ème B');
    expect(c1.students, hasLength(20));
    expect(c1.rules, hasLength(4));
    expect(state.classes, contains(c1));

    final c2 = await state.addDemoClass();
    expect(c2.id, isNot(c1.id));
    expect(state.classes, hasLength(2));
  });
}
