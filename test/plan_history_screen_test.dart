import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/plan_snapshot.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/plan_history_screen.dart';

ClassGroup _classWithSnapshots() {
  final cls = ClassGroup(
    id: 'c',
    name: '6ème B',
    room: Room(rows: 1, cols: 2),
    students: [Student(id: 'lea', firstName: 'Léa')],
    assignment: {'0,0': 'lea'},
  );
  cls.snapshots.addAll([
    PlanSnapshot.fromClassGroup(
      id: 'morning',
      label: 'Matin',
      source: cls,
      createdAt: DateTime(2026, 10, 14, 8),
    ),
    PlanSnapshot.fromClassGroup(
      id: 'afternoon',
      label: 'Après-midi',
      source: cls,
      createdAt: DateTime(2026, 10, 14, 14, 30),
    ),
  ]);
  return cls;
}

Future<AppState> _pump(
  WidgetTester tester,
  ClassGroup cls, {
  SnapshotPdfExporter? exportPdf,
}) async {
  final state = AppState()..classes.add(cls);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PlanHistoryScreen(
        state: state,
        classGroup: cls,
        exportPdf: exportPdf ?? (_, _, _) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('affiche l’heure lorsque plusieurs archives ont la même date', (
    tester,
  ) async {
    await _pump(tester, _classWithSnapshots());

    expect(find.text('Après-midi'), findsOneWidget);
    expect(find.text('Matin'), findsOneWidget);
    expect(find.textContaining('14:30'), findsOneWidget);
    expect(find.textContaining('08:00'), findsOneWidget);
  });

  testWidgets('l’archive est exportée en PDF depuis son menu', (tester) async {
    ClassGroup? exported;
    await _pump(
      tester,
      _classWithSnapshots(),
      exportPdf: (cls, _, _) async => exported = cls,
    );

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exporter en PDF'));
    await tester.pumpAndSettle();

    expect(exported?.name, '6ème B');
    expect(exported?.assignment, {'0,0': 'lea'});
  });

  testWidgets('toucher une archive l’exporte en PDF', (tester) async {
    ClassGroup? exported;
    await _pump(
      tester,
      _classWithSnapshots(),
      exportPdf: (cls, _, _) async => exported = cls,
    );

    await tester.tap(find.text('Matin'));
    await tester.pumpAndSettle();

    expect(exported?.name, '6ème B');
  });

  testWidgets('dit quand l’export PDF de l’archive échoue', (tester) async {
    await _pump(
      tester,
      _classWithSnapshots(),
      exportPdf: (_, _, _) async => throw StateError('partage refusé'),
    );

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exporter en PDF'));
    await tester.pumpAndSettle();

    expect(find.text('L’export a échoué. Réessayez.'), findsOneWidget);
  });

  testWidgets('restaurer crée une copie et supprimer retire une archive', (
    tester,
  ) async {
    final cls = _classWithSnapshots();
    final state = await _pump(tester, cls);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurer comme nouvelle classe'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Restaurer comme nouvelle classe'),
    );
    await tester.pumpAndSettle();

    expect(state.classes, hasLength(2));
    expect(state.classes.last.name, contains('(copie)'));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(cls.snapshots, hasLength(1));
  });

  testWidgets('explique lorsqu’une classe n’a pas encore d’archive', (
    tester,
  ) async {
    await _pump(tester, ClassGroup(id: 'empty', name: 'Vide'));

    expect(find.text('Aucun plan archivé pour cette classe.'), findsOneWidget);
  });
}
