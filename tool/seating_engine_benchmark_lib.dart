import 'dart:convert';
import 'dart:io';

import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';

const benchmarkFixturePath = 'test/fixtures/demo_class_varied_35.json';
const benchmarkWarmupSeeds = [100, 101];
const benchmarkTimingSeeds = [
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
];
const benchmarkP95RegressionThreshold = 0.20;

class BenchmarkStats {
  const BenchmarkStats({
    required this.minUs,
    required this.medianUs,
    required this.p95Us,
    required this.maxUs,
  });

  factory BenchmarkStats.fromSamples(List<Duration> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'ne peut pas être vide');
    }
    final sorted = samples.map((sample) => sample.inMicroseconds).toList()
      ..sort();
    return BenchmarkStats(
      minUs: sorted.first,
      medianUs: _percentile(sorted, 0.5),
      p95Us: _percentile(sorted, 0.95),
      maxUs: sorted.last,
    );
  }

  factory BenchmarkStats.fromJson(Map<String, dynamic> json) => BenchmarkStats(
    minUs: json['minUs'] as int,
    medianUs: json['medianUs'] as int,
    p95Us: json['p95Us'] as int,
    maxUs: json['maxUs'] as int,
  );

  final int minUs;
  final int medianUs;
  final int p95Us;
  final int maxUs;

  Map<String, int> toJson() => {
    'minUs': minUs,
    'medianUs': medianUs,
    'p95Us': p95Us,
    'maxUs': maxUs,
  };
}

class SeatingEngineBenchmarkReport {
  const SeatingEngineBenchmarkReport({
    required this.fixturePath,
    required this.generate,
    required this.evaluate,
    required this.generatePlaces,
    required this.generateUnplaced,
    required this.evaluatePlaces,
    required this.evaluateUnplaced,
  });

  factory SeatingEngineBenchmarkReport.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] as Map<String, dynamic>;
    final correctness = json['correctness'] as Map<String, dynamic>;
    final generateCorrectness = correctness['generate'] as Map<String, dynamic>;
    final evaluateCorrectness = correctness['evaluate'] as Map<String, dynamic>;
    return SeatingEngineBenchmarkReport(
      fixturePath: json['fixturePath'] as String,
      generate: BenchmarkStats.fromJson(
        metrics['generate'] as Map<String, dynamic>,
      ),
      evaluate: BenchmarkStats.fromJson(
        metrics['evaluate'] as Map<String, dynamic>,
      ),
      generatePlaces: generateCorrectness['places'] as int,
      generateUnplaced: generateCorrectness['unplaced'] as int,
      evaluatePlaces: evaluateCorrectness['places'] as int,
      evaluateUnplaced: evaluateCorrectness['unplaced'] as int,
    );
  }

  final String fixturePath;
  final BenchmarkStats generate;
  final BenchmarkStats evaluate;
  final int generatePlaces;
  final int generateUnplaced;
  final int evaluatePlaces;
  final int evaluateUnplaced;

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'fixturePath': fixturePath,
    'config': {
      'warmupSeeds': benchmarkWarmupSeeds,
      'timingSeeds': benchmarkTimingSeeds,
      'restarts': 40,
      'iterations': 1000,
    },
    'metrics': {'generate': generate.toJson(), 'evaluate': evaluate.toJson()},
    'correctness': {
      'generate': {'places': generatePlaces, 'unplaced': generateUnplaced},
      'evaluate': {'places': evaluatePlaces, 'unplaced': evaluateUnplaced},
    },
  };
}

SeatingEngineBenchmarkReport runSeatingEngineBenchmark({
  String fixturePath = benchmarkFixturePath,
}) {
  final fixture = File(fixturePath).readAsStringSync();

  for (final seed in benchmarkWarmupSeeds) {
    _generate(fixture, seed);
    _evaluate(fixture, seed);
  }

  final generateSamples = <Duration>[];
  final evaluateSamples = <Duration>[];
  PlanResult? generation;
  PlanResult? evaluation;
  for (final seed in benchmarkTimingSeeds) {
    final generateWatch = Stopwatch()..start();
    generation = _generate(fixture, seed);
    generateWatch.stop();
    generateSamples.add(generateWatch.elapsed);

    final evaluateWatch = Stopwatch()..start();
    evaluation = _evaluate(fixture, seed);
    evaluateWatch.stop();
    evaluateSamples.add(evaluateWatch.elapsed);
  }

  return SeatingEngineBenchmarkReport(
    fixturePath: fixturePath,
    generate: BenchmarkStats.fromSamples(generateSamples),
    evaluate: BenchmarkStats.fromSamples(evaluateSamples),
    generatePlaces: generation!.assignment.length,
    generateUnplaced: generation.unplacedStudentIds.length,
    evaluatePlaces: evaluation!.assignment.length,
    evaluateUnplaced: evaluation.unplacedStudentIds.length,
  );
}

bool hasP95Regression({
  required SeatingEngineBenchmarkReport baseline,
  required SeatingEngineBenchmarkReport current,
  double threshold = benchmarkP95RegressionThreshold,
}) {
  _verifyComparable(baseline, current);
  return current.generate.p95Us > baseline.generate.p95Us * (1 + threshold);
}

void verifyBenchmarkCorrectness(SeatingEngineBenchmarkReport report) {
  if (report.generatePlaces != 35 ||
      report.generateUnplaced != 0 ||
      report.evaluatePlaces != 35 ||
      report.evaluateUnplaced != 0) {
    throw StateError(
      'Fixture 35 élèves invalide : '
      'génération=${report.generatePlaces}/${report.generateUnplaced}, '
      'validation=${report.evaluatePlaces}/${report.evaluateUnplaced}.',
    );
  }
}

PlanResult _generate(String fixture, int seed) {
  final cls = ClassGroup.fromJson(jsonDecode(fixture) as Map<String, dynamic>);
  return SeatingEngine(cls, seed: seed).generate();
}

PlanResult _evaluate(String fixture, int seed) {
  final cls = ClassGroup.fromJson(jsonDecode(fixture) as Map<String, dynamic>);
  return SeatingEngine(cls, seed: seed).evaluate();
}

int _percentile(List<int> sortedValues, double percentile) {
  // Méthode du rang le plus proche : avec 20 mesures, le P95 est la
  // 19e valeur (index 18), et non pas systématiquement le maximum.
  final index = (percentile * sortedValues.length).ceil() - 1;
  return sortedValues[index];
}

void _verifyComparable(
  SeatingEngineBenchmarkReport baseline,
  SeatingEngineBenchmarkReport current,
) {
  if (baseline.fixturePath != current.fixturePath) {
    throw ArgumentError('Les fixtures de référence et courante diffèrent.');
  }
  verifyBenchmarkCorrectness(baseline);
  verifyBenchmarkCorrectness(current);
}
