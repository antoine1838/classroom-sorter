/// Grilles réutilisables de la salle :
///  - [RoomEditorGrid] : éditer le plan (toucher une case pour retirer/remettre
///    une place — utile pour dessiner les allées).
///  - [PlanGrid] : afficher l'affectation, avec glisser-déposer pour échanger
///    deux élèves à la main.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'plan_viewport.dart';

import '../models/classroom.dart';
import '../models/room.dart';
import '../models/student.dart';

const double kCell = 62;
const double kGap = 6; // espace normal entre deux colonnes
const double kAisle = 24; // largeur d'un couloir entre colonnes
const double kRowGap = 14; // espace entre rangs (toujours un couloir)

/// Largeur maximale d'une case en paysage. Au-delà, une place cesse de
/// ressembler à une place.
const double kCellWideMax = 140;

/// Marge intérieure de la grille (`Padding(all: 4)`) et encombrement vertical du
/// bandeau « DEVANT » : comptés dans la mesure, sinon l'échelle prédite serait
/// plus optimiste que celle réellement appliquée par le [FittedBox].
const double kGridPadding = 4;
const double kBannerBlock = 38;

/// Au-delà de cette largeur RENDUE, une case a la place d'écrire un prénom ; en
/// dessous elle s'en tient aux initiales.
const double kFirstNameMinWidth = 54;

/// Bornes de la taille de police RENDUE d'un prénom, et sa part de la largeur
/// de case.
///
/// La police doit croître **moins vite** que la case, sinon le nombre de
/// lettres reste invariant : c'était le défaut de la première version, où une
/// case 45 % plus large affichait une police 45 % plus grosse et donc une seule
/// lettre de plus. Le plafond garantit qu'au-delà d'une certaine taille, la
/// place gagnée achète des lettres et non des pixels.
const double kNameSizeRatio = 0.12;
const double kNameSizeMin = 11;
const double kNameSizeMax = 18;

/// Hauteur totale de la grille, bandeau et marges compris. Indépendante de
/// l'orientation : seule la LARGEUR d'une case change.
double gridHeight(Room room) =>
    room.rows * kCell +
    (room.rows - 1) * kRowGap +
    kBannerBlock +
    2 * kGridPadding;

/// Largeur de l'espace inter-colonnes après la colonne [c].
/// En mode éditeur, l'espace reste large partout pour être facile à toucher ;
/// en affichage, il ne s'élargit qu'aux vrais couloirs.
double _colGapWidth(Room room, int c, {required bool editor}) {
  final aisle = room.hasColAisleAfter(c);
  return (editor || aisle) ? kAisle : kGap;
}

/// Somme des espaces inter-colonnes, marges de la grille comprises.
double _horizontalExtras(Room room, {required bool editor}) {
  var extras = 2 * kGridPadding;
  for (var c = 0; c < room.cols - 1; c++) {
    extras += _colGapWidth(room, c, editor: editor);
  }
  return extras;
}

double gridWidth(Room room, {bool editor = false, double cell = kCell}) =>
    room.cols * cell + _horizontalExtras(room, editor: editor);

/// Tout ce que l'affichage d'une place a besoin de savoir, mesuré d'un bloc.
class SeatMetrics {
  const SeatMetrics({
    required this.cell,
    required this.scale,
    required this.zoom,
  });

  /// Largeur d'une case AVANT réduction.
  final double cell;

  /// Facteur appliqué par le [FittedBox].
  final double scale;

  final double zoom;

  /// Largeur telle qu'elle apparaît réellement à l'écran.
  double get renderedWidth => cell * scale * zoom;

  /// Le prénom plutôt que les initiales.
  bool get showsFirstName => renderedWidth >= kFirstNameMinWidth;

  /// Taille de police du prénom telle qu'elle apparaît à l'écran.
  double get renderedNameSize =>
      (renderedWidth * kNameSizeRatio).clamp(kNameSizeMin, kNameSizeMax);

  /// Police du prénom avant mise à l'échelle : déduite de la taille rendue
  /// voulue, et non l'inverse.
  double get nameFontSize => renderedNameSize / (scale * zoom);

  /// Les initiales, elles, remplissent la case : proportionnelles lui va bien,
  /// puisqu'il n'y a que deux à cinq caractères à faire tenir.
  double get initialsFontSize => cell * 0.26;
}

