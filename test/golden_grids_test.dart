// Tests golden des grilles du plan et de l'éditeur de salle : ils repèrent une
// régression visuelle (placement, marquage des problèmes, couloirs, dossiers)
// que les tests de widgets ciblés ne voient pas.
//
// Le texte utilise la police de test (Ahem) : les images ne dépendent donc pas
// des polices installées. Les images sont comparées avec une tolérance de 0,5 %
// de pixels, pour absorber le lissage propre à chaque plateforme (références
// produites sous Windows, comparées sous Linux par la CI).
//
// Après un changement visuel voulu, régénérer les références puis relire les
// images avant de les commiter :
//   flutter test --update-goldens test/golden_grids_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plandeclasse/engine/plan_issue.dart';
import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room_layouts.dart';
import 'package:plandeclasse/widgets/seat_grid.dart';

/// Part maximale de pixels différents tolérée entre l'image et sa référence.
const _tolerance = 0.005;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= _tolerance) {
      debugPrint(
        'Golden ${golden.pathSegments.last} : '
        '${(result.diffPercent * 100).toStringAsFixed(3)} % de pixels '
        'différents, sous la tolérance.',
      );
      return true;
    }
    throw FlutterError(await generateFailureOutput(result, golden, basedir));
  }
}

ClassGroup _demoClass() => ClassGroup.fromJson(
  jsonDecode(File('test/fixtures/demo_class_6emeb.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Un problème dur et un souple sur deux élèves de la classe de démo.
PlanResult _resultWithIssues(ClassGroup cls) => PlanResult(
  assignment: cls.assignment,
  unplacedStudentIds: const [],
  issues: const [
    PlanIssue(
      severity: IssueSeverity.hard,
      kind: PlanIssueKind.studentNotNearBoard,
      studentIds: ['s01'],
    ),
    PlanIssue(
      severity: IssueSeverity.soft,
      kind: PlanIssueKind.unplacedStudents,
      studentIds: ['s02', 's03'],
    ),
  ],
  balance: const [],
  score: 0,
);

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  required Size size,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(8), child: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    final comparator = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantComparator(
      comparator.basedir.resolve('golden_grids_test.dart'),
    );
  });

  testWidgets('plan en portrait : classe de démo au complet', (tester) async {
    final cls = _demoClass();
    await _pump(
      tester,
      PlanGrid(cls: cls, onSwap: (_, _) {}),
      size: const Size(360, 640),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/plan_portrait.png'),
    );
  });

  testWidgets('plan en paysage : cases plus larges', (tester) async {
    final cls = _demoClass();
    await _pump(
      tester,
      PlanGrid(cls: cls, onSwap: (_, _) {}),
      size: const Size(800, 360),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/plan_paysage.png'),
    );
  });

  testWidgets('plan avec problèmes marqués sur les places', (tester) async {
    final cls = _demoClass();
    await _pump(
      tester,
      PlanGrid(cls: cls, onSwap: (_, _) {}, result: _resultWithIssues(cls)),
      size: const Size(360, 640),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/plan_problemes.png'),
    );
  });

  testWidgets('plan avec problèmes en thème sombre', (tester) async {
    final cls = _demoClass();
    await _pump(
      tester,
      PlanGrid(cls: cls, onSwap: (_, _) {}, result: _resultWithIssues(cls)),
      size: const Size(360, 640),
      theme: ThemeData(brightness: Brightness.dark),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/plan_problemes_sombre.png'),
    );
  });

  testWidgets('éditeur de salle : U, couloirs et dossiers orientés', (
    tester,
  ) async {
    final room = buildULayout();
    // Est, sud et ouest sur trois places du bras gauche du U.
    for (final (row, col, turns) in [(0, 0, 1), (1, 0, 2), (2, 0, 3)]) {
      for (var turn = 0; turn < turns; turn++) {
        room.rotateFacing(row, col);
      }
    }
    room.toggleRowAisle(0);
    await _pump(
      tester,
      RoomEditorGrid(room: room, onChanged: () {}),
      size: const Size(360, 640),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/salle_u.png'),
    );
  });
}
