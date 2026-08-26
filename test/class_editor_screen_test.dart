// Écran d'édition d'une classe : les quatre onglets, le renommage, les
// objectifs d'équilibre, la création et la suppression de règles, et le cycle
// génération / validation du plan.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';
import 'package:plandeclasse/widgets/seat_grid.dart';

ClassGroup _cls({
  int rows = 3,
  int cols = 3,
  int students = 4,
  List<Rule>? rules,
}) =>
    ClassGroup(
      id: 'c',
      name: '6ème B',
      room: Room(rows: rows, cols: cols),
      students: [
        for (var i = 0; i < students; i++)
          Student(
            id: 'stu$i',
            firstName: 'Prenom$i',
            lastName: 'Nom$i',
          ),
      ],
      rules: rules,
    );

/// Surface haute : l'onglet Règles empile cinq interrupteurs avant la liste des
/// règles, qui sortirait du champ d'un 800×600 — un `ListView` ne construit pas
/// ses enfants invisibles, donc les textes attendus n'existeraient pas.
///
/// Attention : `setSurfaceSize` change les contraintes de MISE EN PAGE mais pas
/// ce que rapporte `MediaQuery` (vérifié : il reste à 800×600). Pour un test qui
/// dépend de l'orientation vue par MediaQuery, il faut régler `tester.view` —
/// voir plan_landscape_test.dart.
Future<AppState> _pump(WidgetTester tester, ClassGroup cls) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final state = AppState()..classes.add(cls);
  await tester.pumpWidget(
      MaterialApp(home: ClassEditorScreen(state: state, cls: cls)));
  await tester.pumpAndSettle();
  return state;
}

/// Bascule sur un onglet. On cible le [Tab] et non le texte : « Règles »
/// apparaît aussi comme titre de section dans l'onglet lui-même.
Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(Tab, label));
  await tester.pumpAndSettle();
}

/// Actionne le « + » ou le « − » du compteur portant ce libellé.
Future<void> _step(WidgetTester tester, String label, IconData icon) async {
  final stepper =
      find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  await tester.tap(find.descendant(of: stepper, matching: find.byIcon(icon)));
  await tester.pumpAndSettle();
}

/// Ouvre la feuille de rapport : le rapport n'est plus une carte permanente,
/// c'est un badge compteur — la carte mangeait jusqu'à 170 dp de hauteur.
Future<void> _openReport(WidgetTester tester) async {
  await tester.tap(find.byKey(kReportButtonKey));
  await tester.pumpAndSettle();
}

