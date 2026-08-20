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
import 'plan_issue.dart';

/// Une violation détectée : le libellé lisible et les élèves qu'elle concerne.
typedef _Violation = ({String label, List<String> studentIds});

/// Infractions à un objectif d'équilibre : combien, et par qui.
typedef _Tally = ({int count, Set<String> ids});

class PlanResult {
  /// Place "r,c" -> id de l'élève.
  final Map<String, String> assignment;
  final List<String> unplacedStudentIds;

  /// Problèmes issus des règles (dures et souples), chacun rattaché aux élèves
  /// concernés.
  final List<PlanIssue> issues;

  /// Bilan des objectifs d'équilibre activés : pour chacun, respecté ou non,
  /// le libellé à afficher et les élèves concernés.
  final List<BalanceNote> balance;
  final double score; // coût final (plus bas = meilleur)

  /// Élève -> problèmes le concernant, règles et équilibre confondus.
  final Map<String, List<PlanIssue>> _byStudent;

  PlanResult({
    required this.assignment,
    required this.unplacedStudentIds,
    required this.issues,
    required this.balance,
    required this.score,
  }) : _byStudent = _indexByStudent(issues, balance);

  /// Libellés des contraintes dures non respectées.
  List<String> get violations =>
      [for (final i in issues) if (i.isHard) i.label];

  /// Libellés des contraintes souples non respectées, et informations.
  List<String> get warnings =>
      [for (final i in issues) if (!i.isHard) i.label];

  bool get hasHardViolations => issues.any((i) => i.isHard);

  /// Nombre de contraintes DURES non respectées : le plan est invalide.
  int get hardCount => issues.where((i) => i.isHard).length;

  /// Nombre de points perfectibles : avertissements souples ET objectifs
  /// d'équilibre non atteints.
  ///
  /// Les notes d'équilibre comptent ici, ce qui n'allait pas de soi : le résumé
  /// annonçait « tout est respecté » alors que des objectifs ne l'étaient pas,
  /// parce qu'ils ne vivent pas dans [issues] mais dans [balance].
  int get softCount =>
      issues.where((i) => !i.isHard).length +
      balance.where((n) => !n.ok).length;

  /// Vrai quand il n'y a strictement rien à signaler.
  bool get isClean => hardCount == 0 && softCount == 0;

  /// Gravité à marquer sur la place de [studentId] : dure si au moins une
  /// contrainte dure le concerne, souple s'il n'y a que du souple, null s'il
  /// n'est concerné par rien.
  IssueSeverity? severityFor(String studentId) {
    final list = _byStudent[studentId];
    if (list == null || list.isEmpty) return null;
    return list.any((i) => i.isHard) ? IssueSeverity.hard : IssueSeverity.soft;
  }

  /// Problèmes concernant [studentId], les contraintes dures d'abord.
  List<PlanIssue> issuesFor(String studentId) {
    final list = _byStudent[studentId];
    if (list == null) return const [];
    return [...list.where((i) => i.isHard), ...list.where((i) => !i.isHard)];
  }

  /// Motifs à afficher au tap sur une place, les plus graves d'abord.
  List<String> reasonsFor(String studentId) =>
      [for (final i in issuesFor(studentId)) i.label];

  /// Élèves concernés par au moins un problème.
  Set<String> get flaggedStudentIds => _byStudent.keys.toSet();

  /// Indexe les problèmes par élève. Un objectif d'équilibre non atteint marque
  /// ses élèves au même titre qu'une contrainte souple.
  static Map<String, List<PlanIssue>> _indexByStudent(
      List<PlanIssue> issues, List<BalanceNote> balance) {
    final map = <String, List<PlanIssue>>{};
    void add(PlanIssue issue) {
      for (final id in issue.studentIds) {
        (map[id] ??= <PlanIssue>[]).add(issue);
      }
    }

    for (final i in issues) {
      add(i);
    }
    for (final n in balance) {
      if (n.ok || n.studentIds.isEmpty) continue;
      add(PlanIssue(
        severity: IssueSeverity.soft,
        label: n.label,
        studentIds: n.studentIds,
      ));
    }
    return map;
  }
}

class SeatingEngine {
  final ClassGroup cls;
  final Random _rng;

  late final List<String> _seats; // places utilisables
  late final Map<String, Set<String>> _neighbors; // place -> voisines (4 dir.)
  late final Map<String, Student> _byId;

