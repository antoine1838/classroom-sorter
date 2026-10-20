import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/l10n/generated/app_localizations_en.dart';
import 'package:plandeclasse/l10n/generated/app_localizations_fr.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/services/plan_pdf_service.dart';

double _fakeWidth(String text) => text.length * 0.5;

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

  group('texte des cases', () {
    // 0,5 pt de large par caractère à 1 pt, 1,4 pt de haut par ligne.
    const measure = PdfTextMeasure(widthAt1: _fakeWidth, lineHeight: 1.4);
    const details = 'Niveau : Fort · Énergie : Agité\nTaille : Grand';

    test('la largeur d une colonne vient de la page, sinon de A4 paysage', () {
      expect(PlanPdfService.cellWidthFor(480, 4), 120);
      expect(PlanPdfService.cellWidthFor(null, 12), closeTo(66.16, 0.01));
      expect(
        PlanPdfService.cellWidthFor(double.infinity, 12),
        closeTo(66.16, 0.01),
      );
      expect(PlanPdfService.cellWidthFor(480, 0), 480);
    });

    test('le nom garde sa taille tant que son plus long mot tient', () {
      expect(PlanPdfService.nameFontSizeFor('Léa Martin', 100, measure), 8);
    });

    test('le nom rétrécit pour que son plus long mot tienne sur une ligne', () {
      // « Dubois-Lefèvre » : 14 caractères, 7 pt à 1 pt, dans 40 pt.
      final size = PlanPdfService.nameFontSizeFor(
        'Léa Dubois-Lefèvre',
        40,
        measure,
      );

      expect(size, closeTo(40 * 0.97 / 7, 1e-9));
      expect(size * 7, lessThan(40));
    });

    test('le nom ne descend pas sous le plancher de lisibilité', () {
      expect(
        PlanPdfService.nameFontSizeFor('Villeneuve-Saint-Georges', 20, measure),
        4,
      );
    });

    test('le retour à la ligne se fait aux espaces et aux sauts de ligne', () {
      // 4 pt par caractère et par espace à 8 pt, dans 20 pt.
      int lines(String text) =>
          PlanPdfService.lineCountFor(text, 8, 20, measure);

      expect(lines('ab cd'), 1, reason: '8 + 4 + 8 = 20 tient');
      expect(lines('abc de'), 2);
      expect(lines('ab\ncd'), 2);
      expect(lines(''), 1);
    });

    test('un mot plus large que la case compte plusieurs lignes', () {
      expect(PlanPdfService.lineCountFor('abcdefghij', 8, 20, measure), 2);
      expect(PlanPdfService.lineCountFor('abcdefghijklmno', 8, 20, measure), 3);
    });

    test('une case large affiche le nom et les attributs', () {
      final layout = PlanPdfService.seatTextLayout(
        name: 'Léa Martin',
        details: details,
        cellWidth: 190,
        rowHeight: 54,
        padLeft: 7,
        measure: measure,
      );

      expect(layout.nameSize, 8);
      expect(layout.showDetails, isTrue);
    });

    test('une case étroite garde le nom et masque les attributs', () {
      final layout = PlanPdfService.seatTextLayout(
        name: 'Marie-Charlotte Dubois-Lefèvre',
        details: details,
        cellWidth: 63,
        rowHeight: 54,
        padLeft: 7,
        measure: measure,
      );

      expect(layout.nameSize, lessThan(8));
      expect(layout.showDetails, isFalse);
    });

    test('une rangée basse n affiche que le nom, même en case large', () {
      final layout = PlanPdfService.seatTextLayout(
        name: 'Léa Martin',
        details: details,
        cellWidth: 190,
        rowHeight: 41,
        padLeft: 7,
        measure: measure,
      );

      expect(layout.showDetails, isFalse);
    });

    test('un liseré décalé par un dossier à l est réduit la largeur utile', () {
      final eastStripe = PlanPdfService.seatTextLayout(
        name: 'Marie-Charlotte',
        details: details,
        cellWidth: 60,
        rowHeight: 54,
        padLeft: 11,
        measure: measure,
      );
      final plain = PlanPdfService.seatTextLayout(
        name: 'Marie-Charlotte',
        details: details,
        cellWidth: 60,
        rowHeight: 54,
        padLeft: 7,
        measure: measure,
      );

      expect(eastStripe.nameSize, lessThan(plain.nameSize));
    });

    test('une salle de 12 colonnes aux noms longs et aux 4 orientations '
        'produit un PDF', () async {
      final room = Room(rows: 3, cols: 12);
      for (var row = 0; row < 3; row++) {
        for (var column = 0; column < 12; column++) {
          for (var turn = 0; turn < column % 4; turn++) {
            room.rotateFacing(row, column);
          }
        }
      }
      final students = [
        for (var row = 0; row < 3; row++)
          for (var column = 0; column < 12; column++)
            Student(
              id: 's$row-$column',
              firstName: 'Marie-Charlotte',
              lastName: 'Villeneuve-Saint-Georges',
              gender: column.isEven ? Gender.fille : Gender.garcon,
            ),
      ];
      final cls = ClassGroup(
        id: 'c',
        name: 'Salle étroite',
        room: room,
        students: students,
        assignment: {
          for (var row = 0; row < 3; row++)
            for (var column = 0; column < 12; column++)
              '$row,$column': 's$row-$column',
        },
      );

      final bytes = await PlanPdfService().build(
        cls,
        l10n: AppLocalizationsFr(),
      );

      expect(bytes.take(4), orderedEquals(<int>[0x25, 0x50, 0x44, 0x46]));
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
