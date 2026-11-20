// Test « fumée » : l'application démarre et affiche l'écran d'accueil.
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/main.dart';
import 'package:plandeclasse/main.dart' as app;

class _TrackingAppState extends AppState {
  int flushCount = 0;

  @override
  Future<void> flushPendingSaves() async {
    flushCount++;
    await super.flushPendingSaves();
  }
}

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

  testWidgets('le passage en arrière-plan attend les sauvegardes en cours', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final state = _TrackingAppState();
    await tester.runAsync(state.init);
    addTearDown(state.dispose);

    await tester.pumpWidget(ClassroomSortApp(debugState: state));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(state.flushCount, greaterThan(0));

    final countAfterPause = state.flushCount;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    expect(state.flushCount, greaterThan(countAfterPause));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    final countAfterDispose = state.flushCount;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(state.flushCount, countAfterDispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    debugDefaultTargetPlatformOverride = null;
  });
}
