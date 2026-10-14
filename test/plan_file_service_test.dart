import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/services/plan_file_service.dart';

void main() {
  final service = PlanFileService();

  test('un fichier natif conserve le plan éditable', () {
    final source = ClassGroup(
      id: 'source',
      name: '6ème B',
      room: Room(rows: 1, cols: 2),
      students: [Student(id: 'lea', firstName: 'Léa')],
      assignment: {'0,0': 'lea'},
    );

    final restored = service.decode(service.encode(source));

    expect(restored.name, '6ème B');
    expect(restored.room.cols, 2);
    expect(restored.students.single.fullName, 'Léa');
    expect(restored.assignment, {'0,0': 'lea'});
  });

  test('un fichier dont le conteneur est invalide est refusé', () {
    expect(
      () => service.decode('{"format":"autre","schemaVersion":1,"class":{}}'),
      throwsFormatException,
    );
    expect(() => service.decode('pas du JSON'), throwsFormatException);
    expect(
      () => service.decode(
        '{"format":"plandeclasse.plan","schemaVersion":1,"class":{}}',
      ),
      throwsFormatException,
    );
  });

  test('exporte un fichier nommé de façon sûre', () async {
    String? filename;
    Uint8List? bytes;
    final service = PlanFileService(
      saveFile: (name, data) async {
        filename = name;
        bytes = data;
        return true;
      },
    );

    final exported = await service.exportClass(
      ClassGroup(id: 'c', name: '6ème/B'),
    );

    expect(exported, isTrue);
    expect(filename, '6ème-B.planclasse');
    expect(service.decode(utf8.decode(bytes!)).name, '6ème/B');
  });

  test('importe les octets choisis ou respecte l’annulation', () async {
    final source = ClassGroup(id: 'c', name: '6ème B');
    final encoded = Uint8List.fromList(utf8.encode(service.encode(source)));
    final importing = PlanFileService(pickFile: () async => encoded);
    final cancelling = PlanFileService(pickFile: () async => null);

    expect((await importing.importClass())?.name, '6ème B');
    expect(await cancelling.importClass(), isNull);
  });
}
