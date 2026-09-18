// Vérifie la persistance du réglage global de vue Élèves (Complète/Compacte).
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/data/repository.dart';
import 'package:plandeclasse/models/classroom.dart';

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

  @override
  Future<void> save(List<ClassGroup> classes) async {
    if (fail) throw StateError('écriture simulée impossible');
    await super.save(classes);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('StudentsViewMode : défaut Complète, persiste après changement',
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
  });

  test('les modifications reçues pendant une écriture sont coalescées',
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
  });

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

  test('une restauration depuis le secours est annoncée sans erreur', () async {
    final backup = jsonEncode([
      ClassGroup(id: 'a', name: '5ème A').toJson(),
    ]);
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
}
