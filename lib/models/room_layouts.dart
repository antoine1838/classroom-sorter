/// Générateurs de dispositions de salle prêtes à l'emploi, pour le
/// sélecteur de modèle de l'onglet Salle (voir notes/dispositions-de-salle.md).
///
/// Chacun produit une [Room] neuve ; aucun ne modifie une salle existante,
/// c'est à l'appelant de remplacer `ClassGroup.room` et de nettoyer ce qui en
/// dépend (affectation, places imposées hors grille).
library;

import 'room.dart';

enum RoomLayoutKind { rangees, u, ilots, blanche }

/// Salle en rangées classique : rows × cols places, sans forme particulière.
/// C'est la disposition par défaut de [Room] elle-même.
Room buildRangeesLayout({required int rows, required int cols}) =>
    Room(rows: rows, cols: cols);

/// Page blanche : la grille rows × cols existe mais toutes ses cases sont
/// désactivées, prête à être peuplée case par case.
Room buildBlancheLayout({required int rows, required int cols}) => Room(
      rows: rows,
      cols: cols,
      disabled: {
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++) Room.keyOf(r, c),
      },
    );

/// Salle en U : une rangée de devant pleine (rang 0, orientée vers le
/// tableau), puis deux bras qui remontent vers le fond, orientés l'un vers
/// l'autre — bras gauche vers l'est, bras droit vers l'ouest, comme décrit
/// dans la note de chantier. Le creux entre les bras reste vide.
///
/// [armDepth] est le nombre de rangs de chaque bras, DERRIÈRE la rangée de
/// devant. [doubleArm] double la largeur de chaque bras (2 colonnes au lieu
/// d'1), pour des bras à deux élèves de front.
Room buildULayout({int armDepth = 3, bool doubleArm = false}) {
  final armWidth = doubleArm ? 2 : 1;
  const centerGap = 3; // largeur du creux du U, purement esthétique
  final cols = armWidth * 2 + centerGap;
  final rows = armDepth + 1; // + la rangée de devant (rang 0)
  final disabled = <String>{};
  final facing = <String, Facing>{};
  for (var r = 1; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (c < armWidth) {
        facing[Room.keyOf(r, c)] = Facing.est; // bras gauche, vers le centre
      } else if (c >= cols - armWidth) {
        facing[Room.keyOf(r, c)] = Facing.ouest; // bras droit, vers le centre
      } else {
        disabled.add(Room.keyOf(r, c)); // creux du U
      }
    }
  }
  return Room(rows: rows, cols: cols, disabled: disabled, facing: facing);
}

/// Salle en îlots : des tables de 4 (2×2) ou 6 (2×3) élèves, alignées en
/// bandes de deux rangs, séparées par un couloir — de colonne entre deux
/// îlots d'une même bande, de rang entre deux bandes — donc jamais voisines
/// entre elles (deux meubles distincts, voir la note de chantier).
///
/// Les élèves sont assis DE CÔTÉ par rapport au tableau, pas face à lui ni
/// dos à lui — c'est ce qui distingue visuellement un îlot d'une rangée.
/// L'appariement se fait par COLONNE, pas par rang : dans chaque îlot, la
/// colonne de gauche fait face à l'est (vers le centre de l'îlot), celle de
/// droite fait face à l'ouest, et les deux rangs d'une même colonne
/// partagent la même orientation — la disposition « rangée » tournée de 90°
/// dans son ensemble.
///
/// Une table de 6 (3 colonnes) a une colonne centrale supplémentaire : elle
/// garde un appariement normal face/dos au tableau (nord/sud), entre les
/// deux colonnes latérales tournées vers elle.
///
/// [islandRows] est le nombre de bandes (1 par défaut, une seule rangée
/// d'îlots) ; chacune ajoute 2 rangs à la salle.
Room buildIlotsLayout(
    {int islandSize = 4, int islandCount = 3, int islandRows = 1}) {
  final islandCols = islandSize == 6 ? 3 : 2;
  final cols = islandCols * islandCount;
  final rows = islandRows * 2;
  final facing = <String, Facing>{};
  for (var b = 0; b < islandRows; b++) {
    final front = b * 2;
    final back = front + 1;
    for (var c = 0; c < cols; c++) {
      final localCol = c % islandCols;
      if (islandCols == 3 && localCol == 1) {
        facing[Room.keyOf(front, c)] = Facing.nord;
        facing[Room.keyOf(back, c)] = Facing.sud;
      } else {
        final dir = localCol < islandCols / 2 ? Facing.est : Facing.ouest;
        facing[Room.keyOf(front, c)] = dir;
        facing[Room.keyOf(back, c)] = dir;
      }
    }
  }
  final colAisles = <int>{
    for (var i = 1; i < islandCount; i++) i * islandCols - 1,
  };
  final rowAisles = <int>{
    for (var b = 0; b < islandRows - 1; b++) b * 2 + 1,
  };
  return Room(
    rows: rows,
    cols: cols,
    facing: facing,
    colAisles: colAisles,
    rowAisles: rowAisles,
  );
}
