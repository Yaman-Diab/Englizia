import 'dart:async';
import 'dart:convert';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/data/datasources/explain_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/models/explanation_model.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';
import 'package:englizia/features/lessons/domain/repositories/explain_repository.dart';

final class ExplainRepositoryImpl implements ExplainRepository {
  ExplainRepositoryImpl(this._remote, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ExplainRemoteDataSource _remote;
  final DateTime Function() _now;

  /// Explanations already given, by question and answer: opened again, they
  /// show at once and count nothing.
  final _given = <String, Explanation>{};

  /// The explanations left, once the server has said, and the day it said
  /// it: the count renews the next day.
  int? _count;
  DateTime? _countDay;

  int? get _left {
    final day = _countDay;
    final now = _now();
    final today =
        day != null &&
        day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
    return today ? _count : null;
  }

  set _left(int value) {
    _count = value;
    _countDay = _now();
  }

  static String _key(ExplainRequest request) =>
      '${request.questionId}:${jsonEncode(answerToJson(request.draft))}';

  @override
  Future<Result<ExplainOutcome>> explain(ExplainRequest request) async {
    final key = _key(request);
    if (_given[key] case final given?) {
      return Ok(ExplainReady(given, left: _left, fresh: false));
    }
    if (_left == 0) return const Ok(ExplainQuotaOut());
    final result = await guard(
      () async =>
          (await _remote.explain(explainRequestToJson(request))).toEntity(),
    );
    switch (result) {
      case Ok(value: ExplainReady(:final explanation, :final left)):
        _given[key] = explanation;
        if (left != null) _left = left;
      case Ok(value: ExplainQuotaOut()):
        _left = 0;
      case Err():
        break;
    }
    return result;
  }

  @override
  Future<void> rate(String explanationId, {required bool helpful}) async {
    final result = await guard(
      () => _remote.rate(explanationId, {'helpful': helpful}),
    );
    if (result case Err(:final failure)) {
      AppLogger.info('Rating an explanation failed: $failure');
    }
  }
}
