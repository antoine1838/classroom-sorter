import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('active explicitement le mode Android bord à bord', () async {
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          call = methodCall;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await app.configureEdgeToEdge();

    expect(call?.method, 'SystemChrome.setEnabledSystemUIMode');

    call = null;
    await app.bootstrapApp();

    expect(call?.method, 'SystemChrome.setEnabledSystemUIMode');
    expect(call?.arguments, 'SystemUiMode.edgeToEdge');
  });
}
