import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/data/datasources/concept_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/concept_model.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/repositories/concept_repository.dart';
import 'package:englizia/features/lessons/domain/services/concept_stations.dart';

/// The mock concepts.
ConceptBank mockConcepts() => ConceptBankModel(
  asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(ConceptFakeDataSource.asset).readAsStringSync()),
    ),
  ),
).toEntity();

class FakeConceptRepository implements ConceptRepository {
  FakeConceptRepository({this.bank, this.failure});

  ConceptBank? bank;

  /// What the server answers instead of the concepts.
  Failure? failure;
  final answers = <(String, bool)>[];
  final reports = <(String, ProblemReason)>[];
  var sends = 0;

  @override
  ConceptBank? get keptBank => bank;

  @override
  Future<Result<ConceptBank>> getBank() async {
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Ok(bank!);
  }

  @override
  Future<ConceptOutcome> answer(
    Concept concept, {
    required bool correct,
  }) async {
    answers.add((concept.id, correct));
    final outcome = outcomeOf(concept.stations, correct: correct);
    bank = bank!.copyWith(
      due: [...bank!.due.where((c) => c.id != concept.id)],
      mastered: outcome.kind == OutcomeKind.mastered
          ? [
              ...bank!.mastered,
              ConceptName(id: concept.id, arabic: concept.arabic),
            ]
          : null,
    );
    return outcome;
  }

  @override
  Future<void> report(Concept concept, ProblemReason reason) async =>
      reports.add((concept.id, reason));

  @override
  Future<void> sendPending() async => sends++;
}
