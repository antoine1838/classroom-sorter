// Stockage local : ce qui est écrit doit se relire, et surtout des données
// corrompues ou tronquées ne doivent jamais faire planter le démarrage.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/data/repository.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Repository — classes', () {
    test('aucune donnée : liste vide', () async {
      expect(await Repository().load(), isEmpty);
    });

    test('aller-retour save / load', () async {
      final repo = Repository();
      await repo.save([
        ClassGroup(
          id: 'c1',
          name: '6ème B',
          room: Room(rows: 2, cols: 3),
          students: [Student(id: 'a', firstName: 'Léa')],
        ),
      ]);

      final back = await repo.load();

      expect(back, hasLength(1));
      expect(back.single.name, '6ème B');
      expect(back.single.room.cols, 3);
      expect(back.single.students.single.firstName, 'Léa');
    });

    test('chaîne vide traitée comme absence de données', () async {
      SharedPreferences.setMockInitialValues(
          {'plandeclasse_classes_v1': ''});
      expect(await Repository().load(), isEmpty);
    });

    test('données corrompues : on repart proprement au lieu de planter',
        () async {
      SharedPreferences.setMockInitialValues(
          {'plandeclasse_classes_v1': 'ceci n\'est pas du JSON'});
      expect(await Repository().load(), isEmpty);
    });

    test('JSON valide mais de forme inattendue : liste vide', () async {
      // Un objet là où on attend une liste : le try/catch doit encaisser.
      SharedPreferences.setMockInitialValues(
          {'plandeclasse_classes_v1': jsonEncode({'pas': 'une liste'})});
      expect(await Repository().load(), isEmpty);
    });
  });

  group('Repository — vue Élèves', () {
    test('null quand jamais réglée, puis relue', () async {
      final repo = Repository();
      expect(await repo.loadStudentsViewMode(), isNull);

      await repo.saveStudentsViewMode('compact');
      expect(await repo.loadStudentsViewMode(), 'compact');
    });
  });

  group('Repository — position de la fenêtre desktop', () {
    test('null quand jamais sauvegardée', () async {
      expect(await Repository().loadWindowBounds(), isNull);
    });

    test('aller-retour', () async {
      final repo = Repository();
      await repo.saveWindowBounds(10, 20, 1280, 720);

      final b = await repo.loadWindowBounds();

      expect(b, isNotNull);
      expect(b!.x, 10);
      expect(b.y, 20);
      expect(b.width, 1280);
      expect(b.height, 720);
    });

    test('valeur tronquée : ignorée plutôt que devinée', () async {
      SharedPreferences.setMockInitialValues(
          {'plandeclasse_window_bounds_v1': '10,20,1280'});
      expect(await Repository().loadWindowBounds(), isNull);
    });

    test('valeur non numérique : ignorée', () async {
      SharedPreferences.setMockInitialValues(
          {'plandeclasse_window_bounds_v1': '10,20,large,720'});
      expect(await Repository().loadWindowBounds(), isNull);
    });
  });

  group('AppState — cycle de vie des classes', () {
    test('addClass nomme la classe, ou lui donne un nom par défaut', () async {
      final state = AppState();
      await state.init();

      final a = state.addClass('5ème A');
      expect(a.name, '5ème A');

      final b = state.addClass('   ');
      expect(b.name, 'Nouvelle classe',
          reason: 'un nom vide ne doit pas passer');

      final c = state.addClass('  6ème B  ');
      expect(c.name, '6ème B', reason: 'les espaces sont rognés');

      expect(state.classes, hasLength(3));
      expect(a.id, isNot(b.id));
    });

    test('les classes ajoutées survivent à un redémarrage', () async {
      final state = AppState();
      await state.init();
      state.addClass('5ème A');

      // Laisse la sauvegarde asynchrone se terminer.
      await Future<void>.delayed(Duration.zero);

      final reloaded = AppState();
      await reloaded.init();
      expect(reloaded.classes.map((c) => c.name), ['5ème A']);
    });

    test('deleteClass retire la classe et persiste', () async {
      final state = AppState();
      await state.init();
      final a = state.addClass('5ème A');
      state.addClass('6ème B');

      state.deleteClass(a);
      await Future<void>.delayed(Duration.zero);

      expect(state.classes.map((c) => c.name), ['6ème B']);

      final reloaded = AppState();
      await reloaded.init();
      expect(reloaded.classes.map((c) => c.name), ['6ème B']);
    });

    test('notifie ses auditeurs à chaque modification', () async {
      final state = AppState();
      await state.init();

      var notifications = 0;
      state.addListener(() => notifications++);

      state.addClass('5ème A');
      expect(notifications, 1);

      state.deleteClass(state.classes.first);
      expect(notifications, 2);
    });
  });
}
