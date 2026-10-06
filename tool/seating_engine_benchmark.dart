import 'dart:convert';
import 'dart:io';

import 'seating_engine_benchmark_lib.dart';

// Mesure manuelle ou CI du générateur avec la fixture représentative de
// 35 élèves. Exécuter depuis la racine du dépôt :
//
//   dart run tool/seating_engine_benchmark.dart --json-out result.json
//   dart run tool/seating_engine_benchmark.dart \
//     --json-out result.json --compare main.json --threshold 0.20
void main(List<String> args) {
  final options = _BenchmarkOptions.parse(args);
  final report = runSeatingEngineBenchmark(fixturePath: options.fixturePath);
  verifyBenchmarkCorrectness(report);

  if (options.jsonOut != null) {
    File(options.jsonOut!).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
  }

  stdout.writeln('Fixture : ${report.fixturePath}');
  stdout.writeln(
    'Générer (ms) : ${_describe(report.generate)}; '
    'Valider (ms) : ${_describe(report.evaluate)}',
  );

  if (options.comparePath == null) return;
  final baseline = SeatingEngineBenchmarkReport.fromJson(
    jsonDecode(File(options.comparePath!).readAsStringSync())
        as Map<String, dynamic>,
  );
  final regression = hasP95Regression(
    baseline: baseline,
    current: report,
    threshold: options.threshold,
  );
  final ratio = report.generate.p95Us / baseline.generate.p95Us;
  stdout.writeln(
    'Comparaison P95 génération : '
    '${(ratio * 100).toStringAsFixed(1)} % de la référence '
    '(tolérance ${(options.threshold * 100).toStringAsFixed(0)} %).',
  );
  if (regression) {
    stderr.writeln('Régression de performance détectée.');
    exitCode = 1;
  }
}

class _BenchmarkOptions {
  const _BenchmarkOptions({
    required this.fixturePath,
    required this.threshold,
    this.jsonOut,
    this.comparePath,
  });

  factory _BenchmarkOptions.parse(List<String> args) {
    var fixturePath = benchmarkFixturePath;
    var threshold = benchmarkP95RegressionThreshold;
    String? jsonOut;
    String? comparePath;
    for (var index = 0; index < args.length; index++) {
      final argument = args[index];
      if (argument == '--fixture') {
        fixturePath = _value(args, ++index, argument);
      } else if (argument == '--json-out') {
        jsonOut = _value(args, ++index, argument);
      } else if (argument == '--compare') {
        comparePath = _value(args, ++index, argument);
      } else if (argument == '--threshold') {
        threshold = double.parse(_value(args, ++index, argument));
      } else {
        throw ArgumentError.value(argument, 'args', 'option inconnue');
      }
    }
    if (threshold < 0) {
      throw ArgumentError.value(threshold, 'threshold', 'doit être positif');
    }
    return _BenchmarkOptions(
      fixturePath: fixturePath,
      jsonOut: jsonOut,
      comparePath: comparePath,
      threshold: threshold,
    );
  }

  final String fixturePath;
  final String? jsonOut;
  final String? comparePath;
  final double threshold;
}

String _value(List<String> args, int index, String option) {
  if (index >= args.length) {
    throw ArgumentError.value(option, 'args', 'valeur manquante');
  }
  return args[index];
}

String _describe(BenchmarkStats stats) =>
    'min=${_milliseconds(stats.minUs)}, '
    'médiane=${_milliseconds(stats.medianUs)}, '
    'p95=${_milliseconds(stats.p95Us)}, '
    'max=${_milliseconds(stats.maxUs)}';

String _milliseconds(int microseconds) =>
    (microseconds / Duration.microsecondsPerMillisecond).toStringAsFixed(1);
