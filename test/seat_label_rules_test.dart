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

    /// Nombre approximatif de caractères qui tiennent dans une case, à la
    /// taille de police rendue. C'est LA mesure qui compte : la largeur seule
    /// ne dit rien si la police grandit en même temps.
    double letters(SeatMetrics m) {
      final usable = m.renderedWidth - 2 * 3 * m.scale;
      return usable / (0.55 * kSeatNameRenderedSize);
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

    test('portrait, petite salle : prénom d\'emblée, sans réduction', () {
      final m = seatMetrics(Room(rows: 5, cols: 5), portrait);

      expect(m.scale, 1);
      expect(m.renderedWidth, kCell);
      expect(m.showsFirstName, isTrue);
    });

    test('paysage : les cases s\'élargissent pour gagner des LETTRES', () {
      final small = seatMetrics(Room(rows: 5, cols: 8), portrait);
      final wide =
          seatMetrics(Room(rows: 5, cols: 8), landscape, landscape: true);

      expect(wide.cell, greaterThan(kCell),
          reason: 'la largeur de case est mesurée, pas codée en dur');
      expect(wide.showsFirstName, isTrue);
      // Le vrai critère, et ce que la première version manquait : on doit
      // gagner des caractères, pas seulement des pixels.
      expect(letters(wide), greaterThan(letters(small) + 3),
          reason: 'au moins trois lettres de plus qu\'en portrait');
    });

    test('la police rendue reste constante quelle que soit l\'échelle', () {
      final petite = seatMetrics(Room(rows: 3, cols: 3), portrait);
      final grande = seatMetrics(Room(rows: 5, cols: 10), portrait);

      expect(petite.scale, greaterThan(grande.scale));
      // C'est tout l'objet du correctif : la taille RENDUE ne bouge pas, donc
      // une case plus large accueille plus de lettres.
      expect(petite.nameFontSize * petite.scale,
          closeTo(kSeatNameRenderedSize, 0.01));
      expect(grande.nameFontSize * grande.scale,
          closeTo(kSeatNameRenderedSize, 0.01));
    });

    test('la largeur de case reste bornée', () {
      // Une seule colonne dans un paysage très large : sans borne, la case
      // deviendrait absurdement allongée.
      final m = seatMetrics(Room(rows: 5, cols: 1), landscape, landscape: true);

      expect(m.cell, lessThanOrEqualTo(kCellWideMax));
    });

    test('la réduction ne grossit jamais une petite salle', () {
      expect(seatMetrics(Room(rows: 2, cols: 2), portrait).scale, 1);
      expect(
          seatMetrics(Room(rows: 2, cols: 2), landscape, landscape: true).scale,
          1);
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
