// ignore_for_file: deprecated_member_use

// Mémorisation de la taille et de la position de la fenêtre sur bureau
// (lib/main.dart). window_manager 0.7 s’appuie sur nativeapi : en VM de test,
// on simule les limites via [debugWindowBoundsOverride] et on déclenche les
// rappels [WindowListener] à la main.
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/legacy.dart';

import 'package:plandeclasse/data/repository.dart';
import 'package:plandeclasse/desktop_window.dart';
import 'package:plandeclasse/main.dart';

typedef _Bounds = ({double x, double y, double width, double height});

Future<_Bounds?> _savedBounds(WidgetTester tester) async =>
    tester.runAsync<_Bounds?>(Repository().loadWindowBounds);

/// Exécute [body] avec Windows comme plateforme. flutter_test vérifie à la fin
/// du test que la surcharge a été retirée : elle l’est donc ici, pas dans un
/// `tearDown`, qui passerait trop tard.
Future<void> _onDesktop(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await body();
    await tester.pumpWidget(const SizedBox());
  } finally {
    debugDefaultTargetPlatformOverride = null;
    debugWindowBoundsOverride = null;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'sur bureau, redimensionner puis déplacer la fenêtre est mémorisé',
    (tester) => _onDesktop(tester, () async {
      var bounds = const Rect.fromLTWH(10, 20, 900, 600);
      debugWindowBoundsOverride = () async => bounds;
      await tester.pumpWidget(const ClassroomSortApp());
      await tester.pump();

      expect(await _savedBounds(tester), isNull);

      final listener = windowManager.listeners.single;
      listener.onWindowResized();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      expect(await _savedBounds(tester), (
        x: 10.0,
        y: 20.0,
        width: 900.0,
        height: 600.0,
      ));

      bounds = const Rect.fromLTWH(300, 120, 1100, 700);
      listener.onWindowMoved();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      expect(await _savedBounds(tester), (
        x: 300.0,
        y: 120.0,
        width: 1100.0,
        height: 700.0,
      ));
    }),
  );

  testWidgets(
    'fermer l\'application cesse d\'écouter la fenêtre',
    (tester) => _onDesktop(tester, () async {
      debugWindowBoundsOverride = () async =>
          const Rect.fromLTWH(10, 20, 900, 600);
      await tester.pumpWidget(const ClassroomSortApp());
      await tester.pump();

      final listener = windowManager.listeners.single;
      listener.onWindowResized();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(windowManager.listeners, isEmpty);
      listener.onWindowMoved();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      expect((await _savedBounds(tester))?.x, 10.0);
    }),
  );

  testWidgets(
    'sans override, la sauvegarde utilise getBounds',
    (tester) => _onDesktop(tester, () async {
      debugWindowBoundsOverride = null;
      await tester.pumpWidget(const ClassroomSortApp());
      await tester.pump();

      final listener = windowManager.listeners.single;
      listener.onWindowResized();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      // En VM, getBounds() renvoie (0,0,0,0) : l’important est d’exécuter la branche prod.
      expect(await _savedBounds(tester), (
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
      ));
    }),
  );

  testWidgets('sur mobile, la fenêtre n\'est pas écoutée', (tester) async {
    await tester.pumpWidget(const ClassroomSortApp());
    await tester.pump();

    expect(windowManager.listeners, isEmpty);
    expect(await _savedBounds(tester), isNull);
  });
}
