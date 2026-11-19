// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/desktop_window.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('configureDesktopWindowAtStartup ne fait rien hors bureau', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await configureDesktopWindowAtStartup();
  });

  test(
    'configureDesktopWindowAtStartup initialise la fenêtre sur bureau',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await configureDesktopWindowAtStartup();
    },
  );

  test(
    'configureDesktopWindowAtStartup restaure les limites sauvegardées',
    () async {
      SharedPreferences.setMockInitialValues({
        'plandeclasse_window_bounds_v1': '120,80,1100,700',
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await configureDesktopWindowAtStartup();
    },
  );
}