/// Mesure la grille pour un [viewport] donné.
///
/// La largeur d'une case n'est jamais codée en dur : on prend la plus grande qui
/// n'empire pas l'échelle. Comme la hauteur de la grille n'en dépend pas, tant
/// que c'est la hauteur qui contraint, élargir les cases est gratuit — et c'est
/// ce qui achète des lettres.
///
/// **Aucune notion d'orientation ici**, à dessein : c'est la place disponible
/// qui décide. Lier l'élargissement au « téléphone en paysage » laissait une
/// fenêtre de bureau large avec des cases carrées et des prénoms tronqués.
SeatMetrics seatMetrics(Room room, Size viewport,
    {double zoom = 1, bool editor = false}) {
  if (viewport.isEmpty || room.cols <= 0 || room.rows <= 0) {
    return SeatMetrics(cell: kCell, scale: 1, zoom: zoom);
  }

  final height = gridHeight(room);
  final extras = _horizontalExtras(room, editor: editor);
  final heightScale = viewport.height / height;

  // Largeur qui rend l'échelle horizontale exactement égale à la verticale :
  // au-delà, élargir ferait rétrécir toute la grille.
  final ideal = (viewport.width / heightScale - extras) / room.cols;
  final cell = ideal.clamp(kCell, kCellWideMax).toDouble();

  // L'échelle peut dépasser 1 : sur un grand écran la salle doit OCCUPER la
  // place disponible. S'en tenir à « rétrécir seulement » laissait la grille à
  // sa taille naturelle dans un coin, avec des prénoms tronqués alors que
  // l'espace était là.
  final widthScale = viewport.width / (room.cols * cell + extras);
  return SeatMetrics(
    cell: cell,
    scale: min(widthScale, heightScale),
    zoom: zoom,
  );
}

Color studentColor(Student s, ColorScheme cs) => switch (s.gender) {
      Gender.fille => const Color(0xFFF3B8D0),
      Gender.garcon => const Color(0xFFA9CCF5),
      Gender.autre => cs.surfaceContainerHighest,
    };

// Icônes de coin : affichées seulement quand la valeur sort de l'ordinaire
// (Moyen / Modéré / Bonne vue restent muets) — le genre reste exprimé par la
// couleur de fond ([studentColor]), pas par un coin.
const _cornerIconColor = Color(0xFF3A3A3A);

IconData? _levelCornerIcon(Level level) => switch (level) {
      Level.faible => Icons.arrow_downward,
      Level.fort => Icons.arrow_upward,
      Level.moyen => null,
    };

IconData? _energyCornerIcon(Energy energy) => switch (energy) {
      Energy.calme => Icons.self_improvement,
      Energy.agite => Icons.bolt,
      Energy.modere => null,
    };

double? _sizeCornerBarHeight(StudentSize size) => switch (size) {
      StudentSize.petit => 6,
      StudentSize.grand => 14,
      StudentSize.moyen => null,
    };

