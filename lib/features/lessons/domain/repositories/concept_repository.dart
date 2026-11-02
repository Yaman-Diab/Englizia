import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/concept_stations.dart';

/// Concepts to strengthen (S §11). Today's questions come with them and are kept
/// on the phone, so a session runs offline; answers and reports wait there.
abstract interface class ConceptRepository {
  /// The server's concepts, or the phone's when there is no connection.
  Future<Result<ConceptBank>> getBank();

  ConceptBank? get keptBank;

  /// The answer to a concept's question: it moves at once, and goes when it can.
  Future<ConceptOutcome> answer(Concept concept, {required bool correct});

  /// «أبلغ عن مشكلة» on a question: a made one goes straight to review.
  Future<void> report(Concept concept, ProblemReason reason);

  /// Sends what is waiting. Never fails.
  Future<void> sendPending();
}
