// Couvre les portes d'entrée des données élèves de l'onglet Élèves (issue #18),
// toutes portées par _StudentsMatrixMixin donc communes aux deux vues :
//   - _StudentFormDialog : création, édition, suppression, annulation ;
//   - _importList : analyse d'une liste collée ;
//   - la colonne des noms : ouverture du formulaire, tri, indicateur de notes.
//
// Une régression ici fait perdre ou corrompre une saisie, d'où la priorité
// donnée à ce bloc dans l'issue. Les tests passent par l'écran complet plutôt
// que par le dialogue isolé : celui-ci est privé, et c'est de toute façon
// l'enchaînement grille -> formulaire -> modèle qui doit être garanti.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';

ClassGroup _cls({List<Student>? students, List<Rule>? rules}) => ClassGroup(
      id: 'c',
      name: '6ème B',
      room: Room(rows: 2, cols: 2),
      students: students ?? [],
      rules: rules,
    );

/// Ouvre l'onglet Élèves. Surface large : la barre Ajouter/Importer affiche
/// alors ses libellés complets (au-dessus du seuil de repli à 420 dp), ce qui
/// permet de cibler les boutons par leur texte.
Future<AppState> _pumpStudents(WidgetTester t, ClassGroup cls) async {
  await t.binding.setSurfaceSize(const Size(1000, 2000));
  addTearDown(() => t.binding.setSurfaceSize(null));

  final state = AppState()..classes.add(cls);
  await t.pumpWidget(MaterialApp(
    home: ClassEditorScreen(state: state, cls: cls),
  ));
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(Tab, 'Élèves'));
  await t.pumpAndSettle();
  return state;
}