class _FrontBanner extends StatelessWidget {
  final double width;
  const _FrontBanner(this.width);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width < 120 ? 120 : width,
      margin: const EdgeInsets.only(top: kGap + 2),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text('⬇  DEVANT (tableau)',
          style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// Enveloppe commune aux deux grilles : réduit la salle pour qu'elle tienne
/// d'un coup, comme une carte.
///
/// Ne défile pas, contrairement à ce que son ancien nom laissait croire : la
/// salle est mise à l'échelle, pas parcourue. Le zoom, lui, est fourni par
/// [PlanViewport] au-dessus.
///
/// Fournit aussi le rendu des couloirs entre colonnes. Si [onToggleAisle] est
/// non nul (mode éditeur), les espaces inter-colonnes sont tappables pour
/// ajouter/retirer un couloir ; sinon ils sont seulement affichés.
class _FittedGrid extends StatelessWidget {
  final Room room;
  final Widget Function(int r, int c) cellBuilder;
  final void Function(int c)? onToggleAisle;

  /// Largeur d'une case, mesurée par [seatMetrics].
  final double cell;

  const _FittedGrid({
    required this.room,
    required this.cellBuilder,
    this.onToggleAisle,
    this.cell = kCell,
  });

  bool get _editor => onToggleAisle != null;

  @override
  Widget build(BuildContext context) {
    final grid = Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rangs affichés du fond (haut) vers le devant (bas) : le tableau est
          // en bas, comme le voit le professeur face à sa classe. On conserve
          // l'index logique r (rang 0 = devant) pour les clés de place et
          // l'affectation — seul l'ordre d'affichage est inversé.
          for (var r = room.rows - 1; r >= 0; r--)
            Padding(
              padding: EdgeInsets.only(bottom: r > 0 ? kRowGap : 0),
              child: Row(
                children: [
                  for (var c = 0; c < room.cols; c++) ...[
                    cellBuilder(r, c),
                    if (c < room.cols - 1) _colGap(context, c),
                  ],
                ],
              ),
            ),
          _FrontBanner(gridWidth(room, editor: _editor, cell: cell)),
        ],
      ),
    );
    // BoxFit.contain, et non scaleDown : la salle doit aussi GRANDIR pour
    // occuper un grand écran. Avec scaleDown elle restait à sa taille naturelle
    // en haut de la fenêtre, laissant tout le bas vide.
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: grid,
      ),
    );
  }

  Widget _colGap(BuildContext context, int c) {
    final cs = Theme.of(context).colorScheme;
    final aisle = room.hasColAisleAfter(c);
    final gap = SizedBox(
      width: _colGapWidth(room, c, editor: _editor),
      height: kCell,
      child: Center(
        child: aisle
            ? Container(
                width: 4,
                height: kCell * 0.82,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : (_editor
                ? Container(width: 2, height: kCell * 0.5, color: cs.outlineVariant)
                : const SizedBox.shrink()),
      ),
    );
    if (!_editor) return gap;
    // HitTestBehavior.opaque : tout l'espace du couloir est cliquable, pas
    // seulement le fin trait peint — sinon la cible (2–4 px) est presque
    // impossible à toucher, surtout pour retirer un couloir existant.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggleAisle!(c),
      child: gap,
    );
  }
}

