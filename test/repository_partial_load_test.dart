// Un enregistrement illisible ne doit pas emporter les autres : avant, une
// seule archive à la date invalide rendait toute la liste de classes illisible,
// et l'application retombait sur une ancienne sauvegarde (ou sur une liste vide)
// en perdant le travail fait depuis.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/data/repository.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/saved_room.dart';

const _classesKey = 'plandeclasse_classes_v1';
const _classesBackupKey = 'plandeclasse_classes_v1_backup';
const _classesCorruptKey = 'plandeclasse_classes_v1_corrupt';
const _roomsKey = 'plandeclasse_saved_rooms_v1';
const _roomsCorruptKey = 'plandeclasse_saved_rooms_v1_corrupt';

/// Une classe dont une archive a une date invalide.
Map<String, dynamic> _classWithBrokenSnapshot(String id) => {
  ...ClassGroup(id: id, name: 'Classe $id').toJson(),
  'snapshots': [
    {
      'id': 's',
      'label': 'Trimestre 1',
      'createdAt': 'pas une date',
      'schemaVersion': 1,
      'classData': <String, dynamic>{},
    },
  ],
};

Map<String, dynamic> _unreadableClass(String id) => {
  ...ClassGroup(id: id, name: 'Cassée $id').toJson(),
  'id': 42,
};

Map<String, dynamic> _validClass(String id, String name) =>
    ClassGroup(id: id, name: name).toJson();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('classes', () {
    test('une archive illisible est retirée sans écarter sa classe', () async {
      final raw = jsonEncode([
        _validClass('a', '6ème A'),
        _classWithBrokenSnapshot('b'),
        'pas même un objet',
        _validClass('c', '6ème C'),
      ]);
      SharedPreferences.setMockInitialValues({_classesKey: raw});

      final result = await Repository().loadClassesWithStatus();
      final prefs = await SharedPreferences.getInstance();

      expect(result.status, RepositoryLoadStatus.recoveredPartially);
      expect(result.data.map((c) => c.name), ['6ème A', 'Classe b', '6ème C']);
      expect(result.data[1].snapshots, isEmpty);
      expect(result.cleanup.snapshotsRemoved, 1);
      expect(result.skipped, 1);
      expect(
        prefs.getString(_classesCorruptKey),
        raw,
        reason: 'les enregistrements écartés restent récupérables à la main',
      );
      expect(
        prefs.getString(_classesKey),
        raw,
        reason: 'la lecture ne réécrit pas la valeur principale',
      );
    });

    test(
      'une archive cassée ne fait pas revenir à une sauvegarde plus ancienne',
      () async {
        final backup = jsonEncode([_validClass('vieux', 'Ancienne classe')]);
        SharedPreferences.setMockInitialValues({
          _classesKey: jsonEncode([
            _validClass('a', '6ème A'),
            _classWithBrokenSnapshot('b'),
          ]),
          _classesBackupKey: backup,
        });

        final result = await Repository().loadClassesWithStatus();

        expect(result.status, RepositoryLoadStatus.ok);
        expect(result.data.map((c) => c.name), ['6ème A', 'Classe b']);
        expect(result.data.last.snapshots, isEmpty);
        expect(result.cleanup.snapshotsRemoved, 1);
        expect(result.skipped, 0);
      },
    );

    test('rien de lisible : retour à la sauvegarde, comme avant', () async {
      final backup = jsonEncode([_validClass('vieux', 'Ancienne classe')]);
      SharedPreferences.setMockInitialValues({
        _classesKey: jsonEncode([_unreadableClass('b')]),
        _classesBackupKey: backup,
      });

      final result = await Repository().loadClassesWithStatus();

      expect(result.status, RepositoryLoadStatus.recoveredFromBackup);
      expect(result.data.single.name, 'Ancienne classe');
      expect(result.skipped, 0);
    });

    test(
      'rien de lisible et pas de sauvegarde : corruption signalée',
      () async {
        SharedPreferences.setMockInitialValues({
          _classesKey: jsonEncode([_unreadableClass('b')]),
        });

        final result = await Repository().loadClassesWithStatus();

        expect(result.status, RepositoryLoadStatus.corrupted);
        expect(result.data, isEmpty);
      },
    );

    test('des données entièrement valides ne sont pas signalées', () async {
      SharedPreferences.setMockInitialValues({
        _classesKey: jsonEncode([_validClass('a', '6ème A')]),
      });

      final result = await Repository().loadClassesWithStatus();

      expect(result.status, RepositoryLoadStatus.ok);
      expect(result.skipped, 0);
      expect(result.cleanup.isEmpty, isTrue);
    });

    test('sauvegarder après nettoyage garde la copie d\'origine', () async {
      final raw = jsonEncode([
        _validClass('a', '6ème A'),
        _classWithBrokenSnapshot('b'),
      ]);
      SharedPreferences.setMockInitialValues({_classesKey: raw});
      final repo = Repository();
      final loaded = await repo.load();

      await repo.save(loaded);
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString(_classesCorruptKey), raw);
      expect(
        (jsonDecode(prefs.getString(_classesKey)!) as List<Object?>).length,
        2,
        reason: 'les deux classes restent présentes après le nettoyage',
      );
      final reloaded = await repo.loadClassesWithStatus();
      expect(reloaded.status, RepositoryLoadStatus.ok);
      expect(reloaded.cleanup.isEmpty, isTrue);
      expect(reloaded.data.last.snapshots, isEmpty);
    });

    test('un champ snapshots mal formé garde aussi la classe', () async {
      final malformed = _validClass('a', '6ème A')..['snapshots'] = 'cassé';
      SharedPreferences.setMockInitialValues({
        _classesKey: jsonEncode([malformed]),
      });

      final result = await Repository().loadClassesWithStatus();

      expect(result.status, RepositoryLoadStatus.ok);
      expect(result.data.single.name, '6ème A');
      expect(result.data.single.snapshots, isEmpty);
      expect(result.cleanup.snapshotsRemoved, 1);
    });
  });

  group('salles enregistrées', () {
    Map<String, dynamic> room(String id, String name) =>
        SavedRoom(id: id, name: name, room: Room(rows: 2, cols: 2)).toJson();

    test(
      'une salle illisible est laissée de côté, les autres sont lues',
      () async {
        final raw = jsonEncode([
          room('a', 'B204'),
          {'id': 'b', 'name': 'Cassée', 'room': 'pas une salle'},
          room('c', 'C101'),
        ]);
        SharedPreferences.setMockInitialValues({_roomsKey: raw});

        final result = await Repository().loadSavedRoomsWithStatus();
        final prefs = await SharedPreferences.getInstance();

        expect(result.status, RepositoryLoadStatus.recoveredPartially);
        expect(result.data.map((r) => r.name), ['B204', 'C101']);
        expect(result.skipped, 1);
        expect(prefs.getString(_roomsCorruptKey), raw);
      },
    );
  });
}
