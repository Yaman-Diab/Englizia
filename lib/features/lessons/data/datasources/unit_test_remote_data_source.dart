import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/unit_test_model.dart';
import 'package:flutter/services.dart';

abstract interface class UnitTestRemoteDataSource {
  Future<UnitTestModel> getTest(String testId);

  /// [request] comes from `UnitTestModel.submission`; the answer as it came.
  Future<Map<String, Object?>> submit(
    String testId,
    Map<String, Object?> request,
  );

  Future<void> chooseLevel(String suggestionId, {required bool move});
}

final class UnitTestRemoteDataSourceImpl implements UnitTestRemoteDataSource {
  const UnitTestRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<UnitTestModel> getTest(String testId) async => UnitTestModel(
    asJsonMap(await _client.get(ApiEndpoints.unitTest(testId))),
  );

  @override
  Future<Map<String, Object?>> submit(
    String testId,
    Map<String, Object?> request,
  ) async => asJsonMap(
    await _client.post(ApiEndpoints.unitTestSubmissions(testId), data: request),
  );

  @override
  Future<void> chooseLevel(String suggestionId, {required bool move}) => _client
      .post(ApiEndpoints.levelCheckChoice(suggestionId), data: {'move': move});
}

/// Mock mode (`env/mock.json`): a test in the server's shape, marked here by
/// a key only the mock has, failed tries waiting their ten minutes, and a
/// level suggested after the first. Deleted once a track on the dev server
/// has a published test to try.
final class UnitTestFakeDataSource implements UnitTestRemoteDataSource {
  UnitTestFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const asset = 'assets/mock/unit_tests/unit_test.json';

  /// How long a failed try waits, as the server's.
  static const cooldown = Duration(minutes: 10);

  final AssetBundle _bundle;
  final Duration latency;
  final DateTime Function() _now;

  final _best = <String, int>{};
  final _retryAt = <String, DateTime>{};
  final _results = <String, Map<String, Object?>>{};
  var _suggested = false;

  Future<Map<String, Object?>> _load(String testId) async {
    final json = asJsonMap(
      ApiClient.unwrap(jsonDecode(await _bundle.loadString(asset))),
    );
    return {...json, 'id': testId};
  }

  String _state(String testId) {
    final retry = _retryAt[testId];
    if (retry != null && _now().isBefore(retry)) return 'cooldown';
    if ((_best[testId] ?? 0) >= 70) return 'passed';
    return 'available';
  }

  @override
  Future<UnitTestModel> getTest(String testId) async {
    await Future<void>.delayed(latency);
    final json = await _load(testId)
      ..['state'] = _state(testId)
      ..['bestPercent'] = _best[testId]
      ..['retryAvailableAt'] = _state(testId) == 'cooldown'
          ? _retryAt[testId]!.toUtc().toIso8601String()
          : null;
    json.remove('mockLevels');
    for (final question in json.readList('questions') ?? const <Object?>[]) {
      asJsonMap(question).remove('mockKey');
    }
    return UnitTestModel(json);
  }

  @override
  Future<Map<String, Object?>> submit(
    String testId,
    Map<String, Object?> request,
  ) async {
    await Future<void>.delayed(latency);
    final id = '${request['clientSubmissionId']}';
    if (_results[id] case final repeat?) return repeat;
    if (_state(testId) == 'cooldown') {
      throw ApiException(
        statusCode: 422,
        code: 'unit_test.retry_not_yet',
        retryAfter: _retryAt[testId]!.difference(_now()),
      );
    }
    final json = await _load(testId);
    final keys = {
      for (final question in json.readList('questions') ?? const <Object?>[])
        asJsonMap(question).readString('versionId'): asJsonMap(
          question,
        ).readMap('mockKey'),
    };
    final marks = [
      for (final answer in request['answers']! as List<Object?>)
        {
          'questionVersionId': asJsonMap(answer)['questionVersionId'],
          'isCorrect':
              jsonEncode(asJsonMap(answer)['answer']) ==
              jsonEncode(keys[asJsonMap(answer)['questionVersionId']]),
        },
    ];
    final correct = marks.where((mark) => mark['isCorrect'] == true).length;
    final percent = marks.isEmpty ? 0 : (correct * 100 / marks.length).round();
    final passed = percent >= (json.readInt('passPercent') ?? 70);
    final best = percent > (_best[testId] ?? 0) ? percent : _best[testId]!;
    _best[testId] = best;
    if (!passed) _retryAt[testId] = _now().add(cooldown);
    final suggest = !_suggested;
    _suggested = true;
    final result = <String, Object?>{
      'correct': correct,
      'questionCount': marks.length,
      'percent': percent,
      'passed': passed,
      'retryAvailableAt': passed
          ? null
          : _retryAt[testId]!.toUtc().toIso8601String(),
      'bestPercent': best,
      'questions': marks,
      // The mock's levels around the learner's, from its own asset.
      'levelCheck': suggest && (percent >= 85 || percent < 50)
          ? {
              'id': 'lc_mock',
              'direction': percent >= 85 ? 'up' : 'down',
              'percent': percent,
              'level': json.readMap('mockLevels')?['current'],
              'suggestedLevel': json.readMap(
                'mockLevels',
              )?[percent >= 85 ? 'above' : 'below'],
            }
          : null,
    };
    _results[id] = result;
    return result;
  }

  @override
  Future<void> chooseLevel(String suggestionId, {required bool move}) =>
      Future<void>.delayed(latency);
}