class RoomEditorGrid extends StatelessWidget {
  final Room room;
  final VoidCallback onChanged;
  const RoomEditorGrid({super.key, required this.room, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _FittedGrid(
      room: room,
      onToggleAisle: (c) {
        room.toggleColAisle(c);
        onChanged();
      },
      cellBuilder: (r, c) {
        final isSeat = room.isSeat(r, c);
        return InkWell(
          onTap: () {
            room.toggle(r, c);
            onChanged();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: kCell,
            height: kCell,
            decoration: BoxDecoration(
              color: isSeat ? cs.surface : cs.surfaceContainerLow,
              border: Border.all(
                color: isSeat ? cs.primary : cs.outlineVariant,
                width: isSeat ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSeat ? Icons.event_seat_outlined : Icons.block,
              color: isSeat ? cs.primary : cs.outlineVariant,
              size: 26,
            ),
          ),
        );
      },
    );
  }
}

class PlanGrid extends StatelessWidget {
  final ClassGroup cls;

  /// Échanger les occupants de deux places (glisser-déposer).
  final void Function(String seatA, String seatB) onSwap;

  /// Compteur de doigts partagé avec la fenêtre de zoom : une place refuse de se
  /// laisser saisir dès qu'il y a deux doigts, sinon un pincement posé dessus
  /// déclencherait un glisser par doigt.
  final PointerTracker? tracker;

  const PlanGrid({
    super.key,
    required this.cls,
    required this.onSwap,
    this.tracker,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Étiquettes calculées une fois pour toute la classe : la désambiguïsation
    // a besoin de voir tout le monde pour repérer les collisions.
    final labels = disambiguatedInitials(cls.students);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tout dépend de la place réellement disponible ici : la largeur des
        // cases, l'échelle, donc la police et le choix prénom / initiales.
        final m = seatMetrics(cls.room, constraints.biggest);

        return _FittedGrid(
          room: cls.room,
          cell: m.cell,
          cellBuilder: (r, c) {
            if (!cls.room.isSeat(r, c)) {
              // Allée / vide : simple espace.
              return SizedBox(width: m.cell, height: kCell);
            }
            final seatKey = Room.keyOf(r, c);
            final student = cls.studentById(cls.assignment[seatKey]);

            return DragTarget<String>(
              onWillAcceptWithDetails: (d) => d.data != seatKey,
              onAcceptWithDetails: (d) => onSwap(d.data, seatKey),
              builder: (context, candidate, rejected) {
                final hovering = candidate.isNotEmpty;
                final cell = _seatContent(context, student, hovering,
                    labels: labels, metrics: m);
                if (student == null) return cell;
                final feedback = Material(
                  color: Colors.transparent,
                  child: _seatContent(context, student, false,
                      labels: labels, metrics: m, elevated: true),
                );
                final placeholder = _emptySeat(cs, false, m.cell);
                // Occupé : rendre l'élève déplaçable. Avec un compteur de
                // doigts, on passe par SeatDraggable pour qu'un pincement ne
                // saisisse pas d'élève.
                return tracker == null
                    ? Draggable<String>(
                        data: seatKey,
                        feedback: feedback,
                        childWhenDragging: placeholder,
                        child: cell,
                      )
                    : SeatDraggable<String>(
                        tracker: tracker!,
                        data: seatKey,
                        feedback: feedback,
                        childWhenDragging: placeholder,
                        child: cell,
                      );
              },
            );
          },
        );
      },
    );
  }

  Widget _seatContent(BuildContext context, Student? student, bool hovering,
      {required Map<String, String> labels,
      required SeatMetrics metrics,
      bool elevated = false}) {
    final cs = Theme.of(context).colorScheme;
    if (student == null) return _emptySeat(cs, hovering, metrics.cell);
    final levelIcon = _levelCornerIcon(student.level);
    final energyIcon = _energyCornerIcon(student.energy);
    final sizeBarHeight = _sizeCornerBarHeight(student.size);
    final width = metrics.cell;
    return Tooltip(
      message: student.fullName,
      child: Container(
        width: width,
        height: kCell,
        decoration: BoxDecoration(
          color: studentColor(student, cs),
          border: Border.all(
            color: hovering ? cs.primary : cs.outline,
            width: hovering ? 2.4 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: elevated
              ? [const BoxShadow(blurRadius: 8, color: Colors.black26)]
              : null,
        ),
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            Center(child: _seatLabel(student, labels, metrics)),
            if (levelIcon != null)
              Positioned(
                top: 0,
                left: 0,
                child: Icon(levelIcon, size: 13, color: _cornerIconColor),
              ),
            if (energyIcon != null)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(energyIcon, size: 13, color: _cornerIconColor),
              ),
            if (sizeBarHeight != null)
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 4,
                  height: sizeBarHeight,
                  decoration: BoxDecoration(
                    color: _cornerIconColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            if (student.poorEyesight)
              const Positioned(
                bottom: 0,
                right: 0,
                child: Icon(Icons.visibility_off,
                    size: 13, color: _cornerIconColor),
              ),
          ],
        ),
      ),
    );
  }

  /// Le prénom quand la case a la place, les initiales désambiguïsées sinon.
  ///
  /// La taille de police est proportionnelle à la largeur de la case, et non
  /// fixe : tout ce contenu est ensuite réduit par le `FittedBox` de la grille,
  /// donc une valeur en dur redeviendrait minuscule dès que la salle est large.
  Widget _seatLabel(
      Student student, Map<String, String> labels, SeatMetrics metrics) {
    if (!metrics.showsFirstName) {
      return Text(
        labels[student.id] ?? student.initials,
        maxLines: 1,
        style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: metrics.initialsFontSize),
      );
    }
    // Prénom sur une ligne, initiale du nom en dessous pour départager deux
    // homonymes de prénom.
    final lastInitial = student.lastName.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          student.firstName.trim().isEmpty ? '?' : student.firstName.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: metrics.nameFontSize),
        ),
        if (lastInitial.isNotEmpty)
          Text(
            '${lastInitial[0].toUpperCase()}.',
            maxLines: 1,
            style: TextStyle(
                fontSize: metrics.nameFontSize * 0.8, color: _cornerIconColor),
          ),
      ],
    );
  }

  /// Place libre. Reçoit la largeur mesurée comme les places occupées : sans
  /// ça, elle resterait carrée au milieu de rectangles et casserait la grille.
  Widget _emptySeat(ColorScheme cs, bool hovering, double width) => Container(
        width: width,
        height: kCell,
        decoration: BoxDecoration(
          color: hovering ? cs.primaryContainer : cs.surface,
          border: Border.all(
            color: hovering ? cs.primary : cs.outlineVariant,
            width: hovering ? 2.4 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.event_seat_outlined, color: cs.outlineVariant, size: 22),
      );
}
