import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/l10n/generated/app_localizations_en.dart';
import 'package:plandeclasse/l10n/generated/app_localizations_fr.dart';
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
      l10n: AppLocalizationsFr(),
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
        final bytes = await service.build(
          cls,
          l10n: AppLocalizationsFr(),
          genderPalette: palette,
        );
        expect(bytes.take(4), orderedEquals(<int>[0x25, 0x50, 0x44, 0x46]));
      }
      await service.export(
        cls,
        l10n: AppLocalizationsEn(),
        genderPalette: GenderColorPalette.bleuOrange,
      );

      expect(shared, isNotNull);
      expect(filename, '6ème-B.pdf');
    },
  );

  group('hauteur des rangs', () {
    // Hauteur du tableau sur une page A4 paysage, mesurée à la mise en page.
    const available = 476.96759055118105;

    test('garde la hauteur confortable quand la salle a peu de rangs', () {
      expect(PlanPdfService.rowHeightFor(available, 1), 54);
      expect(PlanPdfService.rowHeightFor(available, 8), 54);
    });

    test('réduit les rangs pour que 15 rangs tiennent sur la page', () {
      final height = PlanPdfService.rowHeightFor(available, 15);

      expect(height, lessThan(54));
      expect(
        height * 15,
        lessThan(available),
        reason: 'le tableau supprime en silence les rangs qui dépassent',
      );
    });

    test('tient pour toute salle de 1 à 40 rangs', () {
      for (var rows = 1; rows <= 40; rows++) {
        final height = PlanPdfService.rowHeightFor(available, rows);
        expect(height, lessThanOrEqualTo(54), reason: '$rows rangs');
        expect(height * rows, lessThan(available), reason: '$rows rangs');
      }
    });

    test('retombe sur 54 sans hauteur exploitable', () {
      expect(PlanPdfService.rowHeightFor(null, 15), 54);
      expect(PlanPdfService.rowHeightFor(double.infinity, 15), 54);
      expect(PlanPdfService.rowHeightFor(available, 0), 54);
    });
  });

  test(
    'une salle de 15 rangs pleine produit un PDF, en français et anglais',
    () async {
      final students = [
        for (var row = 0; row < 15; row++)
          for (var column = 0; column < 6; column++)
            Student(
              id: 's$row-$column',
              firstName: 'Élève',
              lastName: '$row$column',
            ),
      ];
      final cls = ClassGroup(
        id: 'c',
        name: 'Grande salle',
        room: Room(rows: 15, cols: 6),
        students: students,
        assignment: {
          for (var row = 0; row < 15; row++)
            for (var column = 0; column < 6; column++)
              '$row,$column': 's$row-$column',
        },
      );

      for (final l10n in [AppLocalizationsFr(), AppLocalizationsEn()]) {
        final bytes = await PlanPdfService().build(cls, l10n: l10n);
        expect(bytes.take(4), orderedEquals(<int>[0x25, 0x50, 0x44, 0x46]));
      }
    },
  );
}
