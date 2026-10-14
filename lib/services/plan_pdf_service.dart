/// Génération et partage d'une version PDF non modifiable d'un plan.
library;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/classroom.dart';
import '../models/room.dart';
import '../models/student.dart';

typedef PdfSharer = Future<void> Function(Uint8List bytes, String filename);

class PlanPdfService {
  PlanPdfService({PdfSharer? sharePdf}) : _sharePdf = sharePdf ?? _share;

  final PdfSharer _sharePdf;

  Future<Uint8List> build(
    ClassGroup classGroup, {
    GenderColorPalette genderPalette = GenderColorPalette.tealCorail,
  }) async {
    final document = pw.Document();
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final room = classGroup.room;
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              classGroup.name,
              style: const pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey600),
                defaultColumnWidth: const pw.FlexColumnWidth(),
                children: [
                  for (var row = room.rows - 1; row >= 0; row--)
                    pw.TableRow(
                      children: [
                        for (var column = 0; column < room.cols; column++)
                          _seatCell(classGroup, row, column, genderPalette),
                      ],
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('DEVANT / TABLEAU', textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );
    return document.save();
  }

  Future<void> export(
    ClassGroup classGroup, {
    GenderColorPalette genderPalette = GenderColorPalette.tealCorail,
  }) async {
    final bytes = await build(classGroup, genderPalette: genderPalette);
    await _sharePdf(bytes, '${_safeFilename(classGroup.name)}.pdf');
  }

  static Future<void> _share(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);

  pw.Widget _seatCell(
    ClassGroup classGroup,
    int row,
    int column,
    GenderColorPalette genderPalette,
  ) {
    final room = classGroup.room;
    if (!room.isSeat(row, column)) {
      return pw.Container(color: PdfColors.grey300, height: 54);
    }
    final student = classGroup.studentById(
      classGroup.assignment['$row,$column'],
    );
    if (student == null) {
      return pw.Container(
        height: 54,
        alignment: pw.Alignment.center,
        child: pw.Text('Libre', style: const pw.TextStyle(fontSize: 8)),
      );
    }

    final stripe = _genderColor(student.gender, genderPalette);
    final backrest = room.facingOf(row, column);
    // Comme dans la grille interactive, le dossier garde la priorité visuelle
    // sur le liseré. Lorsqu'il est à gauche, on décale ce dernier vers
    // l'intérieur de la carte plutôt que de masquer l'un des deux repères.
    final stripeLeft = backrest == Facing.est ? 6.0 : 2.0;
    return pw.Container(
      height: 54,
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              padding: const pw.EdgeInsets.fromLTRB(7, 12, 4, 4),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    student.fullName,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _attributeDetails(student),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 4.5),
                  ),
                ],
              ),
            ),
          ),
          if (stripe != null)
            pw.Positioned(
              top: 2,
              bottom: 2,
              left: stripeLeft,
              child: pw.Container(width: 3, color: stripe),
            ),
          _backrest(backrest),
        ],
      ),
    );
  }

  pw.Widget _backrest(Facing facing) {
    final horizontal = facing == Facing.nord || facing == Facing.sud;
    final top = switch (facing) {
      Facing.nord => 2.0,
      _ => null,
    };
    final bottom = switch (facing) {
      Facing.sud => 2.0,
      _ => 0.0,
    };
    final left = switch (facing) {
      Facing.est => 0.0,
      Facing.nord || Facing.sud => 18.0,
      Facing.ouest => null,
    };
    final right = switch (facing) {
      Facing.ouest => 0.0,
      Facing.nord || Facing.sud => 18.0,
      Facing.est => null,
    };
    return pw.Positioned(
      top: horizontal ? top : 0,
      bottom: horizontal ? bottom : 0,
      left: left,
      right: right,
      child: pw.Container(
        width: horizontal ? 24 : 2,
        height: horizontal ? 2 : null,
        color: PdfColors.black,
      ),
    );
  }

  String _attributeDetails(Student student) =>
      'Niveau : ${switch (student.level) {
        Level.faible => 'faible',
        Level.moyen => 'moyen',
        Level.fort => 'fort',
      }} · Énergie : ${switch (student.energy) {
        Energy.calme => 'calme',
        Energy.modere => 'modérée',
        Energy.agite => 'agitée',
      }}\nTaille : ${switch (student.size) {
        StudentSize.petit => 'petit',
        StudentSize.moyen => 'moyen',
        StudentSize.grand => 'grand',
      }}${student.poorEyesight ? ' · Mauvaise vue' : ''}';

  PdfColor? _genderColor(Gender gender, GenderColorPalette palette) {
    if (gender == Gender.autre) return null;
    final value = switch (palette) {
      GenderColorPalette.violetAmbre => _paletteColor(
        gender,
        boy: 0xFF534AB7,
        girl: 0xFFBA7517,
      ),
      GenderColorPalette.tealCorail => _paletteColor(
        gender,
        boy: 0xFF0F6E56,
        girl: 0xFFD85A30,
      ),
      GenderColorPalette.bleuRoseAdouci => _paletteColor(
        gender,
        boy: 0xFF185FA5,
        girl: 0xFF993556,
      ),
      GenderColorPalette.bleuOrange => _paletteColor(
        gender,
        boy: 0xFF1F6FB2,
        girl: 0xFFC2660D,
      ),
      GenderColorPalette.vertRose => _paletteColor(
        gender,
        boy: 0xFF3B6D11,
        girl: 0xFF99244B,
      ),
    };
    return PdfColor(
      ((value >> 16) & 0xFF) / 255,
      ((value >> 8) & 0xFF) / 255,
      (value & 0xFF) / 255,
    );
  }

  int _paletteColor(Gender gender, {required int boy, required int girl}) =>
      switch (gender) {
        Gender.garcon => boy,
        Gender.fille => girl,
        Gender.autre => throw ArgumentError.value(gender, 'gender'),
      };

  String _safeFilename(String value) {
    final collapsed = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return collapsed.isEmpty ? 'plan-de-classe' : collapsed;
  }
}