/// Choisit [value] dans le menu déroulant portant le libellé [fieldLabel].
Future<void> _pickDropdown(
    WidgetTester tester, String fieldLabel, String value) async {
  await tester.tap(find.byWidgetPredicate((w) =>
      w is DropdownButtonFormField && _labelOf(w) == fieldLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

String? _labelOf(DropdownButtonFormField<Object?> field) {
  final label = field.decoration.labelText;
  return label;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Renommer la classe', () {
    testWidgets('le nouveau nom apparaît dans le titre', (t) async {
      final cls = _cls();
      await _pump(t, cls);
      expect(find.text('6ème B'), findsOneWidget);

      await t.tap(find.byIcon(Icons.edit_outlined));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '5ème A');
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();

      expect(cls.name, '5ème A');
      expect(find.text('5ème A'), findsOneWidget);
    });

    testWidgets('Annuler laisse le nom intact', (t) async {
      final cls = _cls();
      await _pump(t, cls);

      await t.tap(find.byIcon(Icons.edit_outlined));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Ignoré');
      await t.tap(find.text('Annuler'));
      await t.pumpAndSettle();

      expect(cls.name, '6ème B');
    });

    testWidgets('un nom vide est refusé', (t) async {
      final cls = _cls();
      await _pump(t, cls);

      await t.tap(find.byIcon(Icons.edit_outlined));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '   ');
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();

      expect(cls.name, '6ème B');
    });
  });

  testWidgets('le bouton retour quitte l\'éditeur', (t) async {
    final cls = _cls();
    final state = AppState()..classes.add(cls);
    // Deux routes : sans pile, Navigator.maybePop n'aurait rien à dépiler et
    // le test passerait sans rien prouver.
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ClassEditorScreen(state: state, cls: cls),
            )),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('ouvrir'));
    await t.pumpAndSettle();
    expect(find.byKey(kClassBackKey), findsOneWidget);

    await t.tap(find.byKey(kClassBackKey));
    await t.pumpAndSettle();

    expect(find.byKey(kClassBackKey), findsNothing);
    expect(find.text('ouvrir'), findsOneWidget, reason: 'retour à l\'écran précédent');
  });

  group('Onglet Salle', () {
    testWidgets('les compteurs redimensionnent la salle', (t) async {
      final cls = _cls(rows: 3, cols: 3);
      await _pump(t, cls);

      expect(find.text('9 places'), findsOneWidget);

      await _step(t, 'Rangs', Icons.add);
      expect(cls.room.rows, 4);
      expect(find.text('12 places'), findsOneWidget);

      await _step(t, 'Colonnes', Icons.remove);
      expect(cls.room.cols, 2);
      expect(find.text('8 places'), findsOneWidget);

      await _step(t, 'Colonnes', Icons.add);
      expect(cls.room.cols, 3);
      expect(find.text('12 places'), findsOneWidget);
    });

    testWidgets('la taille reste bornée à 1 au minimum', (t) async {
      final cls = _cls(rows: 1, cols: 3);
      await _pump(t, cls);

      await _step(t, 'Rangs', Icons.remove);

      expect(cls.room.rows, 1, reason: 'on ne descend pas sous un rang');
    });

    testWidgets('toucher une place la fait tourner, sans la retirer',
        (t) async {
      final cls = _cls(rows: 1, cols: 1);
      await _pump(t, cls);

      expect(cls.room.facingOf(0, 0), Facing.nord);

      await t.tap(find.byIcon(Icons.event_seat_outlined).first);
      await t.pumpAndSettle();

      expect(cls.room.facingOf(0, 0), Facing.est);
      expect(cls.room.capacity, 1, reason: 'le tap tourne, il ne retire pas');

      // Même repère que sur les cartes du Plan (bord de dossier), affiché en
      // plus de l'icône pivotée — pour rester cohérent entre les deux
      // onglets.
      expect(
          t
              .widgetList<Align>(find.byType(Align))
              .where((a) => a.alignment == Alignment.centerLeft),
          isNotEmpty,
          reason: 'facing est => dossier au bord gauche de la case');
    });

    testWidgets(
        'appui long sur une place la retire ; toucher la case vide la remet',
        (t) async {
      final cls = _cls(rows: 2, cols: 2);
      await _pump(t, cls);

      expect(find.text('4 places'), findsOneWidget);

      await t.longPress(find.byIcon(Icons.event_seat_outlined).first);
      await t.pumpAndSettle();
      expect(cls.room.capacity, 3);
      expect(find.text('3 places'), findsOneWidget);

      // La case désactivée porte désormais l'icône « interdit ».
      await t.tap(find.byIcon(Icons.block).first);
      await t.pumpAndSettle();
      expect(cls.room.capacity, 4);
    });

    testWidgets('clic droit sur une place la retire (équivalent Windows)',
        (t) async {
      final cls = _cls(rows: 1, cols: 1);
      await _pump(t, cls);

      final gesture = await t.startGesture(
        t.getCenter(find.byIcon(Icons.event_seat_outlined).first),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await gesture.up();
      await t.pumpAndSettle();

      expect(cls.room.capacity, 0);
    });

    testWidgets('réduire la salle nettoie le plan et les couloirs', (t) async {
      final cls = _cls(rows: 3, cols: 3)
        ..assignment[Room.keyOf(2, 2)] = 'stu0'
        ..room.toggleColAisle(1);
      await _pump(t, cls);

      // On enlève le dernier rang : la place occupée disparaît avec lui.
      await _step(t, 'Rangs', Icons.remove);

      expect(cls.room.rows, 2);
      expect(cls.assignment.containsKey(Room.keyOf(2, 2)), isFalse);

      // Puis on descend à une seule colonne : le couloir après la colonne 1
      // n'a plus de sens.
      await _step(t, 'Colonnes', Icons.remove);
      await _step(t, 'Colonnes', Icons.remove);

      expect(cls.room.cols, 1);
      expect(cls.room.hasColAisleAfter(1), isFalse);
    });

    testWidgets(
        'toucher l\'espace entre deux rangs ajoute puis retire un couloir',
        (t) async {
      final cls = _cls(rows: 2, cols: 2);
      await _pump(t, cls);

      // Icônes rendues du fond vers le devant : index 0 = (r=1,c=0),
      // index 2 = (r=0,c=0) — même colonne, rangs adjacents. Le couloir entre
      // les deux est celui d'indice 0 (entre les rangs 0 et 1).
      final back = t.getCenter(find.byIcon(Icons.event_seat_outlined).at(0));
      final front = t.getCenter(find.byIcon(Icons.event_seat_outlined).at(2));
      final gap = Offset(back.dx, (back.dy + front.dy) / 2);

      expect(cls.room.hasRowAisleAfter(0), isFalse);

      await t.tapAt(gap);
      await t.pumpAndSettle();
      expect(cls.room.hasRowAisleAfter(0), isTrue);

      await t.tapAt(gap);
      await t.pumpAndSettle();
      expect(cls.room.hasRowAisleAfter(0), isFalse);
    });

    testWidgets(
        'un couloir de colonne actif est une seule grande barre, pas un '
        'trait par rang', (t) async {
      final cls = _cls(rows: 3, cols: 2)..room.toggleColAisle(0);
      await _pump(t, cls);

      // Repérée par la largeur (4) posée sur le Positioned lui-même, pas sur
      // son enfant — seule la grande barre de couloir la déclare ainsi.
      final bars = t
          .widgetList<Positioned>(find.byType(Positioned))
          .where((p) => p.width == 4)
          .toList();
      expect(bars, hasLength(1),
          reason: 'une seule barre continue, pas ${cls.room.rows} segments');
    });

    testWidgets(
        'un couloir de rang actif va d\'un bord à l\'autre des places, comme '
        'un couloir de colonne', (t) async {
      final cls = _cls(rows: 3, cols: 2)..room.toggleRowAisle(0);
      await _pump(t, cls);

      final bar = t.widgetList<Container>(find.byType(Container)).firstWhere(
          (c) => c.constraints?.maxHeight == 4 && c.decoration != null);
      final size = t.getSize(find.byWidgetPredicate((w) => identical(w, bar)));

      // 2 colonnes en mode éditeur : couloirs élargis (kAisle) partout, donc
      // largeur attendue = 2 cases + 1 espace inter-colonnes.
      expect(size.width, closeTo(2 * kCell + kAisle, 0.5),
          reason: 'doit couvrir toute la largeur des places, pas 82% d\'un '
              'total incluant la marge de la grille');
    });

    testWidgets(
        'sans couloir de rang, le repère éditeur est un par colonne, pas un '
        'pour toute la ligne', (t) async {
      final cls = _cls(rows: 2, cols: 3);
      await _pump(t, cls);

      // Le repère (2px de haut, sans décoration) doit apparaître une fois
      // par colonne entre les deux rangs, comme le fait déjà le repère de
      // couloir de colonne une fois par rang.
      final hints = t
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.constraints?.maxHeight == 2 && c.decoration == null)
          .toList();
      expect(hints, hasLength(cls.room.cols),
          reason: 'un repère par colonne (${cls.room.cols}), pas un seul '
              'pour toute la ligne');
    });

    testWidgets('le sélecteur de disposition applique le modèle U choisi',
        (t) async {
      final cls = _cls(rows: 3, cols: 3);
      await _pump(t, cls);

      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('U'));
      await t.pumpAndSettle();
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      // Défauts du modèle U : armDepth = 3, bras simples.
      expect(cls.room.rows, 4);
      expect(cls.room.cols, 5);
      expect(cls.room.facingOf(0, 0), Facing.est, reason: 'bras gauche');
      expect(cls.room.facingOf(0, 4), Facing.ouest, reason: 'bras droit');
      // La rangée du fond (dernier rang) referme le U, face au tableau.
      for (var c = 0; c < cls.room.cols; c++) {
        expect(cls.room.facingOf(3, c), Facing.nord);
      }
    });

    testWidgets(
        'le sélecteur de disposition reste lisible sur un écran de '
        'téléphone étroit (issue #26)',
        (t) async {
      final cls = _cls(rows: 3, cols: 3);
      await _pump(t, cls);

      // Largeur d'un téléphone en portrait : avant le correctif, le
      // SegmentedButton comprimait ses 4 segments dans la largeur du
      // dialogue et « Rangées » s'éclatait lettre par lettre sur 7 lignes.
      await t.binding.setSurfaceSize(const Size(320, 690));
      await t.pumpAndSettle();

      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();

      final size = t.getSize(find.text('Rangées'));
      expect(size.height, lessThan(30),
          reason: 'le mot ne doit pas être éclaté lettre par lettre sur '
              'plusieurs lignes');
    });

    testWidgets(
        'le modèle Rangées conserve la taille ; annuler ne change rien',
        (t) async {
      final cls = _cls(rows: 3, cols: 3)..room.toggle(1, 1);
      await _pump(t, cls);
      expect(cls.room.capacity, 8, reason: 'une place retirée au départ');

      // Annuler : ni la salle ni la place retirée ne bougent.
      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('U'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Annuler'));
      await t.pumpAndSettle();
      expect(cls.room.capacity, 8);

      // Rangées : remet une grille pleine, à la taille courante.
      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('Rangées'));
      await t.pumpAndSettle();
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      expect(cls.room.rows, 3);
      expect(cls.room.cols, 3);
      expect(cls.room.capacity, 9, reason: 'la place retirée est rétablie');
    });

    testWidgets('les paramètres du modèle U changent ses dimensions',
        (t) async {
      final cls = _cls(rows: 3, cols: 3);
      await _pump(t, cls);

      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('U'));
      await t.pumpAndSettle();

      // Défauts : bras de profondeur 3, simples => 4 rangs, 5 colonnes.
      // Aller-retour sur le compteur : les deux sens sont exercés, et la
      // valeur finale (4) reste celle attendue plus bas.
      await _step(t, 'Profondeur des bras', Icons.remove);
      await _step(t, 'Profondeur des bras', Icons.add);
      await _step(t, 'Profondeur des bras', Icons.add);
      await t.tap(find.text('Bras doubles'));
      await t.pumpAndSettle();
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      expect(cls.room.rows, 6,
          reason: 'profondeur 4 + rangée du fond doublée (2 rangs)');
      expect(cls.room.cols, 7, reason: 'bras de 2 colonnes + creux de 3');
      expect(cls.room.facingOf(1, 1), Facing.est,
          reason: 'la 2e colonne appartient au bras gauche');
      for (var c = 0; c < cls.room.cols; c++) {
        expect(cls.room.facingOf(4, c), Facing.nord,
            reason: 'rangée du fond doublée : rang 4');
        expect(cls.room.facingOf(5, c), Facing.nord,
            reason: 'rangée du fond doublée : rang 5');
      }
    });

    testWidgets('les paramètres du modèle Îlots changent ses dimensions',
        (t) async {
      final cls = _cls(rows: 3, cols: 3);
      await _pump(t, cls);

      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('Îlots'));
      await t.pumpAndSettle();

      // Défauts : tables de 4, 3 îlots par rang, 1 rang => 6 colonnes.
      // Aller-retour sur les deux compteurs, valeur finale : 2 îlots, 1 rang.
      await t.tap(find.text('Tables de 6'));
      await t.pumpAndSettle();
      await _step(t, 'Nombre d\'îlots par rang', Icons.add);
      await _step(t, 'Nombre d\'îlots par rang', Icons.remove);
      await _step(t, 'Nombre d\'îlots par rang', Icons.remove);
      await _step(t, 'Nombre de rangs d\'îlots', Icons.add);
      await _step(t, 'Nombre de rangs d\'îlots', Icons.remove);
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      expect(cls.room.cols, 6, reason: '2 îlots de 3 colonnes');
      expect(cls.room.colAisles, {2}, reason: 'un couloir entre les deux îlots');
      expect(cls.room.facingOf(0, 1), Facing.nord,
          reason: 'colonne centrale d\'une table de 6 : face au tableau');
    });

    testWidgets(
        'le sélecteur de disposition applique plusieurs bandes d\'îlots',
        (t) async {
      final cls = _cls(rows: 3, cols: 3);
      await _pump(t, cls);

      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('Îlots'));
      await t.pumpAndSettle();
      await _step(t, 'Nombre de rangs d\'îlots', Icons.add);
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      // Défauts : tables de 4, 3 îlots, 2 bandes (1 + 1 après le tap).
      expect(cls.room.rows, 4);
      expect(cls.room.cols, 6);
      expect(cls.room.rowAisleBetween(1, 2), isTrue,
          reason: 'les deux bandes ne doivent pas être voisines');
    });

    testWidgets(
        'appliquer une disposition sur une salle occupée demande confirmation',
        (t) async {
      final cls = _cls(rows: 2, cols: 2)
        ..assignment[Room.keyOf(0, 0)] = 'stu0';
      await _pump(t, cls);

      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vide'));
      await t.pumpAndSettle();
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      expect(find.text('Remplacer la disposition ?'), findsOneWidget);

      // Annuler : la salle et le plan restent intacts.
      await t.tap(find.text('Annuler'));
      await t.pumpAndSettle();
      expect(cls.room.capacity, 4);
      expect(cls.assignment, isNotEmpty);

      // On refait le même choix, cette fois on confirme le remplacement.
      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vide'));
      await t.pumpAndSettle();
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Remplacer'));
      await t.pumpAndSettle();

      expect(cls.room.capacity, 0);
      expect(cls.assignment, isEmpty);
    });

    testWidgets(
        'appliquer une disposition sur une salle vide ne demande rien',
        (t) async {
      final cls = _cls(rows: 2, cols: 2);
      await _pump(t, cls);

      await t.tap(find.text('Disposition'));
      await t.pumpAndSettle();
      await t.tap(find.text('Vide'));
      await t.pumpAndSettle();
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      expect(find.text('Remplacer la disposition ?'), findsNothing);
      expect(cls.room.capacity, 0);
    });

    testWidgets(
        'le bandeau de capacité apparaît quand la salle manque de places',
        (t) async {
      final cls = _cls(rows: 1, cols: 2, students: 3);
      await _pump(t, cls);

      expect(
          find.textContaining('2 place(s) pour 3 élève(s)'), findsOneWidget);
      expect(find.textContaining('1 élève(s) ne seront pas placé(s)'),
          findsOneWidget);
    });

    testWidgets(
        'le bandeau de capacité disparaît quand la salle suffit', (t) async {
      final cls = _cls(rows: 2, cols: 2, students: 3);
      await _pump(t, cls);

      expect(find.textContaining('ne seront pas placé(s)'), findsNothing);
    });
  });

  group('Objectifs d\'équilibre', () {
    testWidgets('seul « séparer les agités » est actif par défaut', (t) async {
      final cls = _cls();
      await _pump(t, cls);

      expect(cls.balance.separateAgites, isTrue);
      expect(cls.balance.mixGender, isFalse);
      expect(cls.balance.mixLevel, isFalse);
      expect(cls.balance.frontForPoorEyesight, isFalse);
      expect(cls.balance.avoidTallInFrontOfShort, isFalse);
    });

    testWidgets('chaque interrupteur bascule son objectif', (t) async {
      final cls = _cls();
      await _pump(t, cls);
      await _tab(t, 'Règles');

      // On vérifie le BASCULEMENT et non une valeur absolue : « séparer les
      // agités » est actif par défaut, les autres non.
      for (final entry in <String, bool Function()>{
        'Mixer filles / garçons': () => cls.balance.mixGender,
        'Mélanger les niveaux': () => cls.balance.mixLevel,
        'Séparer les élèves agités': () => cls.balance.separateAgites,
        'Rapprocher du tableau': () => cls.balance.frontForPoorEyesight,
        'Éviter qu\'un grand gêne la vue d\'un petit': () =>
            cls.balance.avoidTallInFrontOfShort,
      }.entries) {
        final before = entry.value();
        final tile = find.ancestor(
            of: find.text(entry.key), matching: find.byType(SwitchListTile));

        await t.tap(tile);
        await t.pumpAndSettle();
        expect(entry.value(), !before,
            reason: '« ${entry.key} » n\'a pas basculé');

        // Et le retour en arrière fonctionne.
        await t.tap(tile);
        await t.pumpAndSettle();
        expect(entry.value(), before,
            reason: '« ${entry.key} » ne revient pas en arrière');
      }
    });
  });

  group('Onglet Règles', () {
    testWidgets('sans élève, on ne peut pas créer de règle', (t) async {
      await _pump(t, _cls(students: 0));
      await _tab(t, 'Règles');

      expect(find.text('Ajoutez d\'abord des élèves pour créer des règles.'),
          findsOneWidget);
      final button = t.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Règle'));
      expect(button.onPressed, isNull);
    });

    testWidgets('avec des élèves mais aucune règle, le placement est libre',
        (t) async {
      await _pump(t, _cls());
      await _tab(t, 'Règles');

      expect(find.text('Aucune règle. Le placement sera libre (aléatoire).'),
          findsOneWidget);
    });

    testWidgets('créer une règle « Séparer »', (t) async {
      final cls = _cls();
      await _pump(t, cls);
      await _tab(t, 'Règles');

      await t.tap(find.widgetWithText(FilledButton, 'Règle'));
      await t.pumpAndSettle();
      expect(find.text('Nouvelle règle'), findsOneWidget);

      // Le premier élève est présélectionné ; on le change explicitement pour
      // vérifier que le choix est bien pris en compte, et pas seulement le
      // défaut.
      await _pickDropdown(t, 'Élève', 'Prenom2 Nom2');
      await t.tap(find.text('Ajouter'));
      await t.pumpAndSettle();

      expect(cls.rules, hasLength(1));
      expect(cls.rules.single.type, RuleType.separate);
      expect(cls.rules.single.studentAId, 'stu2');
      expect(find.textContaining('Séparer Prenom2 Nom2 et Prenom1 Nom1'),
          findsOneWidget);
      expect(find.textContaining('Obligatoire'), findsOneWidget);
    });

    testWidgets('deux fois le même élève est refusé', (t) async {
      final cls = _cls();
      await _pump(t, cls);
      await _tab(t, 'Règles');

      await t.tap(find.widgetWithText(FilledButton, 'Règle'));
      await t.pumpAndSettle();

      // Met le second élève sur le même que le premier.
      await _pickDropdown(t, 'Deuxième élève', 'Prenom0 Nom0');
      await t.tap(find.text('Ajouter'));
      await t.pumpAndSettle();

      expect(find.text('Choisissez deux élèves différents.'), findsOneWidget);
      expect(cls.rules, isEmpty);
    });

    testWidgets('créer une règle « Place imposée »', (t) async {
      final cls = _cls(rows: 3, cols: 3);
      await _pump(t, cls);
      await _tab(t, 'Règles');

      await t.tap(find.widgetWithText(FilledButton, 'Règle'));
      await t.pumpAndSettle();
      await _pickDropdown(t, 'Type de règle', 'Place imposée');
      await _pickDropdown(t, 'Rang', 'Rang 2');
      await _pickDropdown(t, 'Colonne', 'Colonne 3');
      await t.tap(find.text('Ajouter'));
      await t.pumpAndSettle();

      expect(cls.rules.single.type, RuleType.fixedSeat);
      expect(cls.rules.single.seatRow, 1);
      expect(cls.rules.single.seatCol, 2);
      expect(find.textContaining('place ligne 2, colonne 3'), findsOneWidget);
    });

    testWidgets('une place désactivée est refusée', (t) async {
      // La place (0,0) est désactivée d'entrée : c'est celle que le formulaire
      // propose par défaut. On ne passe pas par l'onglet Salle pour ça, car la
      // grille s'affiche du fond vers le devant — le premier siège du tableau
      // de widgets est le dernier rang, pas (0,0).
      final cls = _cls(rows: 2, cols: 2);
      cls.room.toggle(0, 0);
      await _pump(t, cls);

      await _tab(t, 'Règles');
      await t.tap(find.widgetWithText(FilledButton, 'Règle'));
      await t.pumpAndSettle();
      await _pickDropdown(t, 'Type de règle', 'Place imposée');
      await t.tap(find.text('Ajouter'));
      await t.pumpAndSettle();

      expect(
          find.text(
              'Cette place est désactivée (allée). Choisissez-en une autre.'),
          findsOneWidget);
      expect(cls.rules, isEmpty);
    });

    testWidgets('créer une règle « Doit être devant » en préférence', (t) async {
      final cls = _cls(rows: 4, cols: 3);
      await _pump(t, cls);
      await _tab(t, 'Règles');

      await t.tap(find.widgetWithText(FilledButton, 'Règle'));
      await t.pumpAndSettle();
      await _pickDropdown(t, 'Type de règle', 'Doit être devant');

      // Deux rangs au lieu d'un. Le passage par 3 puis retour à 2 vérifie au
      // passage que le compteur descend aussi, et qu'il est borné à 1.
      await _step(t, 'Rangs du tableau', Icons.add);
      await _step(t, 'Rangs du tableau', Icons.add);
      await _step(t, 'Rangs du tableau', Icons.remove);
      for (var i = 0; i < 4; i++) {
        await _step(t, 'Rangs du tableau', Icons.remove);
      }
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('1')),
          findsOneWidget,
          reason: 'borné à 1, il ne descend pas à 0');
      await _step(t, 'Rangs du tableau', Icons.add);

      // Et une simple préférence.
      await t.tap(find.text('Obligatoire'));
      await t.pumpAndSettle();

      await t.tap(find.text('Ajouter'));
      await t.pumpAndSettle();

      final rule = cls.rules.single;
      expect(rule.type, RuleType.frontZone);
      expect(rule.frontRows, 2);
      expect(rule.hard, isFalse);
      expect(find.textContaining('à 2 rang(s) du tableau'), findsOneWidget);
      expect(find.textContaining('Préférence'), findsOneWidget);
    });

    testWidgets('Annuler n\'ajoute rien', (t) async {
      final cls = _cls();
      await _pump(t, cls);
      await _tab(t, 'Règles');

      await t.tap(find.widgetWithText(FilledButton, 'Règle'));
      await t.pumpAndSettle();
      await t.tap(find.text('Annuler'));
      await t.pumpAndSettle();

      expect(cls.rules, isEmpty);
    });

    testWidgets('supprimer une règle la retire de la liste', (t) async {
      final cls = _cls(rules: [
        Rule(
            id: 'r',
            type: RuleType.keepTogether,
            studentAId: 'stu0',
            studentBId: 'stu1'),
      ]);
      await _pump(t, cls);
      await _tab(t, 'Règles');

      expect(find.textContaining('Rapprocher Prenom0 Nom0 et Prenom1 Nom1'),
          findsOneWidget);

      await t.tap(find.byIcon(Icons.delete_outline));
      await t.pumpAndSettle();

      expect(cls.rules, isEmpty);
      expect(find.text('Aucune règle. Le placement sera libre (aléatoire).'),
          findsOneWidget);
    });

    testWidgets('une règle sur un élève inconnu s\'affiche sans planter',
        (t) async {
      final cls = _cls(rules: [
        Rule(
            id: 'r',
            type: RuleType.separate,
            studentAId: 'fantome',
            studentBId: 'stu1'),
      ]);
      await _pump(t, cls);
      await _tab(t, 'Règles');

      expect(find.textContaining('Séparer ? et Prenom1 Nom1'), findsOneWidget);
    });
  });

  group('Onglet Plan', () {
    testWidgets('sans élève, on invite à en ajouter', (t) async {
      await _pump(t, _cls(students: 0));
      await _tab(t, 'Plan');

      expect(find.text('Ajoutez des élèves, puis générez le plan.'),
          findsOneWidget);
      final button = t.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Générer le plan'));
      expect(button.onPressed, isNull);
    });

    testWidgets('avant génération, une astuce explique le glisser-déposer',
        (t) async {
      await _pump(t, _cls());
      await _tab(t, 'Plan');

      expect(find.textContaining('Appuyez sur « Générer le plan »'),
          findsOneWidget);
      expect(find.byType(PlanGrid), findsNothing);
    });

    testWidgets('générer remplit le plan et affiche le rapport', (t) async {
      final cls = _cls(rows: 2, cols: 3, students: 4);
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.text('Générer le plan'));
      await t.pumpAndSettle();

      expect(cls.assignment, hasLength(4));
      expect(find.byType(PlanGrid), findsOneWidget);
      // Le bouton change de libellé, et « Valider » apparaît.
      expect(find.text('Régénérer'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);

      await _openReport(t);
      expect(find.text('Toutes les règles sont respectées 🎉'), findsOneWidget);
    });

    testWidgets('valider réévalue le plan sans le régénérer', (t) async {
      final cls = _cls(rows: 2, cols: 3, students: 4);
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.text('Générer le plan'));
      await t.pumpAndSettle();
      final plan = Map<String, String>.from(cls.assignment);

      await t.tap(find.text('Valider'));
      await t.pumpAndSettle();

      expect(cls.assignment, plan, reason: 'valider ne doit rien déplacer');

      await _openReport(t);
      expect(find.text('Toutes les règles sont respectées 🎉'), findsOneWidget);
    });

    testWidgets('les élèves en trop sont signalés', (t) async {
      final cls = _cls(rows: 1, cols: 2, students: 3);
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.text('Générer le plan'));
      await t.pumpAndSettle();

      expect(cls.assignment, hasLength(2));

      await _openReport(t);
      expect(find.textContaining('Non placés :'), findsOneWidget);
      expect(find.textContaining('la salle manque de places'), findsOneWidget);
    });

    testWidgets('une règle dure violée est rapportée', (t) async {
      // Deux places imposées sur la même case : la seconde est impossible.
      final cls = _cls(rows: 2, cols: 2, rules: [
        Rule(
            id: 'r1',
            type: RuleType.fixedSeat,
            studentAId: 'stu0',
            seatRow: 0,
            seatCol: 0),
        Rule(
            id: 'r2',
            type: RuleType.fixedSeat,
            studentAId: 'stu1',
            seatRow: 0,
            seatCol: 0),
      ]);
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.text('Générer le plan'));
      await t.pumpAndSettle();

      await _openReport(t);
      expect(find.textContaining('place imposée déjà occupée'), findsOneWidget);
      expect(find.text('Toutes les règles sont respectées 🎉'), findsNothing);
    });

    testWidgets('le bilan d\'équilibre s\'affiche quand un objectif est actif',
        (t) async {
      final cls = _cls(rows: 2, cols: 3, students: 4);
      cls.balance.separateAgites = true;
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.text('Générer le plan'));
      await t.pumpAndSettle();

      await _openReport(t);
      expect(find.text('Équilibre'), findsOneWidget);
      expect(find.textContaining('Élèves agités'), findsOneWidget);
    });

    testWidgets('glisser un élève sur une autre place échange les deux',
        (t) async {
      final cls = _cls(rows: 1, cols: 2, students: 2)
        ..assignment[Room.keyOf(0, 0)] = 'stu0'
        ..assignment[Room.keyOf(0, 1)] = 'stu1';
      await _pump(t, cls);
      await _tab(t, 'Plan');

      // Les cases ont ici largement la place : elles affichent le prénom.
      final from = t.getCenter(find.text('Prenom0'));
      final to = t.getCenter(find.text('Prenom1'));
      await t.dragFrom(from, to - from);
      await t.pumpAndSettle();

      expect(cls.assignment[Room.keyOf(0, 0)], 'stu1');
      expect(cls.assignment[Room.keyOf(0, 1)], 'stu0');
    });

    testWidgets('glisser un élève sur une place vide le déplace', (t) async {
      final cls = _cls(rows: 1, cols: 2, students: 1)
        ..assignment[Room.keyOf(0, 0)] = 'stu0';
      await _pump(t, cls);
      await _tab(t, 'Plan');

      final occupied = t.getCenter(find.text('Prenom0'));
      final empty = t.getCenter(find.byIcon(Icons.event_seat_outlined));
      await t.dragFrom(occupied, empty - occupied);
      await t.pumpAndSettle();

      expect(cls.assignment.containsKey(Room.keyOf(0, 0)), isFalse);
      expect(cls.assignment[Room.keyOf(0, 1)], 'stu0');
    });
  });

  group('Feuille de détail au tap (étape 4)', () {
    testWidgets(
        'tous les attributs apparaissent en clair, même ceux muets sur la case',
        (t) async {
      final cls = _cls(rows: 1, cols: 1, students: 1);
      cls.assignment[Room.keyOf(0, 0)] = 'stu0';
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.byKey(const ValueKey('seat_stu0')));
      await t.pumpAndSettle();

      expect(find.text('Prenom0 Nom0'), findsOneWidget);
      // Genre/Niveau/Énergie/Taille par défaut sont tous « muets » sur la
      // case (aucune icône de coin) : la feuille doit les nommer quand même.
      expect(find.text('Non précisé'), findsOneWidget);
      expect(find.text('Niveau : Moyen'), findsOneWidget);
      expect(find.text('Énergie : Modéré'), findsOneWidget);
      expect(find.text('Taille : Moyen'), findsOneWidget);
      expect(find.text('Bonne vue'), findsOneWidget);
      expect(find.text('Modifier l\'élève'), findsOneWidget);
      expect(find.text('À signaler'), findsNothing);
    });

    testWidgets('un problème marqué sur l\'élève apparaît dans « À signaler »',
        (t) async {
      // Deux places seulement : une règle « séparer » dure entre les deux
      // seuls élèves est nécessairement violée, aucune autre affectation
      // n'étant possible.
      final cls = _cls(rows: 1, cols: 2, students: 2, rules: [
        Rule(
          id: 'r',
          type: RuleType.separate,
          studentAId: 'stu0',
          studentBId: 'stu1',
          hard: true,
        ),
      ]);
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.text('Générer le plan'));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('seat_stu0')));
      await t.pumpAndSettle();

      expect(find.text('À signaler'), findsOneWidget);
      expect(find.textContaining('sont voisins (à séparer)'), findsOneWidget);
    });

    testWidgets(
        '« Modifier l\'élève » ouvre le formulaire existant et applique les changements',
        (t) async {
      final cls = _cls(rows: 1, cols: 1, students: 1);
      cls.assignment[Room.keyOf(0, 0)] = 'stu0';
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.byKey(const ValueKey('seat_stu0')));
      await t.pumpAndSettle();
      await t.tap(find.text('Modifier l\'élève'));
      await t.pumpAndSettle();

      // Le formulaire édite bien l'élève EXISTANT (titre + bouton supprimer),
      // pas un nouvel élève : sans onDelete, _StudentFormDialog l'aurait cru.
      expect(find.text('Modifier l\'élève'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await t.enterText(find.widgetWithText(TextField, 'Prénom'), 'Changé');
      await t.tap(find.text('Enregistrer'));
      await t.pumpAndSettle();

      expect(cls.students.first.firstName, 'Changé');
      // Rouvre la feuille pour vérifier que le changement est bien reflété.
      await t.tap(find.byKey(const ValueKey('seat_stu0')));
      await t.pumpAndSettle();
      expect(find.text('Changé Nom0'), findsOneWidget);
    });

    testWidgets('la note libre de l\'élève apparaît dans la feuille',
        (t) async {
      final cls = _cls(rows: 1, cols: 1, students: 1);
      cls.students.first.notes = 'PAI, lunettes';
      cls.assignment[Room.keyOf(0, 0)] = 'stu0';
      await _pump(t, cls);
      await _tab(t, 'Plan');

      await t.tap(find.byKey(const ValueKey('seat_stu0')));
      await t.pumpAndSettle();

      expect(find.text('PAI, lunettes'), findsOneWidget);
    });

    testWidgets(
        'supprimer depuis la feuille retire l\'élève, sa place et le rapport',
        (t) async {
      final cls = _cls(rows: 1, cols: 2, students: 2, rules: [
        Rule(
            id: 'r',
            type: RuleType.separate,
            studentAId: 'stu0',
            studentBId: 'stu1'),
      ]);
      await _pump(t, cls);
      await _tab(t, 'Plan');

      // Un plan généré d'abord : la suppression doit aussi invalider le
      // rapport affiché, pas seulement le modèle.
      await t.tap(find.text('Générer le plan'));
      await t.pumpAndSettle();
      expect(cls.assignment, hasLength(2));

      await t.tap(find.byKey(const ValueKey('seat_stu0')));
      await t.pumpAndSettle();
      await t.tap(find.text('Modifier l\'élève'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.delete_outline));
      await t.pumpAndSettle();

      // « Supprimer » du dialogue de confirmation, pas l'infobulle de l'icône
      // du formulaire resté ouvert derrière.
      await t.tap(find.descendant(
        of: find.ancestor(
          of: find.text('Supprimer cet élève ?'),
          matching: find.byType(AlertDialog),
        ),
        matching: find.text('Supprimer'),
      ));
      await t.pumpAndSettle();

      expect(cls.students.map((s) => s.id), ['stu1']);
      expect(cls.rules, isEmpty, reason: 'la règle visait l\'élève supprimé');
      expect(cls.assignment.values, isNot(contains('stu0')),
          reason: 'sa place est libérée');
    });
  });
}
