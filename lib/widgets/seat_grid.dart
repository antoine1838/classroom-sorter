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

/// Largeur d'une case en paysage. Plus large que haute : en paysage la hauteur
/// est la ressource rare et la largeur abondante, exactement l'inverse du
/// portrait — d'où des rectangles ici et des carrés là.
const double kCellWide = 90;

/// Au-delà de cette largeur RENDUE (après réduction et zoom), une case a la
/// place d'écrire un prénom ; en dessous elle s'en tient aux initiales.
///
/// Une seule règle, quatre comportements corrects : portrait 8 colonnes (~44dp)
/// → initiales ; portrait zoomé ×1,25 (~55dp) → prénom ; paysage (~80dp) →
/// prénom ; petite salle de 5 colonnes en portrait (62dp) → prénom d'emblée,
/// sans rien demander à l'utilisateur.
///
/// Valeur calculée pour un prénom de 8 lettres à 11px (8 × ~0,55 × 11 ≈ 48dp,
/// plus la marge intérieure) — à confirmer dans l'app réelle, les polices
/// factices de `flutter_test` ne mesurant pas le texte comme le moteur.
const double kFirstNameMinWidth = 54;

/// Hauteur totale de la grille, hors bandeau « devant ». Indépendante de
/// l'orientation : seule la LARGEUR d'une case change (voir [kCellWide]).
double gridHeight(Room room) =>
    room.rows * kCell + (room.rows - 1) * kRowGap;

/// Facteur appliqué par le [FittedBox] pour que la salle tienne d'un coup dans
/// [viewport]. Jamais supérieur à 1 : une petite salle garde sa taille naturelle.
double fitScale(Room room, Size viewport, {bool landscape = false}) {
  if (viewport.isEmpty) return 1;
  final w = gridWidth(room, landscape: landscape);
  final h = gridHeight(room);
  if (w <= 0 || h <= 0) return 1;
  final scale = min(viewport.width / w, viewport.height / h);
  return scale > 1 ? 1 : scale;
}

/// Largeur d'une case telle qu'elle sera réellement rendue à l'écran.
double renderedCellWidth(Room room, Size viewport,
        {bool landscape = false, double zoom = 1}) =>
    cellWidth(landscape: landscape) *
    fitScale(room, viewport, landscape: landscape) *
    zoom;

/// Vrai si les cases ont la place d'afficher un prénom plutôt que des initiales.
bool showsFirstName(Room room, Size viewport,
        {bool landscape = false, double zoom = 1}) =>
    renderedCellWidth(room, viewport, landscape: landscape, zoom: zoom) >=
    kFirstNameMinWidth;

double cellWidth({bool landscape = false}) => landscape ? kCellWide : kCell;

/// Largeur de l'espace inter-colonnes après la colonne [c].
/// En mode éditeur, l'espace reste large partout pour être facile à toucher ;
/// en affichage, il ne s'élargit qu'aux vrais couloirs.
double _colGapWidth(Room room, int c, {required bool editor}) {
  final aisle = room.hasColAisleAfter(c);
  return (editor || aisle) ? kAisle : kGap;
}

double gridWidth(Room room, {bool editor = false, bool landscape = false}) {
  var w = room.cols * cellWidth(landscape: landscape);
  for (var c = 0; c < room.cols - 1; c++) {
    w += _colGapWidth(room, c, editor: editor);
  }
  return w;
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

  /// Cases larges plutôt que carrées (voir [kCellWide]).
  final bool landscape;

  const _FittedGrid({
    required this.room,
    required this.cellBuilder,
    this.onToggleAisle,
    this.landscape = false,
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
          _FrontBanner(gridWidth(room, editor: _editor, landscape: landscape)),
        ],
      ),
    );
    // BoxFit.scaleDown ne fait que rétrécir — une petite salle garde sa taille
    // naturelle et reste alignée en haut.
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.scaleDown,
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

  /// Cases larges portant le prénom, plutôt que carrées (paysage).
  final bool landscape;

  /// Compteur de doigts partagé avec la fenêtre de zoom : une place refuse de se
  /// laisser saisir dès qu'il y a deux doigts, sinon un pincement posé dessus
  /// déclencherait un glisser par doigt.
  final PointerTracker? tracker;

  const PlanGrid({
    super.key,
    required this.cls,
    required this.onSwap,
    this.landscape = false,
    this.tracker,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = cellWidth(landscape: landscape);
    // Étiquettes calculées une fois pour toute la classe : la désambiguïsation
    // a besoin de voir tout le monde pour repérer les collisions.
    final labels = disambiguatedInitials(cls.students);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Le prénom ne s'affiche que si la case aura vraiment la place, ce qui
        // dépend de la réduction appliquée — donc de l'espace disponible ici.
        final named = showsFirstName(cls.room, constraints.biggest,
            landscape: landscape);

        return _FittedGrid(
          room: cls.room,
          landscape: landscape,
          cellBuilder: (r, c) {
            if (!cls.room.isSeat(r, c)) {
              // Allée / vide : simple espace.
              return SizedBox(width: width, height: kCell);
            }
            final seatKey = Room.keyOf(r, c);
            final student = cls.studentById(cls.assignment[seatKey]);

            return DragTarget<String>(
              onWillAcceptWithDetails: (d) => d.data != seatKey,
              onAcceptWithDetails: (d) => onSwap(d.data, seatKey),
              builder: (context, candidate, rejected) {
                final hovering = candidate.isNotEmpty;
                final cell = _seatContent(context, student, hovering,
                    labels: labels, named: named);
                if (student == null) return cell;
                final feedback = Material(
                  color: Colors.transparent,
                  child: _seatContent(context, student, false,
                      labels: labels, named: named, elevated: true),
                );
                final placeholder = _emptySeat(cs, false);
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
      required bool named,
      bool elevated = false}) {
    final cs = Theme.of(context).colorScheme;
    if (student == null) return _emptySeat(cs, hovering);
    final levelIcon = _levelCornerIcon(student.level);
    final energyIcon = _energyCornerIcon(student.energy);
    final sizeBarHeight = _sizeCornerBarHeight(student.size);
    final width = cellWidth(landscape: landscape);
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
            Center(child: _seatLabel(student, labels, named, width)),
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
      Student student, Map<String, String> labels, bool named, double width) {
    if (!named) {
      return Text(
        labels[student.id] ?? student.initials,
        maxLines: 1,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: width * 0.26),
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: width * 0.16),
        ),
        if (lastInitial.isNotEmpty)
          Text(
            '${lastInitial[0].toUpperCase()}.',
            maxLines: 1,
            style: TextStyle(fontSize: width * 0.13, color: _cornerIconColor),
          ),
      ],
    );
  }

  Widget _emptySeat(ColorScheme cs, bool hovering) => Container(
        width: kCell,
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
