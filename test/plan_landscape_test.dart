// Onglet Plan en paysage sur téléphone (issue #8 étape 3, et non-régression de
// l'issue #12 « impossible de voir le plan en paysage »).
//
// Le défaut de #12 n'était pas un plantage : le chrome vertical (app bar +
// onglets + rangée de boutons) ne laissait pas assez de hauteur, et le
// FittedBox réduisait la salle jusqu'à l'invisible. On vérifie donc ici que la
// grille reçoit assez de place pour rester lisible.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';
import 'package:plandeclasse/widgets/plan_viewport.dart';

/// Galaxy A56 en logique : 411 × 891 en portrait, l'inverse en paysage.
const _portrait = Size(411, 891);
const _landscape = Size(891, 411);

/// Fenêtre de bureau : large elle aussi, mais assez haute pour ne rien sacrifier.
const _desktop = Size(1280, 800);

ClassGroup _cls({int rows = 5, int cols = 8, int students = 40}) {
  final cls = ClassGroup(
    id: 'c',
    name: '6ème B',
    room: Room(rows: rows, cols: cols),
    students: [
      for (var i = 0; i < students; i++)
        Student(id: 's$i', firstName: 'Prenom$i', lastName: 'Nom$i'),
    ],
  );
  // Plan déjà généré : on teste l'affichage, pas le moteur.
  var i = 0;
  for (var r = 0; r < rows && i < students; r++) {
    for (var c = 0; c < cols && i < students; c++) {
      cls.assignment[Room.keyOf(r, c)] = 's${i++}';
    }
  }
  return cls;
}

Future<void> _pump(WidgetTester t, ClassGroup cls, Size size) async {
  // `binding.setSurfaceSize` ne change PAS ce que voit MediaQuery (vérifié :
  // la taille restait à 800×600). Il faut régler la vue elle-même, avec un
  // rapport de pixels de 1 pour que la taille physique soit aussi la logique.
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final state = AppState()..classes.add(cls);
  await t.pumpWidget(
      MaterialApp(home: ClassEditorScreen(state: state, cls: cls)));
  await t.pumpAndSettle();

  // On monte sur l'onglet Salle avant de basculer sur Plan : Salle et Élèves
  // (le voisin construit par TabBarView) ne débordent plus depuis #17 — voir
  // test/room_students_overflow_test.dart pour leur propre couverture.
  // Par l'icône et non par le texte : les onglets passent en icônes seules
  // quand leurs libellés ne tiennent plus. Restreint à la barre d'onglets, car
  // Icons.event_seat sert aussi d'avatar au chip « n places » de l'onglet Salle.
  await t.tap(find.descendant(
      of: find.byType(TabBar), matching: find.byIcon(Icons.event_seat)));
  await t.pumpAndSettle();
}

/// Hauteur réellement offerte à la grille.
double _gridHeight(WidgetTester t) =>
    t.getSize(find.byType(PlanViewport)).height;

