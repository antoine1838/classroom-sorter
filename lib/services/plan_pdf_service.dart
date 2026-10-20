/// Génération et partage d'une version PDF non modifiable d'un plan.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/classroom.dart';
import '../models/room.dart';
import '../models/student.dart';

typedef PdfSharer = Future<void> Function(Uint8List bytes, String filename);

/// Mesure de texte du PDF, pour une taille de 1 pt : largeur d'un texte et
/// hauteur d'une ligne. Injectable pour tester sans charger de police.
class PdfTextMeasure {
  const PdfTextMeasure({required this.widthAt1, required this.lineHeight});

  final double Function(String text) widthAt1;
  final double lineHeight;
}

/// Ce que toutes les cases d'une page partagent : palette, libellés et
/// dimensions d'une case. Regroupé pour ne pas passer huit paramètres à chaque
/// case.
class _SeatCellStyle {
  const _SeatCellStyle({
    required this.genderPalette,
    required this.l10n,
    required this.rowHeight,
    required this.cellWidth,
    required this.measure,
  });

  final GenderColorPalette genderPalette;
  final AppLocalizations l10n;
  final double rowHeight;
  final double cellWidth;
  final PdfTextMeasure measure;
}

class PlanPdfService {
  PlanPdfService({PdfSharer? sharePdf}) : _sharePdf = sharePdf ?? _share;

  final PdfSharer _sharePdf;

  static const _pageMargin = 24.0;

  /// Taille du nom de l'élève quand la case est assez large.
  static const _nameFontSize = 8.0;

  /// Plancher de réduction du nom : en dessous, il est coupé en plein mot
  /// plutôt que rendu illisible.
  static const _minNameFontSize = 4.0;
  static const _detailsFontSize = 4.5;

  /// Marges intérieures d'une case : à gauche, de quoi laisser voir le liseré
  /// de genre décalé par un dossier à l'est.
  static const _padLeft = 7.0;
  static const _padLeftBackrestEast = 11.0;
  static const _padRight = 4.0;
  static const _detailsPadTop = 12.0;
  static const _detailsPadBottom = 4.0;
  static const _nameDetailsGap = 2.0;

  /// Hauteur d'une case quand la salle a peu de rangs.
  static const _maxRowHeight = 54.0;

  /// En dessous, la case n'a plus la place d'afficher les attributs de
  /// l'élève : on garde seulement son nom, lisible.
  static const _detailsMinRowHeight = 42.0;

  /// Marge qui absorbe l'arrondi des flottants : sans elle, le dernier rang
  /// dépasse la hauteur disponible de quelques epsilon et le tableau le
  /// supprime en silence.
  static const _layoutSlack = 1.0;

  /// Hauteur de chaque rang pour que [rows] rangs tiennent dans
  /// [availableHeight] (plafonnée à [_maxRowHeight]).
  @visibleForTesting
  static double rowHeightFor(double? availableHeight, int rows) {
    if (availableHeight == null || !availableHeight.isFinite || rows <= 0) {
      return _maxRowHeight;
    }
    return math.min(_maxRowHeight, (availableHeight - _layoutSlack) / rows);
  }

  /// Largeur d'une colonne de la salle ; à défaut de mesure, celle d'une page
  /// A4 paysage entre ses marges.
  @visibleForTesting
  static double cellWidthFor(double? availableWidth, int cols) {
    final width = availableWidth != null && availableWidth.isFinite
        ? availableWidth
        : PdfPageFormat.a4.landscape.width - 2 * _pageMargin;
    return width / math.max(1, cols);
  }