  /// Nombre de rangs constituant la « moitié avant » (près du tableau), rang 0
  /// inclus. Pour un nombre impair de rangs, le rang du milieu est compté
  /// devant (moitié généreuse).
  late final int _frontHalfRows;

  // Barème des pénalités. Les contraintes DURES dominent tout : leur coût
  // (≥ [hardPenalty]) reste très loin au-dessus du cumul maximum possible des
  // termes d'équilibre (≈ nb de paires de voisins × poids). Les préférences
  // explicites (règles souples) passent avant les objectifs d'équilibre
  // génériques, eux-mêmes nettement renforcés pour un vrai brassage.
  static const double hardPenalty = 100000.0;
  static const double softPenalty = 40.0;
  static const double balancePenalty = 12.0; // mixité genre / niveau / taille
  static const double agitePenalty = 20.0; // deux agités voisins

  // Recuit : la température est DÉCOUPLÉE de [hardPenalty] et calée sur
  // l'échelle des termes souples ; le refroidissement descend assez bas pour
  // que ces termes soient réellement optimisés en fin de parcours (sinon un
  // poids d'équilibre est presque toujours accepté et n'a aucun effet).
  static const double _initialTemp = 150.0;
  static const double _coolingRate = 0.995;

  SeatingEngine(this.cls, {int? seed}) : _rng = Random(seed) {
    _seats = cls.room.seatKeys;
    _byId = {for (final s in cls.students) s.id: s};
    _frontHalfRows = (cls.room.rows / 2).ceil();
    // « Voisins » = places orthogonalement adjacentes (gauche, droite, devant,
    // derrière). Pas de diagonale. Un couloir de colonne coupe le lien
    // horizontal (mais jamais le lien devant/derrière).
    const dirs = [(0, -1), (0, 1), (-1, 0), (1, 0)];
    _neighbors = {};
    for (final k in _seats) {
      final (r, c) = Room.parse(k);
      final set = <String>{};
      for (final (dr, dc) in dirs) {
        final nr = r + dr;
        final nc = c + dc;
        if (cls.room.isSeat(nr, nc) && !cls.room.colAisleBetween(c, nc)) {
          set.add(Room.keyOf(nr, nc));
        }
      }
      _neighbors[k] = set;
    }
  }

  /// Génère un plan. [seed] non fourni => résultat différent à chaque appel.
  PlanResult generate({int restarts = 40, int iterations = 1000}) {
    // 1) Places imposées (contrainte dure gérée par « épinglage »).
    final pinning = _pinFixedSeats();

    // 2) Élèves et places libres.
    final freeStudents = [
      for (final s in cls.students)
        if (!pinning.pinned.containsKey(s.id)) s.id
    ];
    final freeSeats = [
      for (final k in _seats)
        if (!pinning.takenSeats.contains(k)) k
    ];

    // 3) Recherche par recuit simulé avec redémarrages.
    final search =
        _anneal(freeStudents, freeSeats, pinning.pinned, restarts, iterations);

    // 4) Construire le plan final.
    final seatOf = <String, String>{...pinning.pinned};
    search.best.forEach((sid, seat) {
      if (seat != null) seatOf[sid] = seat;
    });
    final assignment = <String, String>{};
    seatOf.forEach((sid, seat) => assignment[seat] = sid);

    final unplaced = [
      for (final s in cls.students)
        if (!seatOf.containsKey(s.id)) s.id
    ];

    // 5) Rapport lisible.
    return PlanResult(
      assignment: assignment,
      unplacedStudentIds: unplaced,
      issues: _report(seatOf, pinning.issues, unplaced),
      balance: _balanceNotes(seatOf),
      score: search.bestCost,
    );
  }

