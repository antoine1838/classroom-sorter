/// Moteur d'affectation élèves -> places sous contraintes.
///
/// Approche : recuit simulé (simulated annealing) avec redémarrages
/// multiples. On minimise une fonction de coût :
///   - les contraintes « dures » violées coûtent très cher ;
///   - les contraintes « souples » et les objectifs d'équilibre coûtent peu.
/// Le meilleur plan trouvé (coût le plus bas) est renvoyé, avec un rapport
/// lisible des contraintes non satisfaites.
library;

import 'dart:math';

import '../models/classroom.dart';
import '../models/room.dart';
import '../models/rule.dart';
import '../models/student.dart';

class PlanResult {
  /// Place "r,c" -> id de l'élève.
  final Map<String, String> assignment;
  final List<String> unplacedStudentIds;
  final List<String> violations; // contraintes dures non respectées
  final List<String> warnings; // souples non respectées + infos
  final double score; // coût final (plus bas = meilleur)

  PlanResult({
    required this.assignment,
    required this.unplacedStudentIds,
    required this.violations,
    required this.warnings,
    required this.score,
  });

  bool get hasHardViolations => violations.isNotEmpty;
}

class SeatingEngine {
  final ClassGroup cls;
  final Random _rng;

  late final List<String> _seats; // places utilisables
  late final Map<String, Set<String>> _neighbors; // place -> voisines (8 dir.)
  late final Map<String, Student> _byId;

  static const double hardPenalty = 1000.0;
  static const double softPenalty = 10.0;
  static const double balancePenalty = 3.0;