  /// Taille du nom : celle par défaut, réduite (jusqu'à [_minNameFontSize])
  /// pour que le plus long mot tienne sur une ligne de [width].
  @visibleForTesting
  static double nameFontSizeFor(
    String name,
    double width,
    PdfTextMeasure measure,
  ) {
    var longestWord = 0.0;
    for (final word in name.split(' ')) {
      longestWord = math.max(longestWord, measure.widthAt1(word));
    }
    if (longestWord <= 0) return _nameFontSize;
    // 3 % de marge : un mot exactement à la largeur serait coupé par l'arrondi.
    return math.min(
      _nameFontSize,
      math.max(_minNameFontSize, width * 0.97 / longestWord),
    );
  }

  /// Nombre de lignes de [text] à la taille [fontSize] dans [width], renvoyé
  /// à la ligne aux espaces comme `pw.Text` ; un mot plus large que [width]
  /// est coupé et occupe plusieurs lignes.
  @visibleForTesting
  static int lineCountFor(
    String text,
    double fontSize,
    double width,
    PdfTextMeasure measure,
  ) {
    final space = measure.widthAt1(' ') * fontSize;
    var lines = 0;
    for (final paragraph in text.split('\n')) {
      var used = 0.0;
      var paragraphLines = 1;
      for (final word in paragraph.split(' ')) {
        final wordWidth = measure.widthAt1(word) * fontSize;
        if (used > 0 && used + space + wordWidth > width) {
          paragraphLines++;
          used = 0;
        }
        if (wordWidth > width) {
          final extraLines = (wordWidth / width).ceil() - 1;
          paragraphLines += extraLines;
          used = wordWidth - extraLines * width;
        } else {
          used += (used > 0 ? space : 0) + wordWidth;
        }
      }
      lines += paragraphLines;
    }
    return lines;
  }

  /// Taille du nom et présence des attributs pour une case de [cellWidth] sur
  /// [rowHeight]. Le nom passe toujours en premier : les attributs ne sont
  /// affichés que s'ils tiennent avec lui, sans réduire davantage le texte.
  @visibleForTesting
  static ({double nameSize, bool showDetails}) seatTextLayout({
    required String name,
    required String details,
    required double cellWidth,
    required double rowHeight,
    required double padLeft,
    required PdfTextMeasure measure,
  }) {
    final width = math.max(1.0, cellWidth - padLeft - _padRight);
    final nameSize = nameFontSizeFor(name, width, measure);
    if (rowHeight < _detailsMinRowHeight) {
      return (nameSize: nameSize, showDetails: false);
    }
    final nameHeight =
        lineCountFor(name, nameSize, width, measure) *
        nameSize *
        measure.lineHeight;
    final detailsHeight =
        lineCountFor(details, _detailsFontSize, width, measure) *
        _detailsFontSize *
        measure.lineHeight;
    final available = rowHeight - _detailsPadTop - _detailsPadBottom;
    return (
      nameSize: nameSize,
      showDetails: nameHeight + _nameDetailsGap + detailsHeight <= available,
    );
  }

