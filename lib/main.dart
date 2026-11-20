/// Plan de classe — application d'affectation des élèves aux places.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'data/repository.dart';
import 'desktop_window.dart';
import 'l10n/delegates.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/home_screen.dart';

/// Active explicitement le rendu qui s'étend sous les barres système.
///
/// Android 15+ l'impose aux applications ciblant l'API 35. Le déclarer évite
/// une différence de rendu suivant la version de Flutter.
Future<void> configureEdgeToEdge() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

/// Initialisation partagée par [main] et les tests (couverture Sonar).
@visibleForTesting
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureEdgeToEdge();
  await configureDesktopWindowAtStartup();
}

// coverage:ignore-start
void main() async {
  await bootstrapApp();
  runApp(const ClassroomSortApp());
}
// coverage:ignore-end

class ClassroomSortApp extends StatefulWidget {
  const ClassroomSortApp({super.key, this.debugState});

  /// État injecté par les tests de cycle de vie. En production, l'application
  /// crée, initialise et libère toujours sa propre instance.
  @visibleForTesting
  final AppState? debugState;

  @override
  State<ClassroomSortApp> createState() => _ClassroomSortAppState();
}

class _ClassroomSortAppState extends State<ClassroomSortApp>
    with WidgetsBindingObserver, DesktopWindowAppState {
  late final AppState _state;
  late final bool _ownsState;
  final Repository _windowRepo = Repository();

  @override
  Repository get desktopWindowRepository => _windowRepo;

  @override
  void initState() {
    super.initState();
    _ownsState = widget.debugState == null;
    _state = widget.debugState ?? AppState();
    WidgetsBinding.instance.addObserver(this);
    if (_ownsState) unawaited(_state.init());
    bindDesktopWindowLifecycle(_state.flushPendingSaves);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Les écritures démarrent dès la mutation. Ce point de synchronisation
        // leur laisse aussi la transition vers l'arrière-plan pour se terminer.
        unawaited(_state.flushPendingSaves());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unbindDesktopWindowLifecycle();
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3F51B5);
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: seed,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: seed,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        locale: _state.locale,
        themeMode: _state.themeMode,
        localizationsDelegates: appLocalizationDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(state: _state),
      ),
    );
  }
}
