import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plandeclasse/models/classroom.dart';

import '../tool/seating_engine_benchmark_lib.dart';

SeatingEngineBenchmarkReport _report({required int p95Us}) =>
    SeatingEngineBenchmarkReport(
      fixturePath: benchmarkFixturePath,
      generate: BenchmarkStats(
        minUs: 100,
        medianUs: 120,
        p95Us: p95Us,
        maxUs: p95Us,
      ),
      evaluate: const BenchmarkStats(minUs: 1, medianUs: 2, p95Us: 3, maxUs: 3),
      generatePlaces: 35,
      generateUnplaced: 0,
      evaluatePlaces: 35,
      evaluateUnplaced: 0,
    );

void main() {
  test('la fixture de performance décrit 35 élèves placés', () {
    final cls = ClassGroup.fromJson(
      jsonDecode(File(benchmarkFixturePath).readAsStringSync())
          as Map<String, dynamic>,
    );

    expect(cls.students, hasLength(35));
    expect(cls.assignment, hasLength(35));
    expect(cls.room.rows, 5);
    expect(cls.room.cols, 7);
  });

  test('les statistiques utilisent une médiane et un P95 stables', () {
    final stats = BenchmarkStats.fromSamples([
      for (final microseconds in List.generate(20, (index) => index + 1))
        Duration(microseconds: microseconds),
    ]);

    expect(stats.minUs, 1);
    expect(stats.medianUs, 10);
    expect(stats.p95Us, 19);
    expect(stats.maxUs, 20);
  });

  test('la régression P95 est relative à la référence', () {
    final baseline = _report(p95Us: 100);

    expect(
      hasP95Regression(baseline: baseline, current: _report(p95Us: 120)),
      isFalse,
    );
    expect(
      hasP95Regression(baseline: baseline, current: _report(p95Us: 121)),
      isTrue,
    );
  });

  test('le rapport JSON conserve les métriques et les invariants', () {
    final report = _report(p95Us: 100);

    final decoded = SeatingEngineBenchmarkReport.fromJson(report.toJson());

    expect(decoded.generate.p95Us, 100);
    expect(decoded.generatePlaces, 35);
    expect(() => verifyBenchmarkCorrectness(decoded), returnsNormally);
  });
}
