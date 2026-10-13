import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plandeclasse/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(call?.arguments, 'SystemUiMode.edgeToEdge');
  });
}
