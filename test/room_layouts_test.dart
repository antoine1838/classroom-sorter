/// Vérifie les générateurs de dispositions de salle (onglet Salle, sélecteur
/// de modèle) : Rangées, U, Îlots, Page blanche. Voir
/// notes/dispositions-de-salle.md pour le raisonnement géométrique.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/room_layouts.dart';

void main() {
  group('Rangées', () {
    test('salle pleine, sans forme particulière', () {
      final room = buildRangeesLayout(rows: 3, cols: 4);

      expect(room.capacity, 12);
      expect(room.disabled, isEmpty);
      for (final k in room.seatKeys) {
        final (r, c) = Room.parse(k);
        expect(room.facingOf(r, c), Facing.nord);
      }
    });
  });

  group('Page blanche', () {
    test('grille entièrement désactivée', () {
      final room = buildBlancheLayout(rows: 2, cols: 3);

      expect(room.capacity, 0);
      expect(room.rows, 2);
      expect(room.cols, 3);
      for (var r = 0; r < 2; r++) {
        for (var c = 0; c < 3; c++) {
          expect(room.isSeat(r, c), isFalse);
        }
      }
    });
  });

  group('U simple', () {
    final room = buildULayout(armDepth: 2);

    test('dimensions : armWidth 1, creux de 3, armDepth + rangée du fond',
        () {
      expect(room.cols, 5); // 1 + 3 + 1
      expect(room.rows, 3); // armDepth (2) + rangée du fond
    });

    test('rangée du fond pleine, orientée vers le tableau (nord)', () {
      final backRow = room.rows - 1;
      for (var c = 0; c < room.cols; c++) {
        expect(room.isSeat(backRow, c), isTrue);
        expect(room.facingOf(backRow, c), Facing.nord);
      }
    });

    test(
        'bras gauche vers l\'est, bras droit vers l\'ouest, creux vide, '
        'ouverture côté tableau', () {
      for (var r = 0; r < room.rows - 1; r++) {
        expect(room.facingOf(r, 0), Facing.est);
        expect(room.facingOf(r, room.cols - 1), Facing.ouest);
        for (var c = 1; c < room.cols - 1; c++) {
          expect(room.isSeat(r, c), isFalse,
              reason: 'creux du U à (r=$r, c=$c)');
        }
      }
    });

    test('capacité : rangée du fond + un siège par bras et par rang', () {
      expect(room.capacity, room.cols + 2 * 2);
    });
  });

  group('U double', () {
    test('bras deux fois plus larges, rangée du fond doublée', () {
      final room = buildULayout(armDepth: 1, doubleArm: true);

      expect(room.cols, 7); // 2 + 3 + 2
      expect(room.rows, 3); // armDepth (1) + rangée du fond doublée (2)
      expect(room.facingOf(0, 0), Facing.est);
      expect(room.facingOf(0, 1), Facing.est);
      expect(room.facingOf(0, 5), Facing.ouest);
      expect(room.facingOf(0, 6), Facing.ouest);
      for (var c = 2; c < 5; c++) {
        expect(room.isSeat(0, c), isFalse);
      }
      for (final r in [1, 2]) {
        for (var c = 0; c < room.cols; c++) {
          expect(room.facingOf(r, c), Facing.nord,
              reason: 'rangée du fond doublée : rang $r');
        }
      }
    });
  });

  group('Îlots', () {
    test('taille 4 : tables de 2×2 séparées par un couloir', () {
      final room = buildIlotsLayout(islandSize: 4, islandCount: 3);

      expect(room.rows, 2);
      expect(room.cols, 6); // 3 îlots de 2 colonnes
      expect(room.capacity, 12, reason: 'aucune case désactivée');
      expect(room.colAisles, {1, 3},
          reason: 'un couloir après chaque îlot sauf le dernier');
    });

    test('taille 6 : tables de 2×3', () {
      final room = buildIlotsLayout(islandSize: 6, islandCount: 2);

      expect(room.cols, 6); // 2 îlots de 3 colonnes
      expect(room.colAisles, {2});
    });

    test(
        'taille 4 : appariement par colonne, assis de côté, pas face/dos '
        'au tableau', () {
      final room = buildIlotsLayout(islandSize: 4, islandCount: 2);

      for (final island in [0, 1]) {
        final left = island * 2;
        final right = left + 1;
        for (final r in [0, 1]) {
          expect(room.facingOf(r, left), Facing.est,
              reason: 'îlot $island, colonne gauche, rang $r');
          expect(room.facingOf(r, right), Facing.ouest,
              reason: 'îlot $island, colonne droite, rang $r');
        }
      }
    });

    test(
        'taille 6 : colonnes latérales de côté, colonne centrale face/dos '
        'normal', () {
      final room = buildIlotsLayout(islandSize: 6, islandCount: 1);

      for (final r in [0, 1]) {
        expect(room.facingOf(r, 0), Facing.est, reason: 'colonne gauche');
        expect(room.facingOf(r, 2), Facing.ouest, reason: 'colonne droite');
      }
      expect(room.facingOf(0, 1), Facing.nord, reason: 'colonne centrale, avant');
      expect(room.facingOf(1, 1), Facing.sud, reason: 'colonne centrale, arrière');
    });

    test('un couloir sépare deux îlots : ils ne partagent aucun voisin', () {
      final room = buildIlotsLayout(islandSize: 4, islandCount: 2);
      // Dernière colonne du premier îlot (c=1) et première du second (c=2).
      expect(room.colAisleBetween(1, 2), isTrue);
    });

    test('plusieurs bandes : chacune orientée, séparée par un couloir de rang',
        () {
      final room =
          buildIlotsLayout(islandSize: 4, islandCount: 2, islandRows: 2);

      expect(room.rows, 4); // 2 bandes de 2 rangs
      for (final r in [0, 1, 2, 3]) {
        expect(room.facingOf(r, 0), Facing.est, reason: 'rang $r, colonne gauche');
        expect(room.facingOf(r, 1), Facing.ouest, reason: 'rang $r, colonne droite');
      }
      expect(room.rowAisleBetween(1, 2), isTrue,
          reason: 'les deux bandes ne doivent pas être voisines');
    });

    test('une seule bande (par défaut) : aucun couloir de rang', () {
      final room = buildIlotsLayout(islandSize: 4, islandCount: 2);
      expect(room.rowAisles, isEmpty);
    });
  });
}
