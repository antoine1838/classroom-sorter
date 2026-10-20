// Mémorisation de la taille et de la position de la fenêtre sur bureau
// (lib/main.dart). Le plugin window_manager est simulé : on lui envoie les
// événements que le système d'exploitation lui enverrait quand l'utilisateur
// termine de redimensionner ou de déplacer la fenêtre, et on lit ce que
// l'application a enregistré. Ce que fait réellement Windows de ces valeurs au
// lancement suivant n'est pas vérifiable ici.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/data/repository.dart';
import 'package:plandeclasse/main.dart';

const _channel = MethodChannel('window_manager');

/// Simule la fenêtre : `getBounds` renvoie les dimensions courantes de [bounds].
void _mockWindow(WidgetTester tester, Rect Function() bounds) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
    call,
  ) async {
    if (call.method != 'getBounds') return null;
    final rect = bounds();
    return <String, Object?>{
      'x': rect.left,
      'y': rect.top,
      'width': rect.width,
      'height': rect.height,
    };
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    ),
  );
}

/// Envoie au plugin l'événement [eventName] (`resized`, `moved`…) puis laisse
/// aboutir l'enregistrement asynchrone qui en découle.
Future<void> _sendWindowEvent(WidgetTester tester, String eventName) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('onEvent', {'eventName': eventName}),
    ),
    (_) {},
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
}

typedef _Bounds = ({double x, double y, double width, double height});

Future<_Bounds?> _savedBounds(WidgetTester tester) async =>
    tester.runAsync<_Bounds?>(Repository().loadWindowBounds);

/// Exécute [body] avec Windows comme plateforme. flutter_test vérifie à la fin
/// du test que la surcharge a été retirée : elle l'est donc ici, pas dans un
/// `tearDown`, qui passerait trop tard. L'application est démontée avant,
/// toujours sous Windows : son `dispose` ne retire son écouteur du plugin
/// (un singleton) que sur bureau, et un écouteur resté en place recevrait les
/// événements des tests suivants.
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
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'sur bureau, redimensionner puis déplacer la fenêtre est mémorisé',
    (tester) => _onDesktop(tester, () async {
      var bounds = const Rect.fromLTWH(10, 20, 900, 600);
      _mockWindow(tester, () => bounds);
      await tester.pumpWidget(const ClassroomSortApp());
      await tester.pump();

      expect(await _savedBounds(tester), isNull);

      await _sendWindowEvent(tester, 'resized');
      expect(await _savedBounds(tester), (
        x: 10.0,
        y: 20.0,
        width: 900.0,
        height: 600.0,
      ));

      bounds = const Rect.fromLTWH(300, 120, 1100, 700);
      await _sendWindowEvent(tester, 'moved');
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
      var bounds = const Rect.fromLTWH(10, 20, 900, 600);
      _mockWindow(tester, () => bounds);
      await tester.pumpWidget(const ClassroomSortApp());
      await tester.pump();
      await _sendWindowEvent(tester, 'resized');

      await tester.pumpWidget(const SizedBox());
      bounds = const Rect.fromLTWH(500, 500, 400, 300);
      await _sendWindowEvent(tester, 'resized');

      expect((await _savedBounds(tester))?.x, 10.0);
    }),
  );

  testWidgets('sur mobile, la fenêtre n\'est pas écoutée', (tester) async {
    _mockWindow(tester, () => const Rect.fromLTWH(10, 20, 900, 600));
    await tester.pumpWidget(const ClassroomSortApp());
    await tester.pump();

    await _sendWindowEvent(tester, 'resized');

    expect(await _savedBounds(tester), isNull);
  });
}