  /// Les libellés viennent de [l10n] : le PDF suit la langue de l'appelant.
  Future<Uint8List> build(
    ClassGroup classGroup, {
    required AppLocalizations l10n,
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
              // La place restante dépend du titre et du pied de page : on la
              // lit à la mise en page pour répartir les rangs dessus.
              child: pw.LayoutBuilder(
                builder: (context, constraints) {
                  final rowHeight = rowHeightFor(
                    constraints?.maxHeight,
                    room.rows,
                  );
                  final cellWidth = cellWidthFor(
                    constraints?.maxWidth,
                    room.cols,
                  );
                  final font = regular.getFont(context);
                  final style = _SeatCellStyle(
                    genderPalette: genderPalette,
                    l10n: l10n,
                    rowHeight: rowHeight,
                    cellWidth: cellWidth,
                    measure: PdfTextMeasure(
                      widthAt1: (text) => font.stringMetrics(text).advanceWidth,
                      lineHeight: font.emptyLineHeight,
                    ),
                  );
                  return pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey600),
                    defaultColumnWidth: const pw.FlexColumnWidth(),
                    children: [
                      for (var row = room.rows - 1; row >= 0; row--)
                        pw.TableRow(
                          children: [
                            for (var column = 0; column < room.cols; column++)
                              _seatCell(classGroup, row, column, style),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(l10n.pdfFrontOfRoom, textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );
    return document.save();
  }

  Future<void> export(
    ClassGroup classGroup, {
    required AppLocalizations l10n,
    GenderColorPalette genderPalette = GenderColorPalette.tealCorail,
  }) async {
    final bytes = await build(
      classGroup,
      l10n: l10n,
      genderPalette: genderPalette,
    );
    await _sharePdf(bytes, '${_safeFilename(classGroup.name)}.pdf');
  }

  static Future<void> _share(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);

  pw.Widget _seatCell(
    ClassGroup classGroup,
    int row,
    int column,
    _SeatCellStyle style,
  ) {
    final l10n = style.l10n;
    final rowHeight = style.rowHeight;
    final room = classGroup.room;
    if (!room.isSeat(row, column)) {
      return pw.Container(color: PdfColors.grey300, height: rowHeight);
    }
    final student = classGroup.studentById(
      classGroup.assignment['$row,$column'],
    );
    if (student == null) {
      return pw.Container(
        height: rowHeight,
        alignment: pw.Alignment.center,
        child: pw.Text(
          l10n.pdfFreeSeat,
          style: const pw.TextStyle(fontSize: 8),
        ),
      );
    }

    final stripe = _genderColor(student.gender, style.genderPalette);
    final backrest = room.facingOf(row, column);
    // Comme dans la grille interactive, le dossier garde la priorité visuelle
    // sur le liseré. Lorsqu'il est à gauche, on décale ce dernier vers
    // l'intérieur de la carte plutôt que de masquer l'un des deux repères.
    final stripeLeft = backrest == Facing.est ? 6.0 : 2.0;
    final padLeft = backrest == Facing.est && stripe != null
        ? _padLeftBackrestEast
        : _padLeft;
    final details = _attributeDetails(student, l10n);
    final text = seatTextLayout(
      name: student.fullName,
      details: details,
      cellWidth: style.cellWidth,
      rowHeight: rowHeight,
      padLeft: padLeft,
      measure: style.measure,
    );
    final showDetails = text.showDetails;
    return pw.Container(
      height: rowHeight,
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              padding: pw.EdgeInsets.fromLTRB(
                padLeft,
                showDetails ? _detailsPadTop : 3,
                _padRight,
                showDetails ? _detailsPadBottom : 3,
              ),
              // Filet de sécurité : si le texte dépasse malgré tout la case, il
              // est réduit au lieu d'être supprimé en silence par la mise en
              // page.
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                child: pw.SizedBox(
                  width: math.max(1.0, style.cellWidth - padLeft - _padRight),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        student.fullName,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: text.nameSize),
                      ),
                      if (showDetails) ...[
                        pw.SizedBox(height: _nameDetailsGap),
                        pw.Text(
                          details,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: _detailsFontSize),
                        ),
                      ],
                    ],
                  ),
                ),
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
      _ => null,
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

  String _attributeDetails(Student student, AppLocalizations l10n) {
    final level = switch (student.level) {
      Level.faible => l10n.low,
      Level.moyen => l10n.medium,
      Level.fort => l10n.high,
    };
    final energy = switch (student.energy) {
      Energy.calme => l10n.calm,
      Energy.modere => l10n.moderate,
      Energy.agite => l10n.restless,
    };
    final size = switch (student.size) {
      StudentSize.petit => l10n.small,
      StudentSize.moyen => l10n.medium,
      StudentSize.grand => l10n.tall,
    };
    return '${l10n.attributeLevel(level)} · ${l10n.attributeEnergy(energy)}\n'
        '${l10n.attributeSize(size)}'
        '${student.poorEyesight ? ' · ${l10n.poorEyesight}' : ''}';
  }

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
