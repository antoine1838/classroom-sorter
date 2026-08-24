// Vérifie l'interaction de la vue Élèves « Complète » : une colonne par
// valeur possible, à cocher. Cocher une valeur en décoche l'ancienne ;
// recocher la valeur active revient à la valeur par défaut du champ (pas de
// Level.nonDefini/Energy.nonDefini distinct : le milieu fait office de
// défaut, voir students_grid_cycle_test.dart pour la vue Compacte).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';

Future<void> _pumpEditor(WidgetTester tester, ClassGroup cls) async {
  final state = AppState()..studentsViewMode = StudentsViewMode.complete;
  await tester.pumpWidget(MaterialApp(
    home: ClassEditorScreen(state: state, cls: cls),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Élèves'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Vue Complète : cocher une valeur, recocher revient à la valeur par défaut',
      (tester) async {
    final s = Student(id: 's1', firstName: 'Ana', lastName: 'Test');
    final cls = ClassGroup(
      id: 'c1',
      name: 'Test',
      room: Room(rows: 2, cols: 2),
      students: [s],
    );
    await _pumpEditor(tester, cls);

    Future<void> tapValue(String field, String value) async {
      await tester
          .tap(find.byKey(ValueKey('completeCell_${field}_${value}_${s.id}')));
      await tester.pumpAndSettle();
    }

    // Niveau : Moyen (défaut) -> Fort -> Moyen -> Faible -> Moyen.
    expect(s.level, Level.moyen);
    await tapValue('Niveau', 'Fort');
    expect(s.level, Level.fort);
    await tapValue('Niveau', 'Fort');
    expect(s.level, Level.moyen);
    await tapValue('Niveau', 'Faible');
    expect(s.level, Level.faible);
    await tapValue('Niveau', 'Faible');
    expect(s.level, Level.moyen);

    // Genre : Non précisé (défaut) -> Garçon -> Non précisé -> Fille -> Non précisé.
    expect(s.gender, Gender.autre);
    await tapValue('Genre', 'Garçon');
    expect(s.gender, Gender.garcon);
    await tapValue('Genre', 'Garçon');
    expect(s.gender, Gender.autre);
    await tapValue('Genre', 'Fille');
    expect(s.gender, Gender.fille);
    await tapValue('Genre', 'Fille');
    expect(s.gender, Gender.autre);

    // Énergie : Modéré (défaut) -> Agité -> Modéré -> Calme -> Modéré.
    expect(s.energy, Energy.modere);
    await tapValue('Énergie', 'Agité');
    expect(s.energy, Energy.agite);
    await tapValue('Énergie', 'Agité');
    expect(s.energy, Energy.modere);
    await tapValue('Énergie', 'Calme');
    expect(s.energy, Energy.calme);
    await tapValue('Énergie', 'Calme');
    expect(s.energy, Energy.modere);

    // Taille : Moyen (défaut) -> Grand -> Moyen -> Petit -> Moyen.
    expect(s.size, StudentSize.moyen);
    await tapValue('Taille', 'Grand');
    expect(s.size, StudentSize.grand);
    await tapValue('Taille', 'Grand');
    expect(s.size, StudentSize.moyen);
    await tapValue('Taille', 'Petit');
    expect(s.size, StudentSize.petit);
    await tapValue('Taille', 'Petit');
    expect(s.size, StudentSize.moyen);

    // Vue : Bonne vue (défaut) -> Mauvaise vue -> Bonne vue.
    expect(s.poorEyesight, isFalse);
    await tapValue(
        'Vue', 'Mauvaise vue (objectif : rapprocher du tableau)');
    expect(s.poorEyesight, isTrue);
    await tapValue(
        'Vue', 'Mauvaise vue (objectif : rapprocher du tableau)');
    expect(s.poorEyesight, isFalse);
  });

  testWidgets(
      'la bascule de l\'onglet change de vue dans les deux sens, sans passer '
      'par les Réglages', (tester) async {
    final cls = ClassGroup(
      id: 'c1',
      name: 'Test',
      room: Room(rows: 2, cols: 2),
      students: [Student(id: 's1', firstName: 'Ana', lastName: 'Test')],
    );
    // L'état est gardé ici, contrairement à _pumpEditor : c'est lui que la
    // bascule doit modifier (le mode de vue est global, pas local à l'onglet).
    final state = AppState()..studentsViewMode = StudentsViewMode.complete;
    await tester.pumpWidget(MaterialApp(
      home: ClassEditorScreen(state: state, cls: cls),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Élèves'));
    await tester.pumpAndSettle();

    // Depuis la vue Complète, la bascule propose la Compacte — et l'inverse.
    await tester.tap(find.byTooltip('Passer à la vue compacte'));
    await tester.pumpAndSettle();
    expect(state.studentsViewMode, StudentsViewMode.compact);

    await tester.tap(find.byTooltip('Passer à la vue complète'));
    await tester.pumpAndSettle();
    expect(state.studentsViewMode, StudentsViewMode.complete);
  });
}