  SeatingEngine(this.cls, {int? seed}) : _rng = Random(seed) {
    _seats = cls.room.seatKeys;
    _byId = {for (final s in cls.students) s.id: s};
    _neighbors = {};
    for (final k in _seats) {
      final (r, c) = Room.parse(k);
      final set = <String>{};
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          if (cls.room.isSeat(r + dr, c + dc)) {
            set.add(Room.keyOf(r + dr, c + dc));
          }
        }
      }
      _neighbors[k] = set;
    }
  }

  /// Génère un plan. [seed] non fourni => résultat différent à chaque appel.
  PlanResult generate({int restarts = 40, int iterations = 1000}) {
    // 1) Places imposées (contrainte dure gérée par « épinglage »).
    final pinned = <String, String>{}; // studentId -> seatKey
    final takenSeats = <String>{};
    final fixedIssues = <String>[];

    for (final rule in cls.rules.where((r) => r.type == RuleType.fixedSeat)) {
      final s = _byId[rule.studentAId];
      if (s == null || rule.seatRow == null || rule.seatCol == null) continue;
      final k = Room.keyOf(rule.seatRow!, rule.seatCol!);
      if (!cls.room.isSeat(rule.seatRow!, rule.seatCol!)) {
        fixedIssues.add("${s.fullName} : la place imposée n'existe pas.");
        continue;
      }
      if (takenSeats.contains(k)) {
        fixedIssues.add('${s.fullName} : place imposée déjà occupée.');
        continue;
      }
      if (pinned.containsKey(s.id)) {
        fixedIssues.add('${s.fullName} : plusieurs places imposées, la 1re est gardée.');
        continue;
      }
      pinned[s.id] = k;
      takenSeats.add(k);
    }

    // 2) Élèves et places libres.
    final freeStudents = [
      for (final s in cls.students)
        if (!pinned.containsKey(s.id)) s.id
    ];
    final freeSeats = [
      for (final k in _seats)
        if (!takenSeats.contains(k)) k
    ];

    // 3) Recherche par recuit simulé avec redémarrages.
    Map<String, String?> best = {};
    double bestCost = double.infinity;

    for (var restart = 0; restart < restarts; restart++) {
      final current = _randomFill(freeStudents, freeSeats);
      double cost = _cost(current, pinned);
      double temp = hardPenalty; // température initiale

      for (var it = 0; it < iterations && freeStudents.length >= 2; it++) {
        final a = freeStudents[_rng.nextInt(freeStudents.length)];
        final b = freeStudents[_rng.nextInt(freeStudents.length)];
        if (a == b) continue;

        // Échange des places de a et b (l'une peut être nulle).
        final tmp = current[a];
        current[a] = current[b];
        current[b] = tmp;

        final newCost = _cost(current, pinned);
        final delta = newCost - cost;
        final accept =
            delta <= 0 || _rng.nextDouble() < exp(-delta / (temp <= 0 ? 1e-4 : temp));
        if (accept) {
          cost = newCost;
        } else {
          current[b] = current[a];
          current[a] = tmp; // annuler l'échange
        }
        temp *= 0.997; // refroidissement
      }

      if (cost < bestCost) {
        bestCost = cost;
        best = Map<String, String?>.from(current);
      }
    }

    // 4) Construire le plan final.
    final seatOf = <String, String>{...pinned};
    best.forEach((sid, seat) {
      if (seat != null) seatOf[sid] = seat;
    });
    final assignment = <String, String>{};
    seatOf.forEach((sid, seat) => assignment[seat] = sid);

    final unplaced = [
      for (final s in cls.students)
        if (!seatOf.containsKey(s.id)) s.id
    ];

    // 5) Rapport lisible.
    final report = _report(seatOf, fixedIssues, unplaced);

    return PlanResult(
      assignment: assignment,
      unplacedStudentIds: unplaced,
      violations: report.$1,
      warnings: report.$2,
      score: bestCost,
    );
  }

  Map<String, String?> _randomFill(List<String> students, List<String> seats) {
    final shuffledSeats = [...seats]..shuffle(_rng);
    final shuffledStudents = [...students]..shuffle(_rng);
    final map = <String, String?>{};
    for (var i = 0; i < shuffledStudents.length; i++) {
      map[shuffledStudents[i]] = i < shuffledSeats.length ? shuffledSeats[i] : null;
    }
    return map;
  }

  bool _adjacent(String? seatA, String? seatB) {
    if (seatA == null || seatB == null) return false;
    return _neighbors[seatA]?.contains(seatB) ?? false;
  }

  double _cost(Map<String, String?> free, Map<String, String> pinned) {
    // Position de chaque élève placé.
    final seatOf = <String, String>{...pinned};
    free.forEach((sid, seat) {
      if (seat != null) seatOf[sid] = seat;
    });

    double cost = 0;

    for (final rule in cls.rules) {
      final p = rule.hard ? hardPenalty : softPenalty;
      switch (rule.type) {
        case RuleType.separate:
          if (_adjacent(seatOf[rule.studentAId], seatOf[rule.studentBId])) {
            cost += p;
          }
        case RuleType.keepTogether:
          final ka = seatOf[rule.studentAId];
          final kb = seatOf[rule.studentBId];
          if (ka == null || kb == null || !_adjacent(ka, kb)) cost += p;
        case RuleType.frontZone:
          final ka = seatOf[rule.studentAId];
          if (ka == null) {
            cost += p;
          } else {
            final (r, _) = Room.parse(ka);
            if (r >= rule.frontRows) cost += p;
          }
        case RuleType.fixedSeat:
          break; // géré par épinglage
      }
    }

    // Objectifs d'équilibre : pénaliser les voisins identiques.
    if (cls.balance.mixGender || cls.balance.mixLevel) {
      final occ = <String, String>{}; // seat -> studentId
      seatOf.forEach((sid, seat) => occ[seat] = sid);
      for (final k in _seats) {
        final sid = occ[k];
        if (sid == null) continue;
        final s = _byId[sid]!;
        for (final nk in _neighbors[k]!) {
          if (nk.compareTo(k) <= 0) continue; // compter chaque paire une fois
          final sid2 = occ[nk];
          if (sid2 == null) continue;
          final s2 = _byId[sid2]!;
          if (cls.balance.mixGender &&
              s.gender != Gender.autre &&
              s2.gender != Gender.autre &&
              s.gender == s2.gender) {
            cost += balancePenalty;
          }
          if (cls.balance.mixLevel &&
              s.level != Level.nonDefini &&
              s2.level != Level.nonDefini &&
              s.level == s2.level) {
            cost += balancePenalty;
          }
        }
      }
    }

    return cost;
  }

  /// Renvoie (violations dures, avertissements souples).
  (List<String>, List<String>) _report(
    Map<String, String> seatOf,
    List<String> fixedIssues,
    List<String> unplaced,
  ) {
    final violations = <String>[...fixedIssues];
    final warnings = <String>[];

    String name(String? id) => _byId[id]?.fullName ?? 'Élève';

    for (final rule in cls.rules) {
      switch (rule.type) {
        case RuleType.separate:
          if (_adjacent(seatOf[rule.studentAId], seatOf[rule.studentBId])) {
            final msg =
                '${name(rule.studentAId)} et ${name(rule.studentBId)} sont côte à côte (à séparer).';
            (rule.hard ? violations : warnings).add(msg);
          }
        case RuleType.keepTogether:
          final ka = seatOf[rule.studentAId];
          final kb = seatOf[rule.studentBId];
          if (ka == null || kb == null || !_adjacent(ka, kb)) {
            final msg =
                '${name(rule.studentAId)} et ${name(rule.studentBId)} ne sont pas côte à côte.';
            (rule.hard ? violations : warnings).add(msg);
          }
        case RuleType.frontZone:
          final ka = seatOf[rule.studentAId];
          var ok = false;
          if (ka != null) {
            final (r, _) = Room.parse(ka);
            ok = r < rule.frontRows;
          }
          if (!ok) {
            final msg = "${name(rule.studentAId)} n'est pas dans les premiers rangs.";
            (rule.hard ? violations : warnings).add(msg);
          }
        case RuleType.fixedSeat:
          break;
      }
    }

    if (unplaced.isNotEmpty) {
      warnings.add(
          '${unplaced.length} élève(s) non placé(s) : la salle manque de places.');
    }

    return (violations, warnings);
  }
}