  /// Résout les règles [RuleType.fixedSeat] par épinglage : renvoie les
  /// places imposées, l'ensemble des places ainsi prises, et les conflits
  /// détectés (place inexistante, déjà prise, ou élève avec plusieurs places
  /// imposées — seule la première est gardée).
  ({Map<String, String> pinned, Set<String> takenSeats, List<PlanIssue> issues})
      _pinFixedSeats() {
    final pinned = <String, String>{}; // studentId -> seatKey
    final takenSeats = <String>{};
    final issues = <PlanIssue>[];

    // Un conflit de place imposée est toujours une violation dure : la règle
    // ne peut pas être honorée du tout.
    void conflict(Student s, String label) => issues.add(PlanIssue(
          severity: IssueSeverity.hard,
          label: label,
          studentIds: [s.id],
        ));

    for (final rule in cls.rules.where((r) => r.type == RuleType.fixedSeat)) {
      final s = _byId[rule.studentAId];
      if (s == null || rule.seatRow == null || rule.seatCol == null) continue;
      final k = Room.keyOf(rule.seatRow!, rule.seatCol!);
      if (!cls.room.isSeat(rule.seatRow!, rule.seatCol!)) {
        conflict(s, "${s.fullName} : la place imposée n'existe pas.");
        continue;
      }
      if (takenSeats.contains(k)) {
        conflict(s, '${s.fullName} : place imposée déjà occupée.');
        continue;
      }
      if (pinned.containsKey(s.id)) {
        conflict(
            s, '${s.fullName} : plusieurs places imposées, la 1re est gardée.');
        continue;
      }
      pinned[s.id] = k;
      takenSeats.add(k);
    }

    return (pinned: pinned, takenSeats: takenSeats, issues: issues);
  }

  /// Recuit simulé avec redémarrages : renvoie le meilleur placement trouvé
  /// (élève -> place libre, ou null si non placé) et son coût.
  ({Map<String, String?> best, double bestCost}) _anneal(
    List<String> freeStudents,
    List<String> freeSeats,
    Map<String, String> pinned,
    int restarts,
    int iterations,
  ) {
    Map<String, String?> best = {};
    double bestCost = double.infinity;

    for (var restart = 0; restart < restarts; restart++) {
      final current = _randomFill(freeStudents, freeSeats);
      final cost = _annealRun(current, freeStudents, pinned, iterations);
      if (cost < bestCost) {
        bestCost = cost;
        best = Map<String, String?>.from(current);
      }
    }

    return (best: best, bestCost: bestCost);
  }

  /// Une passe de recuit simulé (un « restart ») : échange des places au
  /// hasard, accepte si ça améliore le coût ou, avec une probabilité
  /// décroissante (température), si ça le dégrade. Modifie [current] en
  /// place ; renvoie le coût final atteint.
  double _annealRun(
    Map<String, String?> current,
    List<String> freeStudents,
    Map<String, String> pinned,
    int iterations,
  ) {
    double cost = _cost(current, pinned);
    double temp = _initialTemp;

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
      temp *= _coolingRate; // refroidissement
    }

