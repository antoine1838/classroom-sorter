import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/platform/is_desktop.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android n’est pas un bureau natif', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(isDesktopNativeApp, isFalse);
  });

  test('Windows est un bureau natif', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(isDesktopNativeApp, isTrue);
  });
}
