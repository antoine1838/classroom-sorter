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

  group('Seuil d\'affichage du prénom', () {
    // Galaxy A56 en logique : 411 × 891. On retire le padding de l'écran (24)
    // comme le fait l'onglet Plan.
    const portrait = Size(387, 620);
    const landscape = Size(795, 363);

    test('portrait, 8 colonnes : initiales', () {
      final room = Room(rows: 5, cols: 8);
      final w = renderedCellWidth(room, portrait);

      expect(w, closeTo(44, 1.5), reason: 'places d\'environ 44dp');
      expect(showsFirstName(room, portrait), isFalse);
    });

    test('portrait, 8 colonnes, zoom ×1,25 : prénom', () {
      final room = Room(rows: 5, cols: 8);

      expect(showsFirstName(room, portrait, zoom: 1.25), isTrue,
          reason: 'un léger zoom suffit à passer le seuil');
    });

    test('portrait, petite salle de 5 colonnes : prénom d\'emblée', () {
      final room = Room(rows: 5, cols: 5);

      expect(fitScale(room, portrait), 1,
          reason: 'la salle tient sans réduction');
      expect(renderedCellWidth(room, portrait), kCell);
      expect(showsFirstName(room, portrait), isTrue);
    });

    test('paysage, 8 colonnes : prénom', () {
      final room = Room(rows: 5, cols: 8);
      final w = renderedCellWidth(room, landscape, landscape: true);

      expect(w, greaterThan(70), reason: 'cases larges en paysage');
      expect(showsFirstName(room, landscape, landscape: true), isTrue);
    });

    test('la réduction ne grossit jamais une petite salle', () {
      final room = Room(rows: 2, cols: 2);

      expect(fitScale(room, portrait), 1);
      expect(fitScale(room, landscape, landscape: true), 1);
    });

    test('une salle très large est réduite, pas débordante', () {
      final room = Room(rows: 5, cols: 15);
      final scale = fitScale(room, portrait);

      expect(scale, lessThan(1));
      expect(gridWidth(room) * scale, lessThanOrEqualTo(portrait.width + 0.01));
      expect(showsFirstName(room, portrait), isFalse,
          reason: '15 colonnes sur un téléphone : initiales obligatoires');
    });

    test('la hauteur peut aussi être la contrainte qui mord', () {
      // Beaucoup de rangs, peu de colonnes : c'est la hauteur qui limite.
      final room = Room(rows: 15, cols: 2);
      final scale = fitScale(room, portrait);

      expect(scale, lessThan(1));
      expect(gridHeight(room) * scale,
          lessThanOrEqualTo(portrait.height + 0.01));
    });

    test('un viewport vide ne divise pas par zéro', () {
      expect(fitScale(Room(rows: 3, cols: 3), Size.zero), 1);
    });

    test('les couloirs élargissent la grille, donc réduisent les cases', () {
      final sans = Room(rows: 3, cols: 6);
      final avec = Room(rows: 3, cols: 6)..toggleColAisle(2);

      expect(gridWidth(avec), greaterThan(gridWidth(sans)));
      expect(renderedCellWidth(avec, const Size(300, 620)),
          lessThan(renderedCellWidth(sans, const Size(300, 620))));
    });
  });
}
