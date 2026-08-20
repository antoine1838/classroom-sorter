// Les deux règles pures de l'affichage d'une place (issue #8, étape 3) :
//
//  - les initiales doivent lever l'ambiguïté entre deux élèves ;
//  - une case affiche un prénom dès qu'elle a la place, sinon les initiales.
//
// Ces règles sont testées ici SANS interface, pour ne pas dépendre du rendu de
// texte : les polices de `flutter_test` ne mesurent pas comme le vrai moteur.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/widgets/seat_grid.dart';

Student _s(String id, String first, String last) =>
    Student(id: id, firstName: first, lastName: last);

void main() {
  group('Initiales désambiguïsées', () {
    test('sans conflit, on garde les initiales', () {
      final labels = disambiguatedInitials([
        _s('1', 'Marie', 'Dupont'),
        _s('2', 'Paul', 'Martin'),
      ]);

      expect(labels['1'], 'MD');
      expect(labels['2'], 'PM');
    });

    test('un conflit s\'arrête dès que deux lettres suffisent', () {
      final labels = disambiguatedInitials([
        _s('1', 'Marie', 'Dupont'),
        _s('2', 'Marc', 'Delon'),
      ]);

      expect(labels['1'], 'M.Du');
      expect(labels['2'], 'M.De');
    });

    test('un conflit en cascade allonge autant que nécessaire', () {
      // Dupont / Durand / Dubois commencent tous par « Du » : il faut aller
      // jusqu'à trois lettres.
      final labels = disambiguatedInitials([
        _s('1', 'Marie', 'Dupont'),
        _s('2', 'Marc', 'Durand'),
        _s('3', 'Manon', 'Dubois'),
      ]);

      expect(labels.values.toSet(), hasLength(3),
          reason: 'les trois étiquettes doivent être distinctes');
      expect(labels['1'], 'M.Dup');
      expect(labels['2'], 'M.Dur');
      expect(labels['3'], 'M.Dub');
    });

    test('seuls les groupes en conflit sont allongés', () {
      final labels = disambiguatedInitials([
        _s('1', 'Marie', 'Dupont'),
        _s('2', 'Marc', 'Durand'),
        _s('3', 'Paul', 'Martin'),
      ]);

      expect(labels['3'], 'PM',
          reason: 'Paul Martin n\'est en conflit avec personne');
    });

    test('homonymie complète : on s\'arrête sans inventer de code', () {
      final labels = disambiguatedInitials([
        _s('1', 'Marie', 'Dupont'),
        _s('2', 'Marie', 'Dupont'),
      ]);

      expect(labels['1'], labels['2'],
          reason: 'deux homonymes sont indiscernables sur une case');
      expect(labels['1'], isNotEmpty);
    });

    test('noms partiels et vides ne font pas planter', () {
      final labels = disambiguatedInitials([
        _s('1', 'Marie', ''),
        _s('2', 'Marc', ''),
        _s('3', '', 'Dupont'),
        Student(id: '4'),
      ]);

      expect(labels['1'], isNotEmpty);
      expect(labels['3'], isNotEmpty);
      expect(labels['4'], '?');
    });

    test('un nom plus court que l\'allongement demandé est toléré', () {
      final labels = disambiguatedInitials([
        _s('1', 'Luc', 'Le'),
        _s('2', 'Léa', 'Leroy'),
      ]);

      expect(labels.values.toSet(), hasLength(2));
    });
  });

  group('Mesures d\'une place', () {
    // Galaxy A56 en logique : 411 × 891. Espace réellement laissé à la grille
    // dans chaque orientation, chrome et marges déduits.
    const portrait = Size(387, 651);
    const landscape = Size(811, 299);

    /// Grande fenêtre de bureau / tablette.
    const grandEcran = Size(1400, 1200);

    /// Nombre approximatif de caractères qui tiennent dans une case, à la
    /// taille de police RENDUE. C'est LA mesure qui compte : la largeur seule ne
    /// dit rien si la police grandit en même temps.
    double letters(SeatMetrics m) {
      final usable = m.renderedWidth - 2 * 3 * m.scale;
      return usable / (0.55 * m.renderedNameSize);
    }

    test('portrait, 8 colonnes : initiales', () {
      final m = seatMetrics(Room(rows: 5, cols: 8), portrait);

      expect(m.cell, kCell, reason: 'cases carrées en portrait');
      expect(m.renderedWidth, lessThan(kFirstNameMinWidth));
      expect(m.showsFirstName, isFalse);
    });

    test('portrait, 8 colonnes, zoom : le prénom apparaît', () {
      final m = seatMetrics(Room(rows: 5, cols: 8), portrait, zoom: 1.4);

      expect(m.showsFirstName, isTrue);
    });

    test('portrait, petite salle : prénom d\'emblée', () {
      final m = seatMetrics(Room(rows: 5, cols: 5), portrait);

      expect(m.showsFirstName, isTrue);
    });

    test('paysage : les cases s\'élargissent pour gagner des LETTRES', () {
      final small = seatMetrics(Room(rows: 5, cols: 8), portrait);
      final wide =
          seatMetrics(Room(rows: 5, cols: 8), landscape);

      expect(wide.cell, greaterThan(kCell),
          reason: 'la largeur de case est mesurée, pas codée en dur');
      expect(wide.showsFirstName, isTrue);
      // Le vrai critère, et ce que la première version manquait : on doit
      // gagner des caractères, pas seulement des pixels.
      expect(letters(wide), greaterThan(letters(small) + 3),
          reason: 'au moins trois lettres de plus qu\'en portrait');
    });

    test('une grande fenêtre est OCCUPÉE, pas laissée vide', () {
      // Défaut constaté sur l'app Windows : `BoxFit.scaleDown` ne grandissait
      // jamais, donc la grille restait dans un coin et les prénoms étaient
      // tronqués alors que la place était là.
      final room = Room(rows: 5, cols: 7);
      final m = seatMetrics(room, grandEcran);

      expect(m.scale, greaterThan(1),
          reason: 'la salle doit grandir pour remplir la fenêtre');
      expect(gridWidth(room, cell: m.cell) * m.scale,
          greaterThan(grandEcran.width * 0.9),
          reason: 'au moins 90 % de la largeur employée');
      expect(letters(m), greaterThan(14),
          reason: 'assez de place pour un prénom composé');
    });

    test('la police rendue est bornée et croît moins vite que la case', () {
      for (final m in [
        seatMetrics(Room(rows: 5, cols: 8), portrait),
        seatMetrics(Room(rows: 5, cols: 8), landscape),
        seatMetrics(Room(rows: 5, cols: 7), grandEcran),
      ]) {
        expect(m.nameFontSize * m.scale * m.zoom,
            closeTo(m.renderedNameSize, 0.01),
            reason: 'la police non mise à l\'échelle se déduit de la taille '
                'rendue voulue, et non l\'inverse');
        expect(m.renderedNameSize, inInclusiveRange(kNameSizeMin, kNameSizeMax));
      }

      // Une case bien plus large doit accueillir plus de lettres : c'est ce que
      // garantit une police qui croît moins vite qu'elle.
      final etroit =
          seatMetrics(Room(rows: 5, cols: 8), landscape);
      final large = seatMetrics(Room(rows: 5, cols: 7), grandEcran);

      expect(large.renderedWidth, greaterThan(etroit.renderedWidth));
      expect(letters(large), greaterThan(letters(etroit)));
    });

    test('la largeur de case reste bornée', () {
      // Une seule colonne dans un paysage très large : sans borne, la case
      // deviendrait absurdement allongée.
      final m = seatMetrics(Room(rows: 5, cols: 1), landscape);

      expect(m.cell, lessThanOrEqualTo(kCellWideMax));
    });

    test('une salle très large est réduite, pas débordante', () {
      final room = Room(rows: 5, cols: 15);
      final m = seatMetrics(room, portrait);

      expect(m.scale, lessThan(1));
      expect(gridWidth(room, cell: m.cell) * m.scale,
          lessThanOrEqualTo(portrait.width + 0.01));
      expect(m.showsFirstName, isFalse,
          reason: '15 colonnes sur un téléphone : initiales obligatoires');
    });

    test('la hauteur peut aussi être la contrainte qui mord', () {
      final room = Room(rows: 15, cols: 2);
      final m = seatMetrics(room, portrait);

      expect(m.scale, lessThan(1));
      expect(
          gridHeight(room) * m.scale, lessThanOrEqualTo(portrait.height + 0.01));
    });

    test('un viewport vide ne divise pas par zéro', () {
      final m = seatMetrics(Room(rows: 3, cols: 3), Size.zero);

      expect(m.scale, 1);
      expect(m.cell, kCell);
    });

    test('les couloirs élargissent la grille, donc réduisent les cases', () {
      final sans = Room(rows: 3, cols: 6);
      final avec = Room(rows: 3, cols: 6)..toggleColAisle(2);
      const etroit = Size(300, 651);

      expect(seatMetrics(avec, etroit).renderedWidth,
          lessThan(seatMetrics(sans, etroit).renderedWidth));
    });
  });
}
