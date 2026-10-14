import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/services/plan_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le PDF paysage est produit à partir du plan', () async {
    final bytes = await PlanPdfService().build(
      ClassGroup(
        id: 'c',
        name: '6ème B',
        room: Room(rows: 1, cols: 1),
        students: [Student(id: 'lea', firstName: 'Léa')],
        assignment: {'0,0': 'lea'},
      ),
    );

    expect(bytes.take(4), orderedEquals(<int>[0x25, 0x50, 0x44, 0x46]));
  });

  test(
    'restitue les variantes de sièges et partage le PDF construit',
    () async {
      final room = Room(rows: 2, cols: 2);
      room.rotateFacing(0, 0); // est
      room.rotateFacing(0, 1);
      room.rotateFacing(0, 1); // sud
      room.toggle(1, 1); // case désactivée
      final cls = ClassGroup(
        id: 'c',
        name: '6ème/B',
        room: room,
        students: [
          Student(
            id: 'girl',
            firstName: 'Élise',
            gender: Gender.fille,
            level: Level.faible,
            energy: Energy.calme,
            size: StudentSize.petit,
            poorEyesight: true,
          ),
          Student(
            id: 'boy',
            firstName: 'Noé',
            gender: Gender.garcon,
            level: Level.fort,
            energy: Energy.agite,
            size: StudentSize.grand,
          ),
        ],
        assignment: {'0,0': 'girl', '0,1': 'boy'},
      );
      Uint8List? shared;
      String? filename;
      final service = PlanPdfService(
        sharePdf: (bytes, name) async {
          shared = bytes;
          filename = name;
        },
      );

      for (final palette in GenderColorPalette.values) {
        final bytes = await service.build(cls, genderPalette: palette);
        expect(bytes.take(4), orderedEquals(<int>[0x25, 0x50, 0x44, 0x46]));
      }
      await service.export(cls, genderPalette: GenderColorPalette.bleuOrange);

      expect(shared, isNotNull);
      expect(filename, '6ème-B.pdf');
    },
  );
}
