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
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';
import 'package:plandeclasse/widgets/plan_viewport.dart';
import 'package:plandeclasse/widgets/seat_grid.dart';

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
  await t.tap(find.widgetWithText(Tab, 'Plan'));
  await t.pumpAndSettle();
}

/// Hauteur réellement offerte à la grille.
double _gridHeight(WidgetTester t) =>
    t.getSize(find.byType(PlanViewport)).height;

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

      final grid = t.widget<PlanGrid>(find.byType(PlanGrid));
      expect(grid.landscape, isTrue);
      expect(find.text('Prenom0'), findsOneWidget,
          reason: 'en paysage la case a la place d\'écrire le prénom');
    });

    testWidgets('le rapport devient un badge qui ouvre une feuille', (t) async {
      await _pump(t, _cls(rows: 1, cols: 2, students: 3), _landscape);

      // Génère pour obtenir un rapport (3 élèves pour 2 places : un non placé).
      await t.tap(find.byIcon(Icons.auto_awesome));
      await t.pumpAndSettle();

      expect(find.byType(Badge), findsOneWidget);
      // La carte de rapport ne doit PAS occuper la hauteur en permanence.
      expect(find.text('Non placés :'), findsNothing);

      await t.tap(find.byType(Badge));
      await t.pumpAndSettle();

      expect(find.textContaining('la salle manque de places'), findsOneWidget);
      expect(find.textContaining('Non placés :'), findsOneWidget);
    });
  });

  group('Portrait sur téléphone', () {
    testWidgets('l\'app bar et les boutons à libellé sont conservés', (t) async {
      await _pump(t, _cls(), _portrait);

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('6ème B'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Régénérer'), findsOneWidget);
    });

    testWidgets('les cases restent carrées et affichent les initiales',
        (t) async {
      await _pump(t, _cls(), _portrait);

      final grid = t.widget<PlanGrid>(find.byType(PlanGrid));
      expect(grid.landscape, isFalse);
      // 8 colonnes sur 411dp : pas la place d'un prénom.
      expect(find.text('Prenom0'), findsNothing);
      expect(find.textContaining('P.Nom0'), findsOneWidget,
          reason: 'initiales désambiguïsées, « PN » étant partagé par tous');
    });
  });

  group('Bureau', () {
    testWidgets('une fenêtre large mais haute garde tout son chrome', (t) async {
      await _pump(t, _cls(), _desktop);

      expect(find.byType(AppBar), findsOneWidget,
          reason: 'la masquer supprimerait le seul retour, faute de geste '
              'système sur un bureau');
      expect(find.widgetWithText(FilledButton, 'Régénérer'), findsOneWidget);

      final grid = t.widget<PlanGrid>(find.byType(PlanGrid));
      expect(grid.landscape, isFalse,
          reason: 'la hauteur ne manque pas : pas besoin de rectangles');
    });
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
}
