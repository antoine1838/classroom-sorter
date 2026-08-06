// Vérifie la nouvelle interaction de la grille Élèves : une colonne par
// champ, un tap sur la cellule passe à la valeur suivante (boucle).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/class_editor_screen.dart';

Future<void> _pumpEditor(WidgetTester tester, ClassGroup cls) async {
  // Cette suite teste spécifiquement la vue Compacte : on la sélectionne
  // explicitement, indépendamment de la vue par défaut de l'application.
  final state = AppState()..studentsViewMode = StudentsViewMode.compact;
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
      'Grille Élèves : un tap sur une cellule passe à la valeur suivante (boucle)',
      (tester) async {
    final s = Student(id: 's1', firstName: 'Ana', lastName: 'Test');
    final cls = ClassGroup(
      id: 'c1',
      name: 'Test',
      room: Room(rows: 2, cols: 2),
      students: [s],
    );
    await _pumpEditor(tester, cls);

    Future<void> tapField(String label) async {
      await tester.tap(find.byKey(ValueKey('attrCell_${label}_${s.id}')));
      await tester.pumpAndSettle();
    }

    // Niveau : Moyen (défaut) -> Fort -> Faible -> Moyen.
    expect(s.level, Level.moyen);
    await tapField('Niveau');
    expect(s.level, Level.fort);
    await tapField('Niveau');
    expect(s.level, Level.faible);
    await tapField('Niveau');
    expect(s.level, Level.moyen);

    // Genre : Non précisé (défaut) -> Garçon -> Fille -> Non précisé.
    expect(s.gender, Gender.autre);
    await tapField('Genre');
    expect(s.gender, Gender.garcon);
    await tapField('Genre');
    expect(s.gender, Gender.fille);
    await tapField('Genre');
    expect(s.gender, Gender.autre);

    // Énergie : Modéré (défaut) -> Agité -> Calme -> Modéré.
    expect(s.energy, Energy.modere);
    await tapField('Énergie');
    expect(s.energy, Energy.agite);
    await tapField('Énergie');
    expect(s.energy, Energy.calme);
    await tapField('Énergie');
    expect(s.energy, Energy.modere);

    // Taille : Moyen (défaut) -> Grand -> Petit -> Moyen.
    expect(s.size, StudentSize.moyen);
    await tapField('Taille');
    expect(s.size, StudentSize.grand);
    await tapField('Taille');
    expect(s.size, StudentSize.petit);
    await tapField('Taille');
    expect(s.size, StudentSize.moyen);

    // Vue : Bonne vue (défaut) -> Mauvaise vue -> Bonne vue.
    expect(s.poorEyesight, isFalse);
    await tapField('Vue');
    expect(s.poorEyesight, isTrue);
    await tapField('Vue');
    expect(s.poorEyesight, isFalse);
  });
}
