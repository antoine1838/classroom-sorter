// bridge legacy window_manager 0.7 : migration vers l'API nativeapi hors scope.
// ignore_for_file: deprecated_member_use

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/legacy.dart';

import 'package:plandeclasse/data/repository.dart';
import 'package:plandeclasse/platform/is_desktop.dart';

const _kDefaultWindowSize = Size(1280, 800);

/// En tests widget, nativeapi n’est pas chargée : ce hook évite `getBounds()`
/// toujours à zéro.
@visibleForTesting
Future<Rect> Function()? debugWindowBoundsOverride;

Future<void> configureDesktopWindowAtStartup() async {
  if (!isDesktopNativeApp) return;
  await windowManager.ensureInitialized();
  final saved = await Repository().loadWindowBounds();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: saved == null
          ? _kDefaultWindowSize
          : Size(saved.width, saved.height),
      title: 'Plan de classe',
    ),
    () async {
      if (saved != null) {
        await windowManager.setPosition(Offset(saved.x, saved.y));
      }
      await windowManager.show();
      await windowManager.focus();
    },
  );
}

mixin DesktopWindowAppState<T extends StatefulWidget> on State<T> {
  Repository get desktopWindowRepository;

  _DesktopWindowPersistenceListener? _desktopWindowListener;

  void bindDesktopWindowLifecycle() {
    if (!isDesktopNativeApp) return;
    _desktopWindowListener ??= _DesktopWindowPersistenceListener(
      desktopWindowRepository,
    );
    windowManager.addListener(_desktopWindowListener!);
  }

  void unbindDesktopWindowLifecycle() {
    if (!isDesktopNativeApp || _desktopWindowListener == null) return;
    windowManager.removeListener(_desktopWindowListener!);
    _desktopWindowListener = null;
  }
}

class _DesktopWindowPersistenceListener with WindowListener {
  _DesktopWindowPersistenceListener(this._repository);

  final Repository _repository;

  Future<void> _save() async {
    final bounds = debugWindowBoundsOverride != null
        ? await debugWindowBoundsOverride!()
        : await windowManager.getBounds();
    await _repository.saveWindowBounds(
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    );
  }

  @override
  void onWindowResized() => _save();

  @override
  void onWindowMoved() => _save();
}
