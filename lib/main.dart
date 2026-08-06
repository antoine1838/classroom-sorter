/// Plan de classe — application d'affectation des élèves aux places.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'data/repository.dart';
import 'screens/home_screen.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

const _kDefaultWindowSize = Size(1280, 800);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_isDesktop) {
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
  runApp(const ClassroomSortApp());
}

class ClassroomSortApp extends StatefulWidget {
  const ClassroomSortApp({super.key});

  @override
  State<ClassroomSortApp> createState() => _ClassroomSortAppState();
}

class _ClassroomSortAppState extends State<ClassroomSortApp>
    with WindowListener {
  final AppState _state = AppState();
  final Repository _windowRepo = Repository();

  @override
  void initState() {
    super.initState();
    _state.init();
    if (_isDesktop) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (_isDesktop) windowManager.removeListener(this);
    _state.dispose();
    super.dispose();
  }

  /// Sauvegarde la taille/position courante — appelé une fois le
  /// redimensionnement/déplacement terminé (pas à chaque pixel).
  Future<void> _saveWindowBounds() async {
    final bounds = await windowManager.getBounds();
    await _windowRepo.saveWindowBounds(
        bounds.left, bounds.top, bounds.width, bounds.height);
  }

  @override
  void onWindowResized() => _saveWindowBounds();

  @override
  void onWindowMoved() => _saveWindowBounds();

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3F51B5);
    return MaterialApp(
      title: 'Plan de classe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorSchemeSeed: seed,
          useMaterial3: true,
          brightness: Brightness.light),
      darkTheme: ThemeData(
          colorSchemeSeed: seed,
          useMaterial3: true,
          brightness: Brightness.dark),
      home: HomeScreen(state: _state),
    );
  }
}
