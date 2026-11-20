import 'package:material_ui/material_ui.dart';

import 'package:plandeclasse/data/repository.dart';

/// Sur Web, aucune liaison `window_manager` (non compilable par dart2js).
@visibleForTesting
Future<Rect> Function()? debugWindowBoundsOverride;

@visibleForTesting
Future<void> Function()? debugWindowDestroyOverride;

Future<void> configureDesktopWindowAtStartup() async {}

mixin DesktopWindowAppState<T extends StatefulWidget> on State<T> {
  /// Référence au [Repository] pour persister les dimensions de fenêtre.
  Repository get desktopWindowRepository;

  void bindDesktopWindowLifecycle(Future<void> Function() flushPendingSaves) {}

  void unbindDesktopWindowLifecycle() {}
}