/// Vrai si Flutter a signalé un débordement de mise en page.
///
/// Les débordements passent par `FlutterError.onError` sans faire échouer le
/// test : sans cette vérification, un « RIGHT OVERFLOWED BY 0.333 PIXELS »
/// resterait invisible en CI.
bool hasOverflow(WidgetTester t) => t
    .takeException()
    .toString()
    .toLowerCase()
    .contains('overflow');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Paysage sur téléphone', () {
    testWidgets('l\'app bar disparaît mais les onglets restent', (t) async {
      await _pump(t, _cls(), _landscape);

      expect(find.byType(AppBar), findsNothing,
          reason: 'les 56dp de l\'app bar sont rendus à la grille');
      expect(find.byType(TabBar), findsOneWidget,
          reason: 'sans les onglets, on ne pourrait plus quitter le Plan');
      expect(find.widgetWithText(Tab, 'Salle'), findsOneWidget);
    });

    testWidgets('les commandes passent dans un rail, plus en rangée', (t) async {
      await _pump(t, _cls(), _landscape);

      // Icônes seules dans le rail : plus de boutons à libellé.
      expect(find.widgetWithText(FilledButton, 'Régénérer'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byIcon(Icons.fact_check), findsOneWidget);
    });

    testWidgets('la grille garde une hauteur utilisable', (t) async {
      await _pump(t, _cls(), _landscape);

      // C'est ce qui manquait dans #12 : sans le chrome récupéré, il ne restait
      // qu'environ 187dp pour une grille qui en demande plus de 400.
      expect(_gridHeight(t), greaterThan(250),
          reason: 'hauteur trop faible : la salle serait réduite à néant');
    });

    testWidgets('les cases sont larges et portent le prénom', (t) async {
      await _pump(t, _cls(), _landscape);

      expect(find.text('Prenom0'), findsOneWidget,
          reason: 'en paysage la case a la place d\'écrire le prénom');
    });

    testWidgets('le rapport devient un badge qui ouvre une feuille', (t) async {
      await _pump(t, _cls(rows: 1, cols: 2, students: 3), _landscape);

      // Génère pour obtenir un rapport (3 élèves pour 2 places : un non placé).
      await t.tap(find.byIcon(Icons.auto_awesome));
      await t.pumpAndSettle();

      expect(find.byKey(kReportButtonKey), findsOneWidget);
      // La carte de rapport ne doit PAS occuper la hauteur en permanence.
      expect(find.text('Non placés :'), findsNothing);

      await t.tap(find.byKey(kReportButtonKey));
      await t.pumpAndSettle();

      expect(find.textContaining('la salle manque de places'), findsOneWidget);
      expect(find.textContaining('Non placés :'), findsOneWidget);
    });
  });

  group('Portrait sur téléphone', () {
    testWidgets('le nom de la classe et le retour sont permanents', (t) async {
      await _pump(t, _cls(), _portrait);

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('6ème B'), findsOneWidget);
      expect(find.byKey(kClassBackKey), findsOneWidget,
          reason: 'le retour vit à gauche des onglets, à toutes les tailles');
    });

    testWidgets('les cases restent carrées et affichent les initiales',
        (t) async {
      await _pump(t, _cls(), _portrait);

      // 8 colonnes sur 411dp : pas la place d'un prénom.
      expect(find.text('Prenom0'), findsNothing);
      expect(find.textContaining('P.Nom0'), findsOneWidget,
          reason: 'initiales désambiguïsées, « PN » étant partagé par tous');
    });
  });

  group('Bureau', () {
    testWidgets('une fenêtre large mais haute garde tout son chrome', (t) async {
      await _pump(t, _cls(), _desktop);

      expect(find.byType(AppBar), findsNothing,
          reason: 'la masquer supprimerait le seul retour, faute de geste '
              'système sur un bureau');
      expect(find.widgetWithText(FilledButton, 'Régénérer'), findsOneWidget);

      // Le chrome est conservé, mais les cases s'élargissent quand même pour
      // occuper la fenêtre : c'est la place disponible qui décide, pas
      // l'orientation.
      expect(find.text('Prenom0'), findsOneWidget);
    });
  });

  group('Dégradation progressive du chrome', () {
    // Signalé sur l'app Windows : « l'application met très longtemps à se dire
    // que la hauteur est rare ». Un seuil unique laissait une fenêtre de 570 dp
    // avec tout son chrome ET la carte de rapport, grille réduite à une
    // vignette. On sacrifie donc le chrome par étapes.

    testWidgets('le rapport n\'est JAMAIS une carte permanente', (t) async {
      // C'était le principal voleur de hauteur : jusqu'à 170 dp.
      await _pump(t, _cls(rows: 2, cols: 3, students: 5), const Size(675, 750));
      await t.tap(find.text('Régénérer'));
      await t.pumpAndSettle();

      expect(find.text('Toutes les règles sont respectées 🎉'), findsNothing);
      expect(find.byKey(kReportButtonKey), findsOneWidget);

      await t.tap(find.byKey(kReportButtonKey));
      await t.pumpAndSettle();
      expect(find.text('Équilibre'), findsOneWidget,
          reason: 'le rapport reste accessible, mais à la demande');
    });

    testWidgets('fenêtre étroite : les libellés cèdent la place aux icônes',
        (t) async {
      // Reproduit le débordement constaté : à cette largeur, les libellés se
      // coupaient en plein mot (« Régé / nérer ») puis débordaient.
      await _pump(t, _cls(rows: 5, cols: 7, students: 35), const Size(324, 980));

      expect(hasOverflow(t), isFalse,
          reason: 'aucun débordement de mise en page');
      expect(find.text('Régénérer'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget,
          reason: 'l\'icône reste, avec son infobulle');
      expect(find.byIcon(Icons.fact_check), findsOneWidget);
    });

    testWidgets('les paliers ne reviennent jamais en arrière', (t) async {
      // Invariant : en rétrécissant, on ne peut que perdre des libellés, jamais
      // en regagner. Les seuils sont mesurés au TextPainter, donc les largeurs
      // exactes dépendent de la police — mais la monotonie, elle, ne doit pas.
      // Hauteur généreuse et fixe pour que seule la largeur varie.
      var seenIconsOnly = false;
      var seenReportIcon = false;

      for (var width = 900.0; width >= 300; width -= 25) {
        await _pump(t, _cls(rows: 5, cols: 7, students: 35),
            Size(width, 900));

        final mainLabelled = find.text('Régénérer').evaluate().isNotEmpty;
        final reportLabelled = find.text('Rapport').evaluate().isNotEmpty;

        if (!reportLabelled) seenReportIcon = true;
        if (!mainLabelled) seenIconsOnly = true;

        expect(reportLabelled && seenReportIcon, isFalse,
            reason: 'le libellé du rapport est revenu à ${width.toInt()} dp');
        expect(mainLabelled && seenIconsOnly, isFalse,
            reason: 'les libellés principaux sont revenus à '
                '${width.toInt()} dp');
        // Le rapport perd son libellé AVANT les commandes principales, étant
        // secondaire : on ne peut donc jamais le voir libellé alors qu'elles ne
        // le sont pas.
        if (reportLabelled) {
          expect(mainLabelled, isTrue,
              reason: 'rapport libellé mais pas les commandes principales, à '
                  '${width.toInt()} dp');
        }
      }

      expect(seenIconsOnly, isTrue,
          reason: 'le balayage doit atteindre le palier « icônes seules »');
    });

    testWidgets('fenêtre confortable : les libellés reviennent', (t) async {
      await _pump(t, _cls(), const Size(700, 980));

      expect(find.widgetWithText(FilledButton, 'Régénérer'), findsOneWidget);
    });

    testWidgets('rapport rouge quand une contrainte DURE est violée', (t) async {
      // Deux places imposées sur la même case : impossible à satisfaire, donc
      // une vraie violation dure. Le rouge est rare par construction — le
      // moteur évite les contraintes dures — d'où ce test.
      final cls = _cls(rows: 2, cols: 2, students: 2);
      cls.assignment.clear();
      cls.rules.addAll([
        Rule(
            id: 'r1',
            type: RuleType.fixedSeat,
            studentAId: 's0',
            seatRow: 0,
            seatCol: 0),
        Rule(
            id: 'r2',
            type: RuleType.fixedSeat,
            studentAId: 's1',
            seatRow: 0,
            seatCol: 0),
      ]);
      await _pump(t, cls, const Size(900, 900));

      await t.tap(find.text('Générer le plan'));
      await t.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget,
          reason: 'une contrainte dure violée doit passer le rapport au rouge');
      expect(find.byIcon(Icons.warning_amber), findsNothing,
          reason: 'le dur prime sur le perfectible');
      expect(find.textContaining('problème(s)'), findsOneWidget);
    });


    testWidgets('en rangée, le rapport est un bouton à libellé', (t) async {
      // Sur un grand écran, une icône nue au bout de la rangée passait
      // inaperçue à côté de deux boutons pleins.
      await _pump(t, _cls(), const Size(1900, 1000));
      await t.tap(find.text('Régénérer'));
      await t.pumpAndSettle();

      // L'état sain doit être franchement VERT : la couleur par défaut donnait
      // une coche grise, indiscernable d'un état neutre.
      final icone = t.widget<Icon>(find.descendant(
          of: find.byKey(kReportButtonKey), matching: find.byType(Icon)));
      expect(icone.icon, Icons.check_circle_outline);
      expect(icone.color, isNotNull, reason: 'le vert doit être explicite');
      expect(find.widgetWithText(OutlinedButton, 'Rapport'), findsOneWidget);
      expect(find.byType(Badge), findsNothing,
          reason: 'le libellé porte déjà le compte, un badge ferait doublon');
    });

    testWidgets('fenêtre haute : rien n\'est sacrifié', (t) async {
      await _pump(t, _cls(), const Size(1280, 800));

      expect(find.byType(AppBar), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Régénérer'), findsOneWidget,
          reason: 'les boutons gardent leur libellé');
    });

    testWidgets('fenêtre moyennement courte : seul le rail est sacrifié',
        (t) async {
      // 480 dp de haut : après passage en rail il reste assez de hauteur, donc
      // l'app bar — et son bouton retour — est conservée.
      await _pump(t, _cls(), const Size(1000, 480));

      expect(find.byType(AppBar), findsNothing,
          reason: 'pas encore besoin de sacrifier le retour');
      expect(find.widgetWithText(FilledButton, 'Régénérer'), findsNothing,
          reason: 'les commandes sont passées en rail');
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('fenêtre très courte : l\'app bar part en dernier', (t) async {
      await _pump(t, _cls(), _landscape);

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('app bar masquée : le retour survit à côté des onglets',
        (t) async {
      // Sans lui, on ne pouvait plus quitter la classe : aucun geste système ne
      // remplace le retour sur un bureau, quelle que soit la forme de la fenêtre.
      await _pump(t, _cls(), _landscape);

      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(kClassBackKey), findsOneWidget,
          reason: 'il doit toujours exister un moyen de sortir de la classe');
    });

    testWidgets('fenêtre étroite et courte : l\'app bar est conservée',
        (t) async {
      // Plus haute que large : un rail n'aurait pas de sens, et masquer l'app
      // bar ferait perdre le retour sans rien gagner d'utile.
      await _pump(t, _cls(), const Size(400, 420));

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('fenêtre portrait courte : les commandes restent EN HAUT',
        (t) async {
      // Défaut signalé sur un format de petite tablette : le rail se déclenchait
      // alors que la fenêtre était plus haute que large. Or en portrait c'est la
      // largeur qui est rare — un rail y vole exactement ce qui manque.
      //
      // 340 et non 282 (la largeur réellement signalée) : sous ~320 dp c'est
      // l'onglet Élèves qui déborde, un défaut préexistant et hors sujet ici.
      // La décision testée est la même dans les deux cas.
      await _pump(t, _cls(), const Size(340, 467));

      final grid = t.getRect(find.byType(PlanViewport));
      final controls = t.getRect(find.byIcon(Icons.auto_awesome));

      expect(controls.center.dy, lessThan(grid.top),
          reason: 'les commandes doivent être au-dessus de la grille');
      expect(find.byType(AppBar), findsNothing);
    });
  });

  group('Aucun débordement, quelle que soit la fenêtre', () {
    // Défaut constaté : sur un écran « raisonnable » en paysage, TOUTES les
    // places débordaient de 7,6 px. Viser une taille de police rendue constante
    // demandait, à petite échelle, une police non mise à l'échelle si grosse
    // que les deux lignes ne tenaient plus dans la hauteur fixe de la case.
    //
    // On balaie donc un éventail de formats plutôt que de vérifier un cas.
    const formats = <Size>[
      Size(587, 266), // le format exact du défaut signalé
      Size(411, 891), // téléphone portrait
      Size(891, 411), // téléphone paysage
      Size(360, 640),
      Size(640, 360),
      Size(500, 300),
      Size(320, 480),
      Size(768, 1024), // tablette portrait
      Size(1024, 768), // tablette paysage
      Size(1280, 800), // bureau
      Size(1920, 1080),
      Size(700, 250), // très plat
      Size(300, 900), // très étroit
    ];

    for (final size in formats) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}', (t) async {
        await _pump(t, _cls(rows: 5, cols: 7, students: 35), size);

        expect(t.takeException(), isNull,
            reason: 'débordement de mise en page en ${size.width.toInt()}×'
                '${size.height.toInt()}');
      });
    }
  });

  group('Zoom', () {
    testWidgets('la grille est enveloppée dans la fenêtre de zoom', (t) async {
      await _pump(t, _cls(), _portrait);

      expect(find.byType(PlanViewport), findsOneWidget);

      // Deux doigts zooment ; le bouton « recentrer » n'existe qu'ensuite,
      // et seulement en paysage (où le rail l'accueille).
      final centre = t.getCenter(find.byType(PlanViewport));
      final f1 = await t.startGesture(centre - const Offset(20, 0), pointer: 1);
      final f2 = await t.startGesture(centre + const Offset(20, 0), pointer: 2);
      await t.pump();
      await f1.moveTo(centre - const Offset(70, 0));
      await f2.moveTo(centre + const Offset(70, 0));
      await t.pump();
      await f1.up();
      await f2.up();
      await t.pumpAndSettle();

      final viewport =
          t.state<PlanViewportState>(find.byType(PlanViewport));
      expect(viewport.isZoomed, isTrue);
    });

    testWidgets('en paysage, « recentrer » apparaît une fois zoomé', (t) async {
      await _pump(t, _cls(), _landscape);

      expect(find.byIcon(Icons.center_focus_strong), findsNothing);

      final centre = t.getCenter(find.byType(PlanViewport));
      final f1 = await t.startGesture(centre - const Offset(20, 0), pointer: 1);
      final f2 = await t.startGesture(centre + const Offset(20, 0), pointer: 2);
      await t.pump();
      await f1.moveTo(centre - const Offset(70, 0));
      await f2.moveTo(centre + const Offset(70, 0));
      await t.pump();
      await f1.up();
      await f2.up();
      await t.pumpAndSettle();

      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);

      await t.tap(find.byIcon(Icons.center_focus_strong));
      await t.pumpAndSettle();

      final viewport =
          t.state<PlanViewportState>(find.byType(PlanViewport));
      expect(viewport.isZoomed, isFalse);
      expect(find.byIcon(Icons.center_focus_strong), findsNothing);
    });
  });

  group('Onglets — libellés jamais coupés', () {
    // Signalé après essai : « le palier pour le passage en icône des onglets
    // arrive un peu tard ». Cause : la marge de respiration ne comptait le
    // padding interne d'un Tab (kTabLabelPadding) que d'un seul côté (16dp) au
    // lieu des deux (32dp) — le seuil se croyait atteint alors que « Élèves »
    // et « Règles », les deux libellés les plus longs, étaient encore coupés
    // net dans leur case.
    double naturalWidth(WidgetTester t, String text) {
      final w = t.widget<Text>(find.text(text));
      final tp = TextPainter(
        text: TextSpan(text: w.data, style: w.style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return tp.width;
    }

    for (var w = 300.0; w <= 900; w += 10) {
      testWidgets('aucun libellé coupé à ${w.toInt()}dp de large', (t) async {
        await _pump(t, _cls(), Size(w, 900));

        for (final label in ['Salle', 'Élèves', 'Règles', 'Plan']) {
          final finder = find.text(label);
          if (finder.evaluate().isEmpty) continue; // mode icônes : rien à vérifier
          final box = t.renderObject(finder) as RenderBox;
          final natural = naturalWidth(t, label);
          expect(box.size.width, greaterThanOrEqualTo(natural - 0.5),
              reason: '« $label » coupé à ${w.toInt()}dp de large '
                  '(rendu ${box.size.width.toStringAsFixed(1)}, '
                  'naturel ${natural.toStringAsFixed(1)})');
        }
      });
    }
  });

  group('Retour et icônes d\'onglets', () {
    testWidgets('le retour porte une infobulle en français', (t) async {
      await _pump(t, _cls(), _landscape);

      final button = t.widget<IconButton>(find.byKey(kClassBackKey));
      expect(button.tooltip, 'Retour',
          reason: 'BackButton hérite « Back » de MaterialLocalizations, '
              'faute de délégué FR configuré pour l\'app');
    });

    testWidgets('en mode icônes, chaque onglet garde son nom en infobulle',
        (t) async {
      // 400dp : sous le seuil (~512dp) qui fait apparaître les libellés.
      await _pump(t, _cls(), const Size(400, 900));

      expect(find.text('Salle'), findsNothing,
          reason: 'ce test suppose le mode icônes, pas le mode libellés');
      for (final label in kClassTabs.map((t) => t.label)) {
        expect(find.byTooltip(label), findsOneWidget,
            reason: '« $label » doit rester accessible via une infobulle');
      }
    });
  });

}
