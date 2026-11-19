// Test « fumée » : l'application démarre et affiche l'écran d'accueil.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/main.dart';
import 'package:plandeclasse/main.dart' as app;

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets("L'accueil s'affiche au démarrage", (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ClassroomSortApp());
    await tester.pumpAndSettle();

    expect(find.text('My classes'), findsOneWidget);
  });

  test('bootstrapApp initialise sur mobile', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await app.bootstrapApp();
  });
}
