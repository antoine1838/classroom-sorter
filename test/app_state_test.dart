// Vérifie la persistance du réglage global de vue Élèves (Complète/Compacte).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/data/repository.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';

class _BlockingRepository extends Repository {
  final firstSaveMayFinish = Completer<void>();
  final snapshots = <List<String>>[];

  @override
  Future<void> save(List<ClassGroup> classes) async {
    snapshots.add(classes.map((c) => c.name).toList());
    if (snapshots.length == 1) await firstSaveMayFinish.future;
  }
}

class _FailingRepository extends Repository {
  bool fail = true;
  bool failTheme = false;
  int classSaveAttempts = 0;

  @override
  Future<void> save(List<ClassGroup> classes) async {
    classSaveAttempts++;
    if (fail) throw StateError('écriture simulée impossible');
    await super.save(classes);
  }

  @override
  Future<void> saveThemePreference(String preference) async {
    if (failTheme) throw StateError('écriture du thème impossible');
    await super.saveThemePreference(preference);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('newId produit des identifiants base 36 distincts', () {
    final ids = {for (var i = 0; i < 500; i++) newId()};

    expect(ids, hasLength(500));
    expect(ids, everyElement(matches(RegExp(r'^[0-9a-z]+$'))));
  });

  test(
    'StudentsViewMode : défaut Complète, persiste après changement',
    () async {
      final state = AppState();
      await state.init();
      expect(state.studentsViewMode, StudentsViewMode.complete);

      state.setStudentsViewMode(StudentsViewMode.compact);
      expect(state.studentsViewMode, StudentsViewMode.compact);
      await state.flushPendingSaves();

      // Une nouvelle instance (ex. redémarrage de l'appli) doit relire le
      // choix persisté plutôt que de retomber sur le défaut.
      final reloaded = AppState();
      await reloaded.init();
      expect(reloaded.studentsViewMode, StudentsViewMode.compact);
    },
  );

  test('LocalePreference : système par défaut, anglais persistant après changement', () async {
    final state = AppState();
    await state.init();
    expect(state.localePreference, LocalePreference.system);
    expect(state.locale, isNull);

    state.setLocalePreference(LocalePreference.english);
    expect(state.locale?.languageCode, 'en');
    await state.flushPendingSaves();

    final reloaded = AppState();
    await reloaded.init();
    expect(reloaded.localePreference, LocalePreference.english);
    expect(reloaded.locale?.languageCode, 'en');
  });

  test(
    'ThemePreference : système par défaut, sombre persistant après changement',
    () async {
      final state = AppState();
      await state.init();
      expect(state.themePreference, ThemePreference.system);
      expect(state.themeMode, ThemeMode.system);

      state.setThemePreference(ThemePreference.dark);
      expect(state.themeMode, ThemeMode.dark);
      await state.flushPendingSaves();

      final reloaded = AppState();
      await reloaded.init();
      expect(reloaded.themePreference, ThemePreference.dark);
      expect(reloaded.themeMode, ThemeMode.dark);
    },
  );

  test(
    'le tutoriel est mémorisé et la démo temporaire n’est pas sauvegardée',
    () async {
      final state = AppState();
      await state.init();
      expect(state.tutorialSeen, isFalse);

      state.markTutorialSeen();
      await state.flushPendingSaves();

      final demo = await state.loadTemporaryDemoClass();
      expect(state.classes, isEmpty);
      expect(demo.students, isNotEmpty);

      final reloaded = AppState();
      await reloaded.init();
      expect(reloaded.tutorialSeen, isTrue);
      expect(reloaded.classes, isEmpty);
    },
  );

  test(
    'les modifications reçues pendant une écriture sont coalescées',
    () async {
      final repo = _BlockingRepository();
      final state = AppState(repository: repo);
      await state.init();

      state.addClass('5ème A');
      state.addClass('5ème B');
      state.addClass('5ème C');

      expect(repo.snapshots, [
        ['5ème A'],
      ], reason: 'une seule écriture doit être active à la fois');

      repo.firstSaveMayFinish.complete();
      await state.flushPendingSaves();

      expect(repo.snapshots, [
        ['5ème A'],
        ['5ème A', '5ème B', '5ème C'],
      ], reason: 'les changements intermédiaires doivent être regroupés');
    },
  );

  test('une erreur de sauvegarde est signalée et peut être retentée', () async {
    final repo = _FailingRepository();
    final state = AppState(repository: repo);
    await state.init();

    state.addClass('5ème A');
    await state.flushPendingSaves();

    expect(state.persistenceMessage, contains('sauvegarde locale a échoué'));
    expect(state.persistenceMessageIsError, isTrue);
    expect(state.canRetryPersistence, isTrue);
    expect(state.lastPersistenceError, isA<StateError>());

    repo.fail = false;
    state.retryPersistence();
    await state.flushPendingSaves();

    expect(state.persistenceMessage, isNull);
    expect(state.lastPersistenceError, isNull);
    expect((await Repository().load()).single.name, '5ème A');
  });

  test('classes en échec puis thème réussi : erreur conservée, classes '
      'réécrites ensuite', () async {
    final repo = _FailingRepository();
    final state = AppState(repository: repo);
    await state.init();

    state.addClass('5ème A');
    await state.flushPendingSaves();
    expect(state.persistenceMessageIsError, isTrue);
    expect(
      repo.classSaveAttempts,
      1,
      reason: 'pas de réessai automatique en boucle',
    );

    state.setThemePreference(ThemePreference.dark);
    await state.flushPendingSaves();

    expect(await Repository().loadThemePreference(), 'dark');
    expect(await Repository().load(), isEmpty);
    expect(state.persistenceMessage, contains('sauvegarde locale a échoué'));
    expect(state.canRetryPersistence, isTrue);
    expect(
      repo.classSaveAttempts,
      2,
      reason: 'les classes sont retentées une fois, avec la mutation suivante',
    );

    repo.fail = false;
    state.setLocalePreference(LocalePreference.english);
    await state.flushPendingSaves();

    expect((await Repository().load()).single.name, '5ème A');
    expect(state.persistenceMessage, isNull);
    expect(state.lastPersistenceError, isNull);
  });

  test(
    'un réglage en échec reste en attente quand les classes réussissent',
    () async {
      final repo = _FailingRepository()
        ..fail = false
        ..failTheme = true;
      final state = AppState(repository: repo);
      await state.init();

      state.setThemePreference(ThemePreference.dark);
      await state.flushPendingSaves();
      expect(state.persistenceMessageIsError, isTrue);

      state.addClass('5ème A');
      await state.flushPendingSaves();

      expect((await Repository().load()).single.name, '5ème A');
      expect(
        state.persistenceMessageIsError,
        isTrue,
        reason: 'le thème n’est toujours pas écrit',
      );

      repo.failTheme = false;
      state.touch();
      await state.flushPendingSaves();

      expect(await Repository().loadThemePreference(), 'dark');
      expect(state.persistenceMessage, isNull);
    },
  );

  test('une restauration depuis le secours est annoncée sans erreur', () async {
    final backup = jsonEncode([ClassGroup(id: 'a', name: '5ème A').toJson()]);
    SharedPreferences.setMockInitialValues({
      'plandeclasse_classes_v1': 'JSON cassé',
      'plandeclasse_classes_v1_backup': backup,
    });
    final state = AppState();

    await state.init();

    expect(state.classes.single.name, '5ème A');
    expect(state.persistenceMessage, contains('sauvegarde valide'));
    expect(state.persistenceMessageIsError, isFalse);
    expect(state.canRetryPersistence, isFalse);

    state.dismissPersistenceMessage();
    expect(state.persistenceMessage, isNull);
  });

  test('archiver puis restaurer crée une classe indépendante', () async {
    final state = AppState();
    await state.init();
    final source = state.addClass('6ème B')
      ..students.add(Student(id: 'lea', firstName: 'Léa'))
      ..assignment[Room.keyOf(0, 0)] = 'lea';
    state.touch();

    final snapshot = state.archivePlan(source, 'Septembre');
    source.students.first.firstName = 'Modifiée';
    source.assignment.clear();

    final restored = state.restorePlanSnapshot(source, snapshot);

    expect(state.classes, hasLength(2));
    expect(restored.name, '6ème B — Septembre (copie)');
    expect(restored.students.single.firstName, 'Léa');
    expect(restored.assignment[Room.keyOf(0, 0)], 'lea');
    expect(restored.snapshots, isEmpty);

    state.deletePlanSnapshot(source, snapshot.id);
    expect(source.snapshots, isEmpty);
  });

  test('importer une classe ne réutilise pas son identifiant', () async {
    final state = AppState();
    await state.init();
    state.addClass('Existante');
    final imported = state.importClass(
      ClassGroup(id: 'externe', name: '6ème B'),
    );

    expect(imported.id, isNot('externe'));
    expect(imported.name, '6ème B (importée)');
    expect(state.classes, hasLength(2));
  });

  test('les copies restaurées et importées reçoivent un nom unique', () async {
    final state = AppState();
    await state.init();
    final source = state.addClass('6ème B');
    final snapshot = state.archivePlan(source, 'Septembre');

    state.addClass('6ème B — Septembre (copie)');
    state.addClass('6ème B — Septembre (copie) 2');
    final restored = state.restorePlanSnapshot(source, snapshot);

    state.addClass('5ème A (importée)');
    state.addClass('5ème A (importée) 2');
    final imported = state.importClass(
      ClassGroup(id: 'external', name: '5ème A'),
    );

    expect(restored.name, '6ème B — Septembre (copie) 3');
    expect(imported.name, '5ème A (importée) 3');
  });
}