/// Choisit [value] dans la liste déroulante de type [T] du formulaire.
///
/// Le libellé cliqué est cherché dans le menu ouvert (`.last`) et non sur le
/// bouton fermé : plusieurs champs partagent des libellés — « Moyen » est à la
/// fois un niveau et une taille — donc viser le texte seul serait ambigu.
Future<void> _pickDropdown<T>(WidgetTester t, String value) async {
  await t.tap(find.byType(DropdownButtonFormField<T>));
  await t.pumpAndSettle();
  await t.tap(find.text(value).last);
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Formulaire élève — création', () {
    testWidgets('« Ajouter » ouvre un formulaire vierge, sans suppression',
        (t) async {
      await _pumpStudents(t, _cls());

      await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
      await t.pumpAndSettle();

      expect(find.text('Nouvel élève'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing,
          reason: 'rien à supprimer sur un élève qui n\'existe pas encore');
    });

    testWidgets('enregistrer crée l\'élève avec tous ses attributs',
        (t) async {
      final cls = _cls();
      await _pumpStudents(t, cls);

      await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
      await t.pumpAndSettle();

      await t.enterText(
          find.widgetWithText(TextField, 'Prénom'), '  Camille  ');
      await t.enterText(find.widgetWithText(TextField, 'Nom'), '  Durand  ');
      await _pickDropdown<Gender>(t, 'Fille');
      await _pickDropdown<Level>(t, 'Fort');
      await _pickDropdown<Energy>(t, 'Agité');
      await _pickDropdown<StudentSize>(t, 'Petit');
      await t.tap(find.text('Mauvaise vue'));
      await t.pumpAndSettle();
      await t.enterText(
          find.widgetWithText(TextField, 'Notes (facultatif)'), ' lunettes ');

      await t.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await t.pumpAndSettle();

      final s = cls.students.single;
      expect(s.firstName, 'Camille', reason: 'espaces retirés');
      expect(s.lastName, 'Durand');
      expect(s.gender, Gender.fille);
      expect(s.level, Level.fort);
      expect(s.energy, Energy.agite);
      expect(s.size, StudentSize.petit);
      expect(s.poorEyesight, isTrue);
      expect(s.notes, 'lunettes');
    });

    testWidgets('annuler n\'ajoute aucun élève', (t) async {
      final cls = _cls();
      await _pumpStudents(t, cls);

      await t.tap(find.widgetWithText(FilledButton, 'Ajouter'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Prénom'), 'Fantôme');
      await t.tap(find.widgetWithText(TextButton, 'Annuler'));
      await t.pumpAndSettle();

      expect(cls.students, isEmpty);
    });
  });

  group('Formulaire élève — édition', () {
    Student existing() => Student(
          id: 's1',
          firstName: 'Ana',
          lastName: 'Test',
          gender: Gender.fille,
          level: Level.faible,
          energy: Energy.calme,
          size: StudentSize.grand,
          poorEyesight: true,
          notes: 'tutorat',
        );

    testWidgets('toucher un nom ouvre le formulaire prérempli', (t) async {
      await _pumpStudents(t, _cls(students: [existing()]));

      await t.tap(find.text('Ana Test'));
      await t.pumpAndSettle();

      expect(find.text('Modifier l\'élève'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Ana'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Test'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'tutorat'), findsOneWidget);
    });

    testWidgets('enregistrer modifie l\'élève en place, sans en créer un autre',
        (t) async {
      final s = existing();
      final cls = _cls(students: [s]);
      await _pumpStudents(t, cls);

      await t.tap(find.text('Ana Test'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Ana'), 'Anna');
      await _pickDropdown<Level>(t, 'Fort');
      await t.tap(find.text('Mauvaise vue'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
      await t.pumpAndSettle();

      expect(cls.students, hasLength(1), reason: 'aucun doublon créé');
      expect(identical(cls.students.single, s), isTrue,
          reason: 'la même instance est mutée, pas remplacée');
      expect(s.firstName, 'Anna');
      expect(s.level, Level.fort);
      expect(s.poorEyesight, isFalse, reason: 'la bascule a été inversée');
      expect(s.lastName, 'Test', reason: 'les champs non touchés survivent');
      expect(s.notes, 'tutorat');
    });

    testWidgets('annuler laisse l\'élève intact', (t) async {
      final s = existing();
      final cls = _cls(students: [s]);
      await _pumpStudents(t, cls);

      await t.tap(find.text('Ana Test'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Ana'), 'Écrasé');
      await t.tap(find.widgetWithText(TextButton, 'Annuler'));
      await t.pumpAndSettle();

      expect(s.firstName, 'Ana');
    });
  });

  group('Formulaire élève — suppression', () {
    /// Libellé [label] de la boîte de confirmation, et non celui du formulaire
    /// resté ouvert derrière elle : les deux portent « Annuler ». Toucher le
    /// texte suffit, il est dans la zone tactile de son bouton.
    Finder confirmButton(String label) => find.descendant(
          of: find.ancestor(
            of: find.text('Supprimer cet élève ?'),
            matching: find.byType(AlertDialog),
          ),
          matching: find.text(label),
        );

    /// Élève placé sur le plan et visé par une règle : la suppression doit
    /// purger les deux (ClassGroup.purgeStudent), sinon le plan garde une
    /// place occupée par un fantôme.
    ClassGroup withPlanAndRule() {
      final s = Student(id: 's1', firstName: 'Ana', lastName: 'Test');
      final other = Student(id: 's2', firstName: 'Bob', lastName: 'Autre');
      final cls = _cls(
        students: [s, other],
        rules: [
          Rule(
              id: 'r',
              type: RuleType.separate,
              studentAId: 's1',
              studentBId: 's2'),
        ],
      );
      cls.assignment[Room.keyOf(0, 0)] = 's1';
      return cls;
    }

    testWidgets('la suppression demande confirmation ; annuler ne fait rien',
        (t) async {
      final cls = withPlanAndRule();
      await _pumpStudents(t, cls);

      await t.tap(find.text('Ana Test'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.delete_outline));
      await t.pumpAndSettle();

      expect(find.text('Supprimer cet élève ?'), findsOneWidget);
      expect(find.textContaining('Ana Test'), findsWidgets);

      await t.tap(confirmButton('Annuler'));
      await t.pumpAndSettle();

      expect(cls.students, hasLength(2));
      expect(cls.rules, hasLength(1));
      expect(cls.assignment, isNotEmpty);
    });

    testWidgets('confirmer retire l\'élève, sa règle et sa place', (t) async {
      final cls = withPlanAndRule();
      await _pumpStudents(t, cls);

      await t.tap(find.text('Ana Test'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.delete_outline));
      await t.pumpAndSettle();
      await t.tap(confirmButton('Supprimer'));
      await t.pumpAndSettle();

      expect(cls.students.map((s) => s.id), ['s2']);
      expect(cls.rules, isEmpty,
          reason: 'la règle visait l\'élève supprimé');
      expect(cls.assignment, isEmpty, reason: 'sa place est libérée');
      expect(find.text('Modifier l\'élève'), findsNothing,
          reason: 'le formulaire se ferme sans enregistrer');
    });
  });

  group('Import d\'une liste', () {
    Future<void> openImport(WidgetTester t) async {
      await t.tap(find.widgetWithText(FilledButton, 'Importer une liste'));
      await t.pumpAndSettle();
    }

    testWidgets('« Prénom Nom » par ligne, lignes vides ignorées', (t) async {
      final cls = _cls();
      await _pumpStudents(t, cls);
      await openImport(t);

      await t.enterText(find.byType(TextField).last,
          'Camille Durand\n\n   \nLéo Martin\n');
      await t.tap(find.widgetWithText(FilledButton, 'Importer'));
      await t.pumpAndSettle();

      expect(cls.students.map((s) => '${s.firstName}|${s.lastName}'),
          ['Camille|Durand', 'Léo|Martin']);
      expect(find.text('2 élève(s) importé(s).'), findsOneWidget);
    });

    testWidgets('nom de famille composé : tout ce qui suit le prénom',
        (t) async {
      final cls = _cls();
      await _pumpStudents(t, cls);
      await openImport(t);

      // Convention annoncée dans le dialogue : le premier mot est le prénom,
      // un prénom composé se relie par un tiret.
      await t.enterText(find.byType(TextField).last,
          'Sami Ben Ali\nPaul-Henri Dupond\nMononyme');
      await t.tap(find.widgetWithText(FilledButton, 'Importer'));
      await t.pumpAndSettle();

      expect(cls.students.map((s) => '${s.firstName}|${s.lastName}'), [
        'Sami|Ben Ali',
        'Paul-Henri|Dupond',
        'Mononyme|',
      ]);
    });

    testWidgets('annuler n\'importe rien et ne notifie pas', (t) async {
      final cls = _cls();
      await _pumpStudents(t, cls);
      await openImport(t);

      await t.enterText(find.byType(TextField).last, 'Camille Durand');
      await t.tap(find.widgetWithText(TextButton, 'Annuler'));
      await t.pumpAndSettle();

      expect(cls.students, isEmpty);
      expect(find.textContaining('importé(s)'), findsNothing);
    });

    testWidgets('un texte vide annonce zéro élève sans rien ajouter',
        (t) async {
      final cls = _cls();
      await _pumpStudents(t, cls);
      await openImport(t);

      await t.tap(find.widgetWithText(FilledButton, 'Importer'));
      await t.pumpAndSettle();

      expect(cls.students, isEmpty);
      expect(find.text('0 élève(s) importé(s).'), findsOneWidget,
          reason: 'le retour reste explicite plutôt que silencieux');
    });
  });

  group('Écran étroit', () {
    /// 260 dp de large, choisis pour franchir deux seuils à la fois :
    ///   - la barre Ajouter/Importer se replie sur des icônes nues
    ///     (`_kToolbarShortLabelMinW` = 290, plus 24 dp de marge intérieure) ;
    ///   - la matrice de la vue Complète ne tient plus : ses 9 colonnes de
    ///     valeurs à leur plancher (21 dp) plus les séparateurs font 193 dp,
    ///     et la colonne des noms ne descend pas sous 98 dp — soit 291 dp
    ///     incompressibles. Le corps devient donc réellement défilable, ce
    ///     qui est la condition pour que `_sync` ait quelque chose à faire.
    Future<AppState> pumpNarrow(WidgetTester t, ClassGroup cls) async {
      await t.binding.setSurfaceSize(const Size(260, 1200));
      addTearDown(() => t.binding.setSurfaceSize(null));

      final state = AppState()..classes.add(cls);
      await t.pumpWidget(MaterialApp(
        home: ClassEditorScreen(state: state, cls: cls),
      ));
      await t.pumpAndSettle();
      // À cette largeur les onglets n'ont plus de libellé : on vise l'icône,
      // qui est là dans les deux modes.
      await t.tap(find.descendant(
        of: find.byType(Tab),
        matching: find.byIcon(Icons.people_alt_outlined),
      ));
      await t.pumpAndSettle();
      return state;
    }

    testWidgets('la barre se replie sur des icônes, libellés en infobulle',
        (t) async {
      await pumpNarrow(t, _cls(students: [
        Student(id: 's1', firstName: 'Ana', lastName: 'Test'),
      ]));

      expect(find.text('Ajouter'), findsNothing);
      expect(find.text('Importer une liste'), findsNothing);
      expect(find.byTooltip('Ajouter un élève'), findsOneWidget);
      expect(find.byTooltip('Importer une liste d\'élèves'), findsOneWidget);
    });

    testWidgets('le défilement horizontal garde l\'en-tête aligné au corps',
        (t) async {
      await pumpNarrow(t, _cls(students: [
        Student(id: 's1', firstName: 'Ana', lastName: 'Test'),
        Student(id: 's2', firstName: 'Bob', lastName: 'Autre'),
      ]));

      // Trois défilements horizontaux dans l'arbre : celui du TabBarView
      // (pagination entre onglets) vient en premier, puis l'en-tête et le
      // corps de la matrice — les deux que _sync doit garder alignés.
      final horizontal = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.right);
      expect(horizontal, findsNWidgets(3));
      final header = horizontal.at(1);
      final body = horizontal.at(2);

      double offsetOf(Finder f) => t.state<ScrollableState>(f).position.pixels;
      expect(offsetOf(header), 0);
      expect(offsetOf(body), 0);

      // On fait glisser le CORPS : l'en-tête doit suivre tout seul.
      await t.drag(body, const Offset(-80, 0));
      await t.pumpAndSettle();

      expect(offsetOf(body), greaterThan(0), reason: 'le corps a bien défilé');
      expect(offsetOf(header), closeTo(offsetOf(body), 0.5),
          reason: 'l\'en-tête est resté aligné sur le corps');

      // Et dans l'autre sens : on tire l'EN-TÊTE, le corps suit. Décalage
      // modeste pour rester dans l'amplitude disponible (~31 dp) plutôt que
      // de retomber à 0, ce qui rendrait la comparaison triviale.
      await t.drag(header, const Offset(15, 0));
      await t.pumpAndSettle();

      expect(offsetOf(body), closeTo(offsetOf(header), 0.5),
          reason: 'la synchronisation joue dans les deux sens');
    });
  });

  group('Colonne des noms', () {
    testWidgets('l\'en-tête bascule le tri par nom', (t) async {
      final cls = _cls(students: [
        Student(id: 's1', firstName: 'Zoé', lastName: 'Zulu'),
        Student(id: 's2', firstName: 'Ana', lastName: 'Alpha'),
      ]);
      await _pumpStudents(t, cls);

      Iterable<String> displayedOrder() => t
          .widgetList<Text>(find.descendant(
              of: find.byType(InkWell), matching: find.byType(Text)))
          .map((w) => w.data ?? '')
          .where((s) => s.contains('Zulu') || s.contains('Alpha'));

      expect(displayedOrder(), ['Zoé Zulu', 'Ana Alpha'],
          reason: 'ordre d\'ajout par défaut');

      await t.tap(find.text('Élève'));
      await t.pumpAndSettle();

      expect(displayedOrder(), ['Ana Alpha', 'Zoé Zulu'],
          reason: 'trié par nom de famille');
      expect(cls.students.first.id, 's1',
          reason: 'le tri est un affichage, il ne réordonne pas le modèle');

      await t.tap(find.text('Élève'));
      await t.pumpAndSettle();
      expect(displayedOrder(), ['Zoé Zulu', 'Ana Alpha']);
    });

    testWidgets('une note affiche son indicateur, pas les élèves sans note',
        (t) async {
      await _pumpStudents(
        t,
        _cls(students: [
          Student(id: 's1', firstName: 'Ana', lastName: 'Test', notes: 'PAI'),
          Student(id: 's2', firstName: 'Bob', lastName: 'Autre'),
        ]),
      );

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
      expect(
          find.byTooltip('PAI'), findsOneWidget,
          reason: 'la note complète est lisible au survol');
    });
  });
}
