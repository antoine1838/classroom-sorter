// Test « fumée » : l'application démarre et affiche l'écran d'accueil.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/main.dart';

void main() {
  testWidgets("L'accueil s'affiche au démarrage", (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ClassroomSortApp());
    await tester.pumpAndSettle();

    expect(find.text('Mes classes'), findsOneWidget);
  });
}
