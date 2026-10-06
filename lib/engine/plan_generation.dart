import 'package:flutter/foundation.dart';

import '../models/classroom.dart';
import 'seating_engine.dart';

typedef PlanGenerator = Future<PlanResult> Function(ClassGroup cls);

/// Génère un plan hors isolate UI sur les plateformes qui supportent les
/// isolates. Sur le Web, [compute] conserve une exécution compatible.
class PlanGenerationService {
  const PlanGenerationService();

  Future<PlanResult> generate(ClassGroup cls) {
    return compute(seatingGenerateWorker, {'classGroup': cls.toJson()});
  }
}

/// Point d'entrée top-level requis par [compute].
///
/// Le worker ne reçoit qu'un instantané sérialisé et ne partage donc aucun
/// modèle mutable avec l'interface.
PlanResult seatingGenerateWorker(Map<String, dynamic> message) {
  final rawClass = Map<String, dynamic>.from(message['classGroup'] as Map);
  final cls = ClassGroup.fromJson(rawClass);
  final seed = message['seed'];
  final restarts = message['restarts'] as int? ?? 40;
  final iterations = message['iterations'] as int? ?? 1000;
  final result = SeatingEngine(
    cls,
    seed: seed is int ? seed : null,
  ).generate(restarts: restarts, iterations: iterations);
  return result;
}

/// Vrai si le résultat d'une génération en arrière-plan peut encore modifier
/// le plan affiché.
bool shouldApplyGeneratedPlan({
  required String requestSignature,
  required String currentSignature,
  required int requestToken,
  required int currentToken,
}) => requestToken == currentToken && requestSignature == currentSignature;
