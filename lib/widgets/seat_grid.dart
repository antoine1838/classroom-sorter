/// Grilles réutilisables de la salle :
///  - [RoomEditorGrid] : éditer le plan (toucher une case pour retirer/remettre
///    une place — utile pour dessiner les allées).
///  - [PlanGrid] : afficher l'affectation, avec glisser-déposer pour échanger
///    deux élèves à la main.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'plan_viewport.dart';

import '../engine/plan_issue.dart';
import '../engine/seating_engine.dart';
import '../models/classroom.dart';
import '../models/room.dart';
import '../models/student.dart';

const double kCell = 62;
const double kGap = 6; // espace normal entre deux colonnes
const double kAisle = 24; // largeur/hauteur d'un couloir, colonne ou rang
const double kRowGap = 14; // espace entre rangs sans couloir

/// Rapport largeur/hauteur maximal d'une place. Au-delà, ce n'est plus une
/// place mais une barre.
///
/// Arbitré à l'essai : 3:1 passe encore pour une place, et on accepte le blanc
/// qui reste sur les côtés d'une fenêtre très large — une salle de 7 colonnes
/// sur 5 rangs a un rapport de 2,5:1, elle ne peut pas remplir un 4:1 sans se
/// déformer.
const double kCellMaxAspect = 3;

/// Largeur maximale d'une case, déduite de ce rapport.
const double kCellWideMax = kCell * kCellMaxAspect;

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

/// Marge intérieure d'une place, épaisseur maximale de sa bordure (celle du
/// survol), et hauteur d'une ligne de texte rapportée à sa taille de police.
/// Servent à vérifier qu'une étiquette tient dans la hauteur de la case.
///
/// La bordure est facile à oublier : elle retire 1 px de chaque côté au repos,
/// 2,4 au survol — c'est ce qui manquait au premier calcul. Quant au facteur de
/// ligne, il est délibérément généreux : les métriques réelles dépendent de la
/// police, que `flutter_test` ne reproduit pas.
const double kSeatPadding = 3;
const double kSeatBorderMax = 2.4;
const double kTextLineFactor = 1.5;

/// Hauteur de l'espace inter-rangs après le rang [r] (mêmes règles que
/// [_colGapWidth], sur l'autre axe).
double _rowGapHeight(Room room, int r, {required bool editor}) {
  final aisle = room.hasRowAisleAfter(r);
  return (editor || aisle) ? kAisle : kRowGap;
}

/// Somme des espaces inter-rangs.
double _verticalExtras(Room room, {required bool editor}) {
  var extras = 0.0;
  for (var r = 0; r < room.rows - 1; r++) {
    extras += _rowGapHeight(room, r, editor: editor);
  }
  return extras;
}

/// Hauteur totale de la grille, bandeau et marges compris. Indépendante de
/// l'orientation : seule la LARGEUR d'une case change.
double gridHeight(Room room, {bool editor = false}) =>
    room.rows * kCell +
    _verticalExtras(room, editor: editor) +
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

/// Centre horizontal du couloir après la colonne [c], relatif au bord gauche
/// de la zone des places (sans la marge de la grille) : sert à peindre une
/// grande barre verticale continue sur toute la hauteur de la salle plutôt
/// qu'un trait répété à chaque rang, symétrique de ce qui existe déjà pour
/// les couloirs de rang (voir [_rowGap]).
double _colGapCenterX(Room room, int c, double cell, {required bool editor}) {
  var x = 0.0;
  for (var i = 0; i < c; i++) {
    x += cell + _colGapWidth(room, i, editor: editor);
  }
  return x + cell + _colGapWidth(room, c, editor: editor) / 2;
}

/// Hauteur de la seule zone des places (rangs + espaces inter-rangs), sans la
/// marge de la grille ni le bandeau « DEVANT » — l'étendue verticale que doit
/// couvrir une grande barre de couloir de colonne.
double _seatingAreaHeight(Room room, {required bool editor}) =>
    room.rows * kCell + _verticalExtras(room, editor: editor);

