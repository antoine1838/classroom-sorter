// Écran d'accueil : liste des classes, création, suppression, accès aux
// réglages et à la classe de démo.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';
import 'package:plandeclasse/screens/home_screen.dart';
import 'package:plandeclasse/screens/settings_screen.dart';

ClassGroup _cls(String name, {int students = 2, int rows = 2, int cols = 3}) =>
    ClassGroup(
      id: name,
      name: name,
      room: Room(rows: rows, cols: cols),
      students: [
        for (var i = 0; i < students; i++) Student(id: '$name$i'),
      ],
    );

/// Laisse tourner la boucle asynchrone réelle jusqu'à ce que [done] soit vrai.
///
/// La classe de démo est lue depuis un asset : c'est une vraie E/S, que
/// `pumpAndSettle` n'attend pas (il ne traite que frames et minuteurs de
/// l'horloge factice). Une attente de durée fixe marcherait une fois sur deux —
/// on attend donc la condition elle-même.
Future<void> _settleUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Monte l'accueil. [initialised] à false laisse l'état en cours de chargement.
Future<AppState> _pump(WidgetTester tester,
    {List<ClassGroup> classes = const [], bool initialised = true}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final state = AppState();
  if (initialised) await state.init();
  state.classes.addAll(classes);

  await tester.pumpWidget(MaterialApp(home: HomeScreen(state: state)));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // rootBundle met en cache le Future de chargement d'un asset. Ce Future est
    // créé dans la zone d'horloge factice du test qui l'a demandé le premier ;
    // un test suivant qui l'attend verrait sa continuation planifiée dans cette
    // zone morte, jamais repompée — et la classe de démo ne se chargerait
    // jamais. On repart donc d'un cache vide à chaque test.
    rootBundle.clear();
  });

  testWidgets('pendant le chargement, un indicateur tourne', (t) async {
    await t.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final state = AppState();
    await t.pumpWidget(MaterialApp(home: HomeScreen(state: state)));
    await t.pump();

    expect(state.loading, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('Aucune classe', () {
    testWidgets('l\'état vide explique quoi faire', (t) async {
      await _pump(t);

      expect(find.text('Aucune classe pour le moment'), findsOneWidget);
      expect(find.text('Créer ma première classe'), findsOneWidget);
      expect(find.text('Classe de démo'), findsOneWidget);
    });

    testWidgets('« Créer ma première classe » ouvre la saisie du nom',
        (t) async {
      final state = await _pump(t);

      await t.tap(find.text('Créer ma première classe'));
      await t.pumpAndSettle();

      expect(find.text('Nom de la classe'), findsOneWidget);
      await t.enterText(find.byType(TextField), '5ème A');
      await t.tap(find.text('Créer'));
      await t.pumpAndSettle();

      // Le sélecteur de disposition s'enchaîne aussitôt (issue #28) ;
      // Annuler garde la salle par défaut avant d'ouvrir l'éditeur.
      expect(find.text('Disposition de la salle'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Annuler'));
      await t.pumpAndSettle();

      expect(state.classes.map((c) => c.name), ['5ème A']);
      expect(find.byType(ClassEditorScreen), findsOneWidget,
          reason: 'on enchaîne directement sur l\'édition de la classe');
    });

    testWidgets('la classe de démo est ajoutée et ouverte', (t) async {
      final state = await _pump(t);

      await t.tap(find.text('Classe de démo'));
      await _settleUntil(t, () => state.classes.isNotEmpty);

      expect(state.classes, hasLength(1));
      expect(state.classes.single.students, isNotEmpty,
          reason: 'la démo arrive déjà remplie');
      expect(find.byType(ClassEditorScreen), findsOneWidget);
    });
  });

  group('Création depuis le bouton flottant', () {
    testWidgets('valider avec la touche Entrée crée la classe', (t) async {
      final state = await _pump(t, classes: [_cls('6ème B')]);

      await t.tap(find.widgetWithText(FloatingActionButton, 'Nouvelle classe'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), '  5ème A  ');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();

      expect(state.classes.map((c) => c.name), ['6ème B', '5ème A'],
          reason: 'le nom doit être rogné');
    });

    testWidgets('Annuler ne crée rien', (t) async {
      final state = await _pump(t);

      await t.tap(find.widgetWithText(FloatingActionButton, 'Nouvelle classe'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Ignorée');
      await t.tap(find.text('Annuler'));
      await t.pumpAndSettle();

      expect(state.classes, isEmpty);
    });

    testWidgets('un nom vide crée quand même une classe nommée par défaut',
        (t) async {
      final state = await _pump(t);

      await t.tap(find.widgetWithText(FloatingActionButton, 'Nouvelle classe'));
      await t.pumpAndSettle();
      await t.tap(find.text('Créer'));
      await t.pumpAndSettle();

      expect(state.classes.single.name, 'Nouvelle classe');
    });
  });

  group('Disposition proposée à la création (#28)', () {
    Future<AppState> createUpTo(WidgetTester t) async {
      final state = await _pump(t);
      await t.tap(find.widgetWithText(FloatingActionButton, 'Nouvelle classe'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '5ème A');
      await t.tap(find.text('Créer'));
      await t.pumpAndSettle();
      return state;
    }

    testWidgets('Annuler garde la salle par défaut (5 × 7)', (t) async {
      final state = await createUpTo(t);

      await t.tap(find.widgetWithText(TextButton, 'Annuler'));
      await t.pumpAndSettle();

      final cls = state.classes.single;
      expect(cls.room.rows, 5);
      expect(cls.room.cols, 7);
      expect(cls.savedRoomId, isNull);
      expect(find.byType(ClassEditorScreen), findsOneWidget);
    });

    testWidgets('choisir un modèle applique sa géométrie à la classe créée',
        (t) async {
      final state = await createUpTo(t);

      await t.tap(find.text('U'));
      await t.pumpAndSettle();
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      // Défauts du modèle U : armDepth = 3, bras simples => 4 rangs, 5 colonnes.
      final cls = state.classes.single;
      expect(cls.room.rows, 4);
      expect(cls.room.cols, 5);
      expect(find.byType(ClassEditorScreen), findsOneWidget);
    });

    testWidgets('Mes salles est proposée dès la création', (t) async {
      final state = await _pump(t);
      final saved = state.addSavedRoom('B204', Room(rows: 4, cols: 6));

      await t.tap(find.widgetWithText(FloatingActionButton, 'Nouvelle classe'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '5ème A');
      await t.tap(find.text('Créer'));
      await t.pumpAndSettle();

      await t.tap(find.text('Mes salles'));
      await t.pumpAndSettle();
      await t.tap(find.text('B204'));
      await t.pumpAndSettle();
      await t.tap(find.text('Appliquer'));
      await t.pumpAndSettle();

      final cls = state.classes.single;
      expect(cls.room.rows, 4);
      expect(cls.room.cols, 6);
      expect(cls.savedRoomId, saved.id);
    });
  });

  group('Liste des classes', () {
    testWidgets('chaque carte résume la classe', (t) async {
      await _pump(t, classes: [_cls('6ème B', students: 3, rows: 2, cols: 4)]);

      expect(find.text('6ème B'), findsOneWidget);
      expect(find.text('3 élève(s) · 8 place(s)'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'la pastille du effectif');
    });

    testWidgets('une classe sans nom s\'affiche « Classe »', (t) async {
      await _pump(t, classes: [_cls('')]);

      expect(find.text('Classe'), findsOneWidget);
    });

    testWidgets('toucher une carte ouvre l\'édition', (t) async {
      await _pump(t, classes: [_cls('6ème B')]);

      await t.tap(find.text('6ème B'));
      await t.pumpAndSettle();

      expect(find.byType(ClassEditorScreen), findsOneWidget);
    });

    testWidgets('plusieurs classes sont listées dans l\'ordre', (t) async {
      await _pump(t, classes: [_cls('6ème B'), _cls('5ème A')]);

      expect(find.byType(Card), findsNWidgets(2));
      expect(find.text('6ème B'), findsOneWidget);
      expect(find.text('5ème A'), findsOneWidget);
    });
  });

  group('Suppression', () {
    testWidgets('confirmer supprime la classe', (t) async {
      final state = await _pump(t, classes: [_cls('6ème B'), _cls('5ème A')]);

      await t.tap(find.byIcon(Icons.delete_outline).first);
      await t.pumpAndSettle();

      expect(find.text('Supprimer la classe ?'), findsOneWidget);
      expect(find.textContaining('« 6ème B » sera définitivement supprimée'),
          findsOneWidget);

      await t.tap(find.text('Supprimer'));
      await t.pumpAndSettle();

      expect(state.classes.map((c) => c.name), ['5ème A']);
    });

    testWidgets('Annuler garde la classe', (t) async {
      final state = await _pump(t, classes: [_cls('6ème B')]);

      await t.tap(find.byIcon(Icons.delete_outline));
      await t.pumpAndSettle();
      await t.tap(find.text('Annuler'));
      await t.pumpAndSettle();

      expect(state.classes, hasLength(1));
    });
  });

  group('Barre d\'actions', () {
    testWidgets('l\'engrenage mène aux réglages', (t) async {
      await _pump(t);

      await t.tap(find.byIcon(Icons.settings_outlined));
      await t.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget);
    });

    testWidgets('le raccourci démo fonctionne aussi depuis la barre',
        (t) async {
      // La classe de démo s'appelle elle aussi « 6ème B » : on part d'un autre
      // nom pour que l'assertion reste lisible.
      final state = await _pump(t, classes: [_cls('5ème A')]);

      await t.tap(find.byIcon(Icons.auto_awesome_outlined));
      await _settleUntil(t, () => state.classes.length > 1);

      expect(state.classes.map((c) => c.name), ['5ème A', '6ème B']);
      expect(find.byType(ClassEditorScreen), findsOneWidget);
    });
  });
}