    return cost;
  }

  /// Évalue le placement actuel ([cls.assignment]) sans le modifier : utile
  /// après un ajustement manuel (glisser-déposer) pour vérifier les règles et
  /// les objectifs d'équilibre sans relancer une génération.
  PlanResult evaluate() {
    final seatOf = <String, String>{};
    cls.assignment.forEach((seat, sid) => seatOf[sid] = seat);

    final unplaced = [
      for (final s in cls.students)
        if (!seatOf.containsKey(s.id)) s.id
    ];

    final issues = [..._report(seatOf, const [], unplaced)];

    for (final rule in cls.rules.where((r) => r.type == RuleType.fixedSeat)) {
      final s = _byId[rule.studentAId];
      if (s == null || rule.seatRow == null || rule.seatCol == null) continue;
      if (!cls.room.isSeat(rule.seatRow!, rule.seatCol!)) continue;
      final expected = Room.keyOf(rule.seatRow!, rule.seatCol!);
      if (seatOf[s.id] != expected) {
        issues.add(PlanIssue(
          severity: rule.hard ? IssueSeverity.hard : IssueSeverity.soft,
          label: "${s.fullName} n'est pas à la place imposée.",
          studentIds: [s.id],
        ));
      }
    }

    return PlanResult(
      assignment: Map<String, String>.from(cls.assignment),
      unplacedStudentIds: unplaced,
      issues: issues,
      balance: _balanceNotes(seatOf),
      score: _cost(Map<String, String?>.from(seatOf), const {}),
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

    double cost = _ruleCost(seatOf);

    // Mauvaise vue : préférence souple « moitié avant » (objectif d'équilibre,
    // même poids que les autres). Ne s'applique que si la bascule est activée.
    if (cls.balance.frontForPoorEyesight) {
      cost += _poorEyesightBackCount(seatOf) * balancePenalty;
    }

    // Objectifs d'équilibre : pénaliser les voisins identiques.
    if (cls.balance.mixGender ||
        cls.balance.mixLevel ||
        cls.balance.separateAgites) {
      cost += _neighborBalanceCost(seatOf);
    }

    // Taille : éviter qu'un élève grand se retrouve directement devant un
    // petit (rang - 1, même colonne), qui lui bloquerait la vue. Relation
    // dirigée (contrairement aux objectifs ci-dessus) : seule la paire
    // exacte grand-devant / petit-derrière compte.
    if (cls.balance.avoidTallInFrontOfShort) {
      cost += _tallInFrontOfShortCount(seatOf) * balancePenalty;
    }

    return cost;
  }

  /// Coût des règles explicites (séparer / rapprocher / devant), pondéré par
  /// [hardPenalty] ou [softPenalty] selon [Rule.hard].
  double _ruleCost(Map<String, String> seatOf) {
    double cost = 0;
    for (final rule in cls.rules) {
      final p = rule.hard ? hardPenalty : softPenalty;
      cost += switch (rule.type) {
        RuleType.separate => _separateCost(rule, seatOf, p),
        RuleType.keepTogether => _keepTogetherCost(rule, seatOf, p),
        RuleType.frontZone => _frontZoneCost(rule, seatOf, p),
        RuleType.fixedSeat => 0, // géré par épinglage
      };
    }
    return cost;
  }

  double _separateCost(Rule rule, Map<String, String> seatOf, double p) =>
      _adjacent(seatOf[rule.studentAId], seatOf[rule.studentBId]) ? p : 0;

  double _keepTogetherCost(Rule rule, Map<String, String> seatOf, double p) {
    final ka = seatOf[rule.studentAId];
    final kb = seatOf[rule.studentBId];
    return (ka == null || kb == null || !_adjacent(ka, kb)) ? p : 0;
  }

  double _frontZoneCost(Rule rule, Map<String, String> seatOf, double p) {
    final ka = seatOf[rule.studentAId];
    if (ka == null) return p;
    final (r, _) = Room.parse(ka);
    return r >= rule.frontRows ? p : 0;
  }

  /// Nombre d'élèves à mauvaise vue placés hors de la moitié avant.
  ///
  /// [ids], quand il est fourni, reçoit les élèves concernés. Il reste nul dans
  /// le chemin chaud du recuit, qui n'a besoin que du compte : aucune
  /// allocation sur les dizaines de milliers d'évaluations de coût.
  int _poorEyesightBackCount(Map<String, String> seatOf, [Set<String>? ids]) {
    var count = 0;
    for (final s in cls.students) {
      if (!s.poorEyesight) continue;
      final seat = seatOf[s.id];
      if (seat != null && Room.parse(seat).$1 >= _frontHalfRows) {
        count++;
        ids?.add(s.id);
      }
    }
    return count;
  }

  /// Parcourt chaque paire de places voisines occupées une seule fois (jamais
  /// deux fois, jamais en diagonale) et appelle [visit] avec les deux élèves
  /// concernés.
  void _forEachNeighborPair(
    Map<String, String> seatOf,
    void Function(Student a, Student b) visit,
  ) {
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
        visit(s, _byId[sid2]!);
      }
    }
  }

  /// Coût des objectifs de mixité entre voisins (genre / niveau / agités).
  double _neighborBalanceCost(Map<String, String> seatOf) {
    double cost = 0;
    _forEachNeighborPair(seatOf, (s, s2) {
      if (cls.balance.mixGender &&
          s.gender != Gender.autre &&
          s2.gender != Gender.autre &&
          s.gender == s2.gender) {
        cost += balancePenalty;
      }
      if (cls.balance.mixLevel &&
          s.level != Level.moyen &&
          s2.level != Level.moyen &&
          s.level == s2.level) {
        cost += balancePenalty;
      }
      if (cls.balance.separateAgites &&
          s.energy == Energy.agite &&
          s2.energy == Energy.agite) {
        cost += agitePenalty;
      }
    });
    return cost;
  }

  /// Nombre de paires grand-devant / petit-derrière (relation dirigée,
  /// indépendante du voisinage symétrique ci-dessus).
  ///
  /// [ids] suit la même convention que [_poorEyesightBackCount] : nul dans le
  /// chemin chaud. Les DEUX élèves de la paire sont concernés — c'est leur
  /// position relative qui pose problème, pas l'un des deux.
  int _tallInFrontOfShortCount(Map<String, String> seatOf, [Set<String>? ids]) {
    final occ = <String, String>{};
    seatOf.forEach((sid, seat) => occ[seat] = sid);
    var count = 0;
    for (final k in _seats) {
      final sid = occ[k];
      if (sid == null || _byId[sid]!.size != StudentSize.grand) continue;
      final (r, c) = Room.parse(k);
      final behindSid = occ[Room.keyOf(r + 1, c)];
      if (behindSid != null && _byId[behindSid]!.size == StudentSize.petit) {
        count++;
        ids?..add(sid)
          ..add(behindSid);
      }
    }
    return count;
  }

  /// Bilan des objectifs d'équilibre ACTIVÉS : compte, parmi les paires de
  /// voisins, celles qui vont à l'encontre de chaque objectif. Renvoie une
  /// ligne par objectif activé (respecté ou non).
  List<BalanceNote> _balanceNotes(Map<String, String> seatOf) {
    final b = cls.balance;
    if (!b.mixGender &&
        !b.mixLevel &&
        !b.separateAgites &&
        !b.frontForPoorEyesight &&
        !b.avoidTallInFrontOfShort) {
      return const [];
    }

    // Pour les objectifs de voisinage, les deux élèves de chaque paire fautive
    // sont concernés : c'est le fait d'être côte à côte qui pose problème.
    var sameGender = 0;
    var sameLevel = 0;
    var bothAgite = 0;
    final sameGenderIds = <String>{};
    final sameLevelIds = <String>{};
    final bothAgiteIds = <String>{};
    _forEachNeighborPair(seatOf, (s, s2) {
      if (b.mixGender &&
          s.gender != Gender.autre &&
          s2.gender != Gender.autre &&
          s.gender == s2.gender) {
        sameGender++;
        sameGenderIds..add(s.id)
          ..add(s2.id);
      }
      if (b.mixLevel &&
          s.level != Level.moyen &&
          s2.level != Level.moyen &&
          s.level == s2.level) {
        sameLevel++;
        sameLevelIds..add(s.id)
          ..add(s2.id);
      }
      if (b.separateAgites &&
          s.energy == Energy.agite &&
          s2.energy == Energy.agite) {
        bothAgite++;
        bothAgiteIds..add(s.id)
          ..add(s2.id);
      }
    });

    // Mauvaise vue : comptage par rang (indépendant du voisinage).
    final eyesightTotal = b.frontForPoorEyesight
        ? cls.students.where((s) => s.poorEyesight).length
        : 0;
    final eyesightIds = <String>{};
    final eyesightBack = b.frontForPoorEyesight
        ? _poorEyesightBackCount(seatOf, eyesightIds)
        : 0;

    // Taille : comptage des paires grand-devant / petit-derrière (relation
    // dirigée, indépendante du voisinage symétrique ci-dessus).
    final tallIds = <String>{};
    final tallFrontOfShort = b.avoidTallInFrontOfShort
        ? _tallInFrontOfShortCount(seatOf, tallIds)
        : 0;

    return _buildBalanceLines(
      b,
      gender: (count: sameGender, ids: sameGenderIds),
      level: (count: sameLevel, ids: sameLevelIds),
      agite: (count: bothAgite, ids: bothAgiteIds),
      eyesightTotal: eyesightTotal,
      eyesight: (count: eyesightBack, ids: eyesightIds),
      size: (count: tallFrontOfShort, ids: tallIds),
    );
  }

  /// Construit les lignes de bilan d'équilibre à partir des compteurs déjà
  /// calculés (une ligne par objectif activé).
  List<BalanceNote> _buildBalanceLines(
    BalanceSettings b, {
    required _Tally gender,
    required _Tally level,
    required _Tally agite,
    required int eyesightTotal,
    required _Tally eyesight,
    required _Tally size,
  }) {
    final notes = <BalanceNote>[];
    _addBalanceNote(notes, b.mixGender, gender,
        'Mixité filles/garçons : aucun voisin de même genre.',
        'Mixité filles/garçons : ${gender.count} paire(s) de même genre voisines.');
    _addBalanceNote(notes, b.mixLevel, level,
        'Mélange des niveaux : aucune paire de Faibles ou de Forts voisine.',
        'Mélange des niveaux : ${level.count} paire(s) de Faibles ou de Forts voisines.');
    _addBalanceNote(notes, b.separateAgites, agite,
        'Élèves agités séparés : aucun voisin agité.',
        'Élèves agités : ${agite.count} paire(s) d\'agités voisines.');
    // Note affichée seulement s'il existe au moins un élève à mauvaise vue.
    _addBalanceNote(
        notes,
        b.frontForPoorEyesight && eyesightTotal > 0,
        eyesight,
        'Mauvaise vue : tous dans la moitié avant (près du tableau).',
        'Mauvaise vue : ${eyesight.count} élève(s) hors moitié avant.');
    _addBalanceNote(notes, b.avoidTallInFrontOfShort, size,
        'Tailles : aucun grand directement devant un petit.',
        'Tailles : ${size.count} grand(s) directement devant un petit.');
    return notes;
  }

  /// Ajoute une ligne de bilan si l'objectif [active] est activé. L'objectif est
  /// atteint quand le compteur est nul ; les élèves ne sont rattachés que dans
  /// le cas contraire.
  void _addBalanceNote(List<BalanceNote> notes, bool active, _Tally tally,
      String okLabel, String violatedLabel) {
    if (!active) return;
    final ok = tally.count == 0;
    notes.add(BalanceNote(
      ok: ok,
      label: ok ? okLabel : violatedLabel,
      studentIds: ok ? const [] : tally.ids.toList(),
    ));
  }

  /// Problèmes issus des règles, rattachés aux élèves concernés.
  List<PlanIssue> _report(
    Map<String, String> seatOf,
    List<PlanIssue> fixedIssues,
    List<String> unplaced,
  ) {
    final issues = <PlanIssue>[...fixedIssues];

    String name(String? id) => _byId[id]?.fullName ?? 'Élève';

    for (final rule in cls.rules) {
      final found = switch (rule.type) {
        RuleType.separate => _separateViolation(rule, seatOf, name),
        RuleType.keepTogether => _keepTogetherViolation(rule, seatOf, name),
        RuleType.frontZone => _frontZoneViolation(rule, seatOf, name),
        RuleType.fixedSeat => null,
      };
      if (found != null) {
        issues.add(PlanIssue(
          severity: rule.hard ? IssueSeverity.hard : IssueSeverity.soft,
          label: found.label,
          studentIds: found.studentIds,
        ));
      }
    }

    // Mauvaise vue : plus de violation dure — c'est désormais un objectif
    // d'équilibre souple, rapporté via _balanceNotes (section « Équilibre »).

    if (unplaced.isNotEmpty) {
      // Sans élèves concernés : un élève non placé n'occupe aucune place, il n'y
      // a donc rien à marquer sur le plan. C'est un problème de salle.
      issues.add(PlanIssue(
        severity: IssueSeverity.soft,
        label:
            '${unplaced.length} élève(s) non placé(s) : la salle manque de places.',
      ));
    }

    return issues;
  }

  /// Les deux élèves d'une règle, le second seulement s'il existe.
  List<String> _ruleStudents(Rule rule) => [
        rule.studentAId,
        if (rule.studentBId != null) rule.studentBId!,
      ];

  _Violation? _separateViolation(
      Rule rule, Map<String, String> seatOf, String Function(String?) name) {
    if (!_adjacent(seatOf[rule.studentAId], seatOf[rule.studentBId])) {
      return null;
    }
    return (
      label:
          '${name(rule.studentAId)} et ${name(rule.studentBId)} sont voisins (à séparer).',
      studentIds: _ruleStudents(rule),
    );
  }

  _Violation? _keepTogetherViolation(
      Rule rule, Map<String, String> seatOf, String Function(String?) name) {
    final ka = seatOf[rule.studentAId];
    final kb = seatOf[rule.studentBId];
    if (ka != null && kb != null && _adjacent(ka, kb)) return null;
    return (
      label:
          '${name(rule.studentAId)} et ${name(rule.studentBId)} ne sont pas voisins.',
      studentIds: _ruleStudents(rule),
    );
  }

  _Violation? _frontZoneViolation(
      Rule rule, Map<String, String> seatOf, String Function(String?) name) {
    final ka = seatOf[rule.studentAId];
    if (ka != null && Room.parse(ka).$1 < rule.frontRows) return null;
    return (
      label: "${name(rule.studentAId)} n'est pas dans les premiers rangs.",
      studentIds: [rule.studentAId],
    );
  }
}