/// Largeur de la seule zone des places (colonnes + espaces inter-colonnes),
/// sans la marge de la grille — le pendant horizontal de
/// [_seatingAreaHeight], pour qu'une grande barre de couloir de rang aille
/// d'un bord à l'autre des places plutôt que de s'arrêter avant, comme le
/// fait déjà la barre verticale d'un couloir de colonne.
double _seatingAreaWidth(Room room, double cell, {required bool editor}) =>
    room.cols * cell + _horizontalExtras(room, editor: editor) - 2 * kGridPadding;

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
  ///
  /// Deux conditions : la case doit être assez large, ET la police qui tient
  /// dans sa hauteur doit rester lisible. Ne regarder que la largeur laissait
  /// afficher un prénom dans une police trop grosse pour la case.
  /// Tolérance : quand le plafond de hauteur ne mord pas, la taille rendue vaut
  /// exactement le minimum, à l'arrondi flottant près.
  bool get showsFirstName =>
      renderedWidth >= kFirstNameMinWidth &&
      renderedNameSize >= kNameSizeMin - 0.01;

  /// Taille de police rendue que l'on VOUDRAIT, si la hauteur le permettait.
  double get _wantedNameSize =>
      (renderedWidth * kNameSizeRatio).clamp(kNameSizeMin, kNameSizeMax);

  /// Police du prénom avant mise à l'échelle.
  ///
  /// Déduite de la taille rendue voulue — mais **plafonnée par la hauteur de la
  /// case**, qui ne bouge pas. Sans ce plafond, une petite échelle demandait une
  /// police non mise à l'échelle si grosse que les deux lignes débordaient de la
  /// case : le défaut se voyait sur TOUTES les places à la fois.
  double get nameFontSize =>
      min(_wantedNameSize / (scale * zoom), _maxNameFontByHeight);

  /// Ce que la hauteur utile d'une case autorise pour deux lignes (le prénom,
  /// puis l'initiale du nom à 80 %).
  static double get _maxNameFontByHeight =>
      (kCell - 2 * kSeatPadding - 2 * kSeatBorderMax) / (kTextLineFactor * 1.8);

  /// Taille de police du prénom telle qu'elle apparaît réellement à l'écran.
  double get renderedNameSize => nameFontSize * scale * zoom;

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
SeatMetrics seatMetrics(
  Room room,
  Size viewport, {
  double zoom = 1,
  bool editor = false,
}) {
  if (viewport.isEmpty || room.cols <= 0 || room.rows <= 0) {
    return SeatMetrics(cell: kCell, scale: 1, zoom: zoom);
  }

  final height = gridHeight(room, editor: editor);
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

/// Fond de la place : réquisitionné par le marquage de sévérité, le canal le
/// plus lisible quand les cases sont petites. Neutre si l'élève n'est
/// concerné par aucun problème.
Color _severityBackground(IssueSeverity? severity, ColorScheme cs) =>
    switch (severity) {
      IssueSeverity.hard => const Color(0xFFF3AFAF),
      IssueSeverity.soft => const Color(0xFFFFD98A),
      null => cs.surface,
    };

/// Le genre, replié sur un liseré au bord gauche : le fond n'est plus
/// disponible, pris par [_severityBackground]. Muet pour « autre », comme les
/// autres indicateurs de coin.
Color? _genderStripeColor(Gender gender) => switch (gender) {
  Gender.fille => const Color(0xFFD6478F),
  Gender.garcon => const Color(0xFF3B82C4),
  Gender.autre => null,
};

/// Bord de la place opposé au regard (le dossier), pour signaler son
/// orientation. [Facing.nord] (par défaut) place ce bord en haut, donc sans
/// changement visuel pour les salles enregistrées avant l'introduction de
/// l'orientation. Affiché à la fois sur une carte d'élève (où le nom empêche
/// de pivoter l'icône) et dans [RoomEditorGrid] (où l'icône pivote déjà) :
/// le même repère dans les deux onglets, pour rester cohérent.
Alignment _backrestAlignment(Facing facing) => switch (facing) {
  Facing.nord => Alignment.topCenter,
  Facing.est => Alignment.centerLeft,
  Facing.sud => Alignment.bottomCenter,
  Facing.ouest => Alignment.centerRight,
};

/// Petite barre du bord de dossier elle-même, partagée entre [RoomEditorGrid]
/// et les cartes d'élève de [PlanGrid] pour un rendu identique. [width] est
/// la largeur de la case (fixe, [kCell], dans l'éditeur ; variable, mise à
/// l'échelle, dans le plan).
Widget _backrestBar(Facing facing, {required double width, Key? key}) {
  final horizontal = facing == Facing.nord || facing == Facing.sud;
  return Container(
    key: key,
    width: horizontal ? width * 0.5 : 3,
    height: horizontal ? 3 : kCell * 0.5,
    color: _cornerIconColor,
  );
}

/// Angle de rotation (radians) de l'icône de siège pour une orientation
/// donnée : [Facing.est] tourne vers l'écran-droite, [Facing.ouest] vers
/// l'écran-gauche — c'est ce qui fait que les deux bras d'un U (gauche en
/// est, droit en ouest, voir buildULayout) se font face plutôt que de
/// tourner le dos l'un à l'autre. Négatif car [Transform.rotate] tourne dans
/// le sens horaire pour un angle positif : sans ce signe, est/ouest étaient
/// inversés (bug remonté après coup, voir la note de chantier).
double _facingRotationAngle(Facing facing) => -facing.index * (pi / 2);

// Icônes de coin : affichées seulement quand la valeur sort de l'ordinaire
// (Moyen / Modéré / Bonne vue restent muets).
const _cornerIconColor = Color(0xFF3A3A3A);
const _kCornerIconSize = 13.0;

// Largeur de la barre de taille : centrée sous l'icône de niveau (même bord
// gauche que top-left), pas collée au bord gauche de la case — sinon elle se
// confond avec le liseré de genre, qui occupe désormais ce bord.
const _kSizeBarWidth = 4.0;
const _kSizeBarLeft = (_kCornerIconSize - _kSizeBarWidth) / 2;

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
      child: Text(
        '⬇  DEVANT (tableau)',
        style: Theme.of(context).textTheme.labelMedium,
      ),
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
  final void Function(int r)? onToggleRowAisle;

  /// Largeur d'une case, mesurée par [seatMetrics].
  final double cell;

  const _FittedGrid({
    required this.room,
    required this.cellBuilder,
    this.onToggleAisle,
    this.onToggleRowAisle,
    this.cell = kCell,
  });

  bool get _editor => onToggleAisle != null;

  @override
  Widget build(BuildContext context) {
    // Rangs affichés du fond (haut) vers le devant (bas) : le tableau est
    // en bas, comme le voit le professeur face à sa classe. On conserve
    // l'index logique r (rang 0 = devant) pour les clés de place et
    // l'affectation — seul l'ordre d'affichage est inversé. Le couloir
    // affiché entre deux rangs consécutifs r et r-1 est celui d'indice r-1
    // ([Room.hasRowAisleAfter]).
    final rows = <Widget>[
      for (var r = room.rows - 1; r >= 0; r--) ...[
        Row(
          children: [
            for (var c = 0; c < room.cols; c++) ...[
              cellBuilder(r, c),
              if (c < room.cols - 1) _colGap(context, c),
            ],
          ],
        ),
        if (r > 0) _rowGap(context, r - 1),
      ],
    ];
    final cs = Theme.of(context).colorScheme;
    // Couloirs de colonne ACTIFS : une grande barre continue par couloir,
    // superposée à la grille plutôt que peinte à chaque rang — symétrique du
    // traitement déjà fait pour les couloirs de rang (voir _rowGap). Une
    // simple Container non interactive : elle ne vole aucun tap aux
    // GestureDetector de _colGap qui restent dessous, dans la grille.
    final seatingHeight = _seatingAreaHeight(room, editor: _editor);
    final seatingArea = Stack(
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
        for (final c in room.colAisles)
          if (c >= 0 && c < room.cols - 1)
            Positioned(
              left: _colGapCenterX(room, c, cell, editor: _editor) - 2,
              top: 0,
              width: 4,
              height: seatingHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
      ],
    );
    final grid = Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          seatingArea,
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
    // Le trait d'un couloir ACTIF est peint une seule fois, en une grande
    // barre verticale qui traverse toute la salle (voir le Stack dans
    // build()) — pas ici, ce qui donnerait un pointillé par rang plutôt
    // qu'une seule barre continue, comme pour les couloirs de rang.
    final gap = SizedBox(
      width: _colGapWidth(room, c, editor: _editor),
      height: kCell,
      child: Center(
        child: (!room.hasColAisleAfter(c) && _editor)
            ? Container(
                width: 2,
                height: kCell * 0.5,
                color: cs.outlineVariant,
              )
            : const SizedBox.shrink(),
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

  /// Miroir de [_colGap] sur l'axe des rangs : [r] est l'indice du couloir
  /// (entre les rangs `r` et `r+1`), pas un index d'affichage.
  ///
  /// Les deux cas suivent maintenant exactement le traitement des couloirs de
  /// colonne, plutôt que de traiter la ligne entière comme un seul bloc :
  /// couloir actif => une grande barre qui va d'un bord à l'autre des places
  /// (comme la barre verticale va de haut en bas) ; pas de couloir, en mode
  /// éditeur => un repère par colonne, aligné sous chaque place (comme le
  /// repère de colonne est répété à chaque rang).
  Widget _rowGap(BuildContext context, int r) {
    final cs = Theme.of(context).colorScheme;
    final aisle = room.hasRowAisleAfter(r);
    final Widget content;
    if (aisle) {
      content = Container(
        height: 4,
        width: _seatingAreaWidth(room, cell, editor: _editor),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else if (_editor) {
      content = Row(
        children: [
          for (var c = 0; c < room.cols; c++) ...[
            SizedBox(
              width: cell,
              child: Center(
                child: Container(
                  height: 2,
                  width: cell * 0.5,
                  color: cs.outlineVariant,
                ),
              ),
            ),
            if (c < room.cols - 1)
              SizedBox(width: _colGapWidth(room, c, editor: _editor)),
          ],
        ],
      );
    } else {
      content = const SizedBox.shrink();
    }
    final gap = SizedBox(
      width: gridWidth(room, editor: _editor, cell: cell),
      height: _rowGapHeight(room, r, editor: _editor),
      child: Center(child: content),
    );
    if (!_editor) return gap;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggleRowAisle!(r),
      child: gap,
    );
  }
}

class RoomEditorGrid extends StatelessWidget {
  final Room room;
  final VoidCallback onChanged;
  const RoomEditorGrid({
    super.key,
    required this.room,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _FittedGrid(
      room: room,
      onToggleAisle: (c) {
        room.toggleColAisle(c);
        onChanged();
      },
      onToggleRowAisle: (r) {
        room.toggleRowAisle(r);
        onChanged();
      },
      cellBuilder: (r, c) => _buildCell(cs, r, c),
    );
  }

  /// Une case de l'éditeur : gestes (voir le commentaire sur `onTap`
  /// ci-dessous) et rendu (icône pivotée + bord de dossier, voir
  /// [_facingRotationAngle] / [_backrestBar]). Extrait de [build] pour rester
  /// sous la limite de complexité cognitive (S3776) : la case a son propre
  /// niveau d'imbrication, plutôt que d'empiler ses conditions sur celles du
  /// `cellBuilder` qui l'appelait en ligne.
  Widget _buildCell(ColorScheme cs, int r, int c) {
    final isSeat = room.isSeat(r, c);
    // Case vide : le seul geste est d'y poser une place. Place existante :
    // le tap la fait tourner (geste répété après avoir posé un modèle),
    // l'appui long ou le clic droit (équivalent souris sur Windows) la
    // retire — le geste destructeur est délibérément le moins accessible.
    return InkWell(
      onTap: () {
        if (isSeat) {
          room.rotateFacing(r, c);
        } else {
          room.toggle(r, c);
        }
        onChanged();
      },
      onLongPress: isSeat
          ? () {
              room.toggle(r, c);
              onChanged();
            }
          : null,
      onSecondaryTap: isSeat
          ? () {
              room.toggle(r, c);
              onChanged();
            }
          : null,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              isSeat
                  ? Transform.rotate(
                      angle: _facingRotationAngle(room.facingOf(r, c)),
                      child: Icon(
                        Icons.event_seat_outlined,
                        color: cs.primary,
                        size: 26,
                      ),
                    )
                  : Icon(Icons.block, color: cs.outlineVariant, size: 26),
              // Même repère que sur les cartes du Plan (_seatContent),
              // pour rester cohérent entre les deux onglets — même si
              // l'icône pivotée donne déjà l'orientation ici.
              if (isSeat)
                Positioned.fill(
                  child: Align(
                    alignment: _backrestAlignment(room.facingOf(r, c)),
                    child: _backrestBar(room.facingOf(r, c), width: kCell),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ce qu'il faut à [PlanGrid] pour rendre une place occupée, en dehors de
/// l'élève lui-même et de l'état transitoire (survol, élévation) : identique
/// aux deux endroits où `_seatContent` est appelé (la case et son retour de
/// glisser-déposer), donc regroupé plutôt que passé quatre fois de suite —
/// c'est aussi ce qui garde `_seatContent` sous la limite de paramètres.
typedef _SeatRenderContext = ({
  Map<String, String> labels,
  SeatMetrics metrics,
  Facing facing,
  PlanResult? result,
});

class PlanGrid extends StatelessWidget {
  final ClassGroup cls;

  /// Échanger les occupants de deux places (glisser-déposer).
  final void Function(String seatA, String seatB) onSwap;

  /// Compteur de doigts partagé avec la fenêtre de zoom : une place refuse de se
  /// laisser saisir dès qu'il y a deux doigts, sinon un pincement posé dessus
  /// déclencherait un glisser par doigt.
  final PointerTracker? tracker;

  /// Dernier plan validé : fournit la sévérité et les motifs à marquer sur les
  /// places. Nul tant qu'aucun plan n'a été généré ou validé.
  final PlanResult? result;

  /// Tap sur une place occupée : ouvre la feuille de détail de l'élève.
  final void Function(Student student)? onTapSeat;

  /// Échelle courante de [PlanViewport], au-dessus : sans elle, un pincement
  /// grossit les places visuellement (Transform) mais ne fait jamais basculer
  /// des initiales vers le prénom, puisque [seatMetrics] la croirait toujours
  /// à 1.
  final double zoom;

  const PlanGrid({
    super.key,
    required this.cls,
    required this.onSwap,
    this.tracker,
    this.result,
    this.onTapSeat,
    this.zoom = 1,
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
        final m = seatMetrics(cls.room, constraints.biggest, zoom: zoom);

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
            final facing = cls.room.facingOf(r, c);
            // Regroupé pour ne pas repasser individuellement labels/metrics/
            // facing/result à chacun des deux appels ci-dessous, identiques
            // sur ce point (voir _SeatRenderContext).
            final ctx =
                (labels: labels, metrics: m, facing: facing, result: result);

            return DragTarget<String>(
              onWillAcceptWithDetails: (d) => d.data != seatKey,
              onAcceptWithDetails: (d) => onSwap(d.data, seatKey),
              builder: (context, candidate, rejected) {
                final hovering = candidate.isNotEmpty;
                final cell = _seatContent(context, student, hovering, ctx,
                    onTapSeat: onTapSeat);
                if (student == null) return cell;
                final feedback = Material(
                  color: Colors.transparent,
                  child: _seatContent(context, student, false, ctx,
                      elevated: true),
                );
                final placeholder = _emptySeat(cs, false, m.cell, facing);
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

  Widget _seatContent(
    BuildContext context,
    Student? student,
    bool hovering,
    _SeatRenderContext ctx, {
    void Function(Student student)? onTapSeat,
    bool elevated = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (student == null) {
      return _emptySeat(cs, hovering, ctx.metrics.cell, ctx.facing);
    }
    final levelIcon = _levelCornerIcon(student.level);
    final energyIcon = _energyCornerIcon(student.energy);
    final sizeBarHeight = _sizeCornerBarHeight(student.size);
    final width = ctx.metrics.cell;
    final severity = ctx.result?.severityFor(student.id);
    final stripeColor = _genderStripeColor(student.gender);
    final outline = hovering ? cs.primary : cs.outline;
    final outlineWidth = hovering ? 2.4 : 1.0;
    final box = Container(
      width: width,
      height: kCell,
      decoration: BoxDecoration(
        color: _severityBackground(severity, cs),
        border: Border.all(color: outline, width: outlineWidth),
        borderRadius: BorderRadius.circular(8),
        boxShadow: elevated
            ? [const BoxShadow(blurRadius: 8, color: Colors.black26)]
            : null,
      ),
      padding: const EdgeInsets.all(kSeatPadding),
      child: Stack(
        children: [
          Center(child: _seatLabel(student, ctx.labels, ctx.metrics)),
          if (levelIcon != null)
            Positioned(
              top: 0,
              left: 0,
              child: Icon(levelIcon,
                  size: _kCornerIconSize, color: _cornerIconColor),
            ),
          if (energyIcon != null)
            Positioned(
              top: 0,
              right: 0,
              child: Icon(energyIcon,
                  size: _kCornerIconSize, color: _cornerIconColor),
            ),
          if (sizeBarHeight != null)
            Positioned(
              bottom: 0,
              left: _kSizeBarLeft,
              child: Container(
                width: _kSizeBarWidth,
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
              child: Icon(
                Icons.visibility_off,
                size: _kCornerIconSize,
                color: _cornerIconColor,
              ),
            ),
        ],
      ),
    );
    // Le liseré de genre est peint EN SUS de la case, pas comme un côté de sa
    // bordure : `Border` refuse des couleurs par côté dès qu'un `borderRadius`
    // est présent (« borders with uniform colors » uniquement). Le survol du
    // glisser-déposer prime dessus : c'est un retour transitoire sur toute la
    // bordure, plus important que le genre à cet instant précis.
    final seat = SizedBox(
      width: width,
      height: kCell,
      child: Stack(
        children: [
          box,
          // Découpé à la taille PLEINE de la case (et non à celle, étroite,
          // du liseré) : un `ClipRRect` de rayon 8 sur une bande de 4dp de
          // large rogne presque toute sa largeur en haut/bas et dessine une
          // courbe qui ne correspond plus du tout à celle de la case. En
          // clippant le plein cadre puis en n'affichant que la bande de
          // gauche, le même rayon 8 produit exactement la même courbe.
          if (!hovering && stripeColor != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: ValueKey('gender_stripe_${student.id}'),
                    width: 4,
                    color: stripeColor,
                  ),
                ),
              ),
            ),
          // Bord de dossier : un trait posé sur le cadre de la case, pas
          // flottant dans son contenu — il ne peut donc pas dériver vers le
          // texte du nom quel que soit la taille de la carte (contrairement
          // à un décalage fractionnel, voir la note de chantier). Peint
          // APRÈS le liseré de genre ci-dessus, pour rester visible même
          // quand il tombe sur le même bord (facing est) : sans lui,
          // l'orientation d'un élève genré serait invisible sur sa carte
          // (remonté après coup — voir la note de chantier).
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Align(
                alignment: _backrestAlignment(ctx.facing),
                child: _backrestBar(ctx.facing,
                    width: width, key: ValueKey('backrest_${student.id}')),
              ),
            ),
          ),
        ],
      ),
    );
    // Clé stable par élève : localise la place en test sans dépendre d'un
    // texte affiché (prénom/initiales varient avec l'échelle), depuis que le
    // Tooltip de nom complet a été retiré au profit de la feuille au tap.
    final keyed = KeyedSubtree(
      key: ValueKey('seat_${student.id}'),
      child: seat,
    );
    if (onTapSeat == null) return keyed;
    // opaque : toute la case répond au tap, pas seulement les zones peintes.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapSeat(student),
      child: keyed,
    );
  }

  /// Le prénom quand la case a la place, les initiales désambiguïsées sinon.
  ///
  /// Les deux branches ne dimensionnent PAS leur police de la même façon.
  /// Les initiales suivent [SeatMetrics.initialsFontSize] (simple proportion de
  /// la largeur de case) : peu de caractères, autant qu'ils remplissent la case.
  /// Le prénom suit [SeatMetrics.nameFontSize] (taille rendue ciblée, plafonnée
  /// par la hauteur) — voir la documentation de ce getter pour le pourquoi.
  Widget _seatLabel(
    Student student,
    Map<String, String> labels,
    SeatMetrics metrics,
  ) {
    if (!metrics.showsFirstName) {
      return Text(
        labels[student.id] ?? student.initials,
        maxLines: 1,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: metrics.initialsFontSize,
        ),
      );
    }
    // Prénom sur une ligne, initiale du nom en dessous pour départager deux
    // homonymes de prénom.
    //
    // FittedBox en filet de sécurité : le calcul ci-dessus dépend de métriques
    // de police qu'on ne peut pas connaître exactement, et un débordement
    // barbouillait TOUTES les places d'un bandeau rouge. Ici, au pire, le texte
    // rétrécit d'un cheveu.
    final lastInitial = student.lastName.trim();
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            student.firstName.trim().isEmpty ? '?' : student.firstName.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: metrics.nameFontSize,
            ),
          ),
          if (lastInitial.isNotEmpty)
            Text(
              '${lastInitial[0].toUpperCase()}.',
              maxLines: 1,
              style: TextStyle(
                fontSize: metrics.nameFontSize * 0.8,
                color: _cornerIconColor,
              ),
            ),
        ],
      ),
    );
  }

  /// Place libre. Reçoit la largeur mesurée comme les places occupées : sans
  /// ça, elle resterait carrée au milieu de rectangles et casserait la grille.
  ///
  /// L'icône est pivotée selon [facing], comme dans [RoomEditorGrid] : c'est
  /// le seul endroit de ce onglet où l'orientation d'une place se voit
  /// directement sur une icône plutôt que sur le bord de dossier d'une carte
  /// (voir [_seatContent]), puisqu'il n'y a pas de nom à préserver ici.
  Widget _emptySeat(ColorScheme cs, bool hovering, double width, Facing facing) =>
      Container(
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
        child: Transform.rotate(
          angle: _facingRotationAngle(facing),
          child: Icon(Icons.event_seat_outlined,
              color: cs.outlineVariant, size: 22),
        ),
      );
}
