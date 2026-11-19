import 'package:flutter/foundation.dart';

/// Bureau natif (Windows, macOS, Linux), sans Web.
bool get isDesktopNativeApp =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);
