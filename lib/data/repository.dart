/// Stockage local (hors-ligne) des classes, via shared_preferences.
/// Fonctionne sur Android, iOS, Web, Windows, macOS et Linux.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/classroom.dart';

class Repository {
  static const _key = 'plandeclasse_classes_v1';

  Future<List<ClassGroup>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(ClassGroup.fromJson).toList();
    } catch (_) {
      // Données corrompues : on repart proprement plutôt que de planter.
      return [];
    }
  }

  Future<void> save(List<ClassGroup> classes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(classes.map((c) => c.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
