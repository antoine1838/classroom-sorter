// Après l'import d'un fichier de classe, l'utilisateur doit savoir si des
// données incohérentes ont été retirées : sans ce message, des places du plan
// ou des règles disparaîtraient sans explication.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plandeclasse/app_state.dart';
import 'package:plandeclasse/l10n/generated/app_localizations.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/rule.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/screens/home_screen.dart';
import 'package:plandeclasse/services/plan_file_service.dart';

ClassGroup _class({required bool dirty}) => ClassGroup(
  id: 'c',
  name: '5ème A',
  room: Room(rows: 1, cols: 3),
  students: [
    Student(id: 'ada', firstName: 'Ada'),
    Student(id: 'lin', firstName: 'Lin'),
  ],
  rules: [
    if (dirty)
      Rule(
        id: 'r',
        type: RuleType.separate,
        studentAId: 'ada',
        studentBId: 'fantôme',
      ),
  ],
  assignment: {'0,0': 'ada', if (dirty) '0,1': 'fantôme', '0,2': 'lin'},
);

Future<AppState> _importFrom(
  WidgetTester tester,
  ClassGroup source, {
  Locale locale = const Locale('fr'),
}) async {
  SharedPreferences.setMockInitialValues({
    'plandeclasse_tutorial_seen_v1': true,
  });
  await tester.binding.setSurfaceSize(const Size(1000, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final state = AppState();
  await tester.runAsync(state.init);
  final service = PlanFileService(
    pickFile: () async =>
        Uint8List.fromList(utf8.encode(PlanFileService().encode(source))),
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(state: state, planFileService: service),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.file_open_outlined));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('un fichier nettoyé le dit, en comptant ce qui a été retiré', (
    tester,
  ) async {
    final state = await _importFrom(tester, _class(dirty: true));

    expect(state.classes, hasLength(1));
    expect(
      find.textContaining(
        'Une nouvelle classe a été créée à partir du fichier.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Pour rester cohérent, l’import a retiré 1 place du plan incohérente, '
        '1 règle qui nommait un élève absent.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('en anglais aussi', (tester) async {
    await _importFrom(tester, _class(dirty: true), locale: const Locale('en'));

    expect(
      find.textContaining(
        'To stay consistent, the import removed 1 inconsistent seat '
        'assignment, 1 rule naming a missing student.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('un fichier sain n\'ajoute rien au message', (tester) async {
    await _importFrom(tester, _class(dirty: false));

    expect(
      find.text('Une nouvelle classe a été créée à partir du fichier.'),
      findsOneWidget,
    );
    expect(find.textContaining('Pour rester cohérent'), findsNothing);
  });
}
