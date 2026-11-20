// bridge legacy window_manager 0.7 : migration vers l'API nativeapi hors scope.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/legacy.dart';

import 'package:plandeclasse/data/repository.dart';
import 'package:plandeclasse/platform/is_desktop.dart';

const _kDefaultWindowSize = Size(1280, 800);

/// En tests widget, nativeapi n’est pas chargée : ce hook évite `getBounds()`
/// toujours à zéro.
@visibleForTesting
Future<Rect> Function()? debugWindowBoundsOverride;

/// Remplace la destruction native dans les tests pour observer le moment exact
/// où la fermeture est enfin autorisée.
@visibleForTesting
Future<void> Function()? debugWindowDestroyOverride;

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

  void bindDesktopWindowLifecycle(Future<void> Function() flushPendingSaves) {
    if (!isDesktopNativeApp) return;
    _desktopWindowListener ??= _DesktopWindowPersistenceListener(
      desktopWindowRepository,
      flushPendingSaves,
    );
    windowManager.addListener(_desktopWindowListener!);
    // Le bouton de fermeture déclenche désormais onWindowClose ; le listener
    // détruira réellement la fenêtre une fois les écritures terminées.
    unawaited(windowManager.setPreventClose(true));
  }

  void unbindDesktopWindowLifecycle() {
    if (!isDesktopNativeApp || _desktopWindowListener == null) return;
    windowManager.removeListener(_desktopWindowListener!);
    _desktopWindowListener = null;
    unawaited(windowManager.setPreventClose(false));
  }
}

class _DesktopWindowPersistenceListener with WindowListener {
  _DesktopWindowPersistenceListener(this._repository, this._flushPendingSaves);

  final Repository _repository;
  final Future<void> Function() _flushPendingSaves;
  bool _closing = false;

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
  void onWindowResized() => unawaited(_save());

  @override
  void onWindowMoved() => unawaited(_save());

  @override
  void onWindowClose() {
    if (_closing) return;
    _closing = true;
    unawaited(_closeAfterSaving());
  }

  Future<void> _closeAfterSaving() async {
    await _attempt(
      _flushPendingSaves,
      'pendant la sauvegarde des données avant fermeture',
    );
    await _attempt(
      _save,
      'pendant la sauvegarde de la fenêtre avant fermeture',
    );
    await (debugWindowDestroyOverride ?? windowManager.destroy)();
  }

  Future<void> _attempt(Future<void> Function() action, String context) async {
    try {
      await action();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Plan de classe',
          context: ErrorDescription(context),
        ),
      );
    }
  }
}
