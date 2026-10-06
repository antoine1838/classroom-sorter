// Mesure manuelle du générateur avec la fixture représentative de 35 élèves.
//
// Exécuter depuis la racine du dépôt :
//   dart run tool/seating_engine_benchmark.dart
//
// Ne pas comparer des valeurs absolues entre des machines différentes. Ce
// lanceur sert à suivre une régression sur une même machine et à décider si
// l'opération bloque trop longtemps l'interface.
import 'dart:convert';
import 'dart:io';

import 'package:plandeclasse/engine/seating_engine.dart';
import 'package:plandeclasse/models/classroom.dart';

const _fixturePath = 'test/fixtures/demo_class_varied_35.json';
const _warmupRuns = 2;
const _measuredRuns = 10;

void main() {
  final fixture = File(_fixturePath).readAsStringSync();
  final generateSamples = <Duration>[];
  final evaluateSamples = <Duration>[];
  PlanResult? lastGeneration;
  PlanResult? lastEvaluation;

  for (var run = 0; run < _warmupRuns + _measuredRuns; run++) {
    // Une nouvelle classe par essai évite que l'état mutable de la fixture
    // n'influence une mesure ultérieure.
    final generationClass = ClassGroup.fromJson(
      jsonDecode(fixture) as Map<String, dynamic>,
    );
    final generateWatch = Stopwatch()..start();
    final generation = SeatingEngine(generationClass, seed: run).generate();
    generateWatch.stop();

    final evaluationClass = ClassGroup.fromJson(
      jsonDecode(fixture) as Map<String, dynamic>,
    );
    final evaluateWatch = Stopwatch()..start();
    final evaluation = SeatingEngine(evaluationClass, seed: run).evaluate();
    evaluateWatch.stop();

    if (run >= _warmupRuns) {
      generateSamples.add(generateWatch.elapsed);
      evaluateSamples.add(evaluateWatch.elapsed);
      lastGeneration = generation;
      lastEvaluation = evaluation;
    }
  }

  final generationStats = _TimingStats.fromSamples(generateSamples);
  final evaluationStats = _TimingStats.fromSamples(evaluateSamples);
  final generation = lastGeneration!;
  final evaluation = lastEvaluation!;

  stdout.writeln('Fixture : $_fixturePath');
  stdout.writeln(
    'Configuration : $_measuredRuns générations, $_warmupRuns échauffements',
  );
  stdout.writeln(
    'Paramètres : 40 redémarrages × 1000 itérations (valeurs production)',
  );
  stdout.writeln('Générer (ms) : ${generationStats.describe()}');
  stdout.writeln('Valider (ms) : ${evaluationStats.describe()}');
  stdout.writeln(
    'Contrôle génération : score=${generation.score}, '
    'places=${generation.assignment.length}, '
    'élèves non placés=${generation.unplacedStudentIds.length}',
  );
  stdout.writeln(
    'Contrôle validation : score=${evaluation.score}, '
    'places=${evaluation.assignment.length}, '
    'élèves non placés=${evaluation.unplacedStudentIds.length}',
  );
  stdout.writeln(
    'Décision : isoler generate() si le P95 dépasse 100 ms '
    'sur l’appareil cible ; conserver evaluate() tant que son P95 reste '
    'sous ce seuil.',
  );
}

class _TimingStats {
  _TimingStats._(this.min, this.median, this.p95, this.max);

  factory _TimingStats.fromSamples(List<Duration> samples) {
    final sorted = samples.map((sample) => sample.inMicroseconds).toList()
      ..sort();
    return _TimingStats._(
      sorted.first,
      _percentile(sorted, 0.5),
      _percentile(sorted, 0.95),
      sorted.last,
    );
  }

  final int min;
  final int median;
  final int p95;
  final int max;

  String describe() =>
      'min=${_milliseconds(min)}, '
      'médiane=${_milliseconds(median)}, '
      'p95=${_milliseconds(p95)}, '
      'max=${_milliseconds(max)}';
}

int _percentile(List<int> sortedValues, double percentile) =>
    sortedValues[(percentile * (sortedValues.length - 1)).ceil()];

String _milliseconds(int microseconds) =>
    (microseconds / Duration.microsecondsPerMillisecond).toStringAsFixed(1);
