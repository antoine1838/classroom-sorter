/// Plan de classe — application d'affectation des élèves aux places.
library;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';

void main() => runApp(const ClassroomSortApp());

class ClassroomSortApp extends StatefulWidget {
  const ClassroomSortApp({super.key});

  @override
  State<ClassroomSortApp> createState() => _ClassroomSortAppState();
}

class _ClassroomSortAppState extends State<ClassroomSortApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

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
