import 'dart:convert';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/send_queue.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/concept_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/concept_model.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/repositories/concept_repository.dart';
import 'package:englizia/features/lessons/domain/services/concept_stations.dart';

final class ConceptRepositoryImpl implements ConceptRepository {
  ConceptRepositoryImpl(
    this._remote,
    this._settings, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _queue = SendQueue(
      read: () => _settings.conceptsOutbox,
      write: _settings.setConceptsOutbox,
      send: (entry) => switch (entry.readString('kind')) {
        _reportKind => _remote.sendReport(asJsonMap(entry['request'])),
        _ => _remote.sendAnswer(asJsonMap(entry['request'])),
      },
    );
  }

  static const _answerKind = 'answer';
  static const _reportKind = 'report';

  final ConceptRemoteDataSource _remote;
  final SettingsStorageService _settings;
  final DateTime Function() _now;
  late final SendQueue _queue;

  /// The server's JSON as last received, so a session runs offline.
  Map<String, Object?>? get _keptJson {
    final kept = _settings.concepts;
    if (kept == null) return null;
    try {
      return asJsonMap(jsonDecode(kept));
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'The kept concepts are unreadable');
      return null;
    }
  }

  @override
  ConceptBank? get keptBank {
    final json = _keptJson;
    return json == null
        ? null
        : _answeredAway(ConceptBankModel(json).toEntity());
  }

  /// Concepts answered and not yet heard of by the server are done for today.
  ConceptBank _answeredAway(ConceptBank bank) {
    final answered = {
      for (final entry in _queue.entries)
        if (entry.readString('kind') == _answerKind)
          entry.readString('conceptId'),
    };
    if (answered.isEmpty) return bank;
    return bank.copyWith(
      due: [...bank.due.where((concept) => !answered.contains(concept.id))],
    );
  }

  @override
  Future<Result<ConceptBank>> getBank() async {
    await sendPending();
    final result = await guard(() async => (await _remote.getBank()).json);
    switch (result) {
      case Ok(:final value):
        try {
          await _settings.setConcepts(jsonEncode(value));
        } catch (error, stackTrace) {
          AppLogger.error(error, stackTrace, 'Keeping the concepts failed');
        }
        return Ok(_answeredAway(ConceptBankModel(value).toEntity()));
      case Err(:final failure):
        final kept = keptBank;
        if (failure is NetworkFailure && kept != null) return Ok(kept);
        return Err(failure);
    }
  }

  @override
  Future<ConceptOutcome> answer(
    Concept concept, {
    required bool correct,
  }) async {
    await _queue.add({
      'kind': _answerKind,
      'conceptId': concept.id,
      'request': conceptAnswerToJson(
        answerId: SettingsStorageService.randomId(),
        conceptId: concept.id,
        questionId: concept.question?.id,
        correct: correct,
        at: _now(),
      ),
    });
    return outcomeOf(concept.stations, correct: correct);
  }

  @override
  Future<void> report(Concept concept, ProblemReason reason) => _queue.add({
    'kind': _reportKind,
    'request': {
      'reportId': SettingsStorageService.randomId(),
      'conceptId': concept.id,
      'questionId': ?concept.question?.id,
      'reason': reason.name,
    },
  });

  @override
  Future<void> sendPending() => _queue.flush();
}
