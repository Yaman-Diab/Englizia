import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/features/placement/data/models/placement_result_model.dart';
import 'package:englizia/features/placement/data/models/placement_status_model.dart';
import 'package:englizia/features/placement/data/models/placement_summary_model.dart';
import 'package:englizia/features/placement/data/models/placement_test_models.dart';
import 'package:flutter/services.dart';

abstract interface class PlacementRemoteDataSource {
  Future<PlacementSummaryModel> getSummary();

  Future<PlacementStatusModel> getStatus();

  Future<void> restartTest();

  Future<void> deferTest(String enrollmentId);

  Future<PlacementAttemptModel> startAttempt();

  Future<PlacementStageModel> getStage(String attemptId, int stage);

  /// [answer] is `{answerId, questionId, optionId, plays}`.
  Future<void> sendAnswer(String attemptId, Map<String, Object?> answer);

  Future<PlacementNextModel> completeStage(String attemptId, int stage);

  Future<PlacementResultModel> getResult(String attemptId);

  Future<void> acceptLevel(String attemptId, String levelId);
}

final class PlacementRemoteDataSourceImpl implements PlacementRemoteDataSource {
  const PlacementRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<PlacementSummaryModel> getSummary() async =>
      PlacementSummaryModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.placementSummary)),
      );

  @override
  Future<PlacementStatusModel> getStatus() async =>
      PlacementStatusModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.placementStatus)),
      );

  @override
  Future<void> restartTest() =>
      _client.post(ApiEndpoints.placementAttempts, data: {'restart': true});

  @override
  Future<void> deferTest(String enrollmentId) => _client.patch(
    ApiEndpoints.enrollment(enrollmentId),
    data: {'placement_state': 'deferred'},
  );

  @override
  Future<PlacementAttemptModel> startAttempt() async =>
      PlacementAttemptModel.fromJson(
        asJsonMap(
          await _client.post(
            ApiEndpoints.placementAttempts,
            data: const <String, Object?>{},
          ),
        ),
      );

  @override
  Future<PlacementStageModel> getStage(String attemptId, int stage) async =>
      PlacementStageModel.fromJson(
        asJsonMap(
          await _client.get(ApiEndpoints.placementStage(attemptId, stage)),
        ),
      );

  @override
  Future<void> sendAnswer(String attemptId, Map<String, Object?> answer) =>
      _client.post(ApiEndpoints.placementAnswers(attemptId), data: answer);

  @override
  Future<PlacementNextModel> completeStage(String attemptId, int stage) async =>
      PlacementNextModel.fromJson(
        asJsonMap(
          await _client.post(
            ApiEndpoints.placementStageComplete(attemptId, stage),
          ),
        ),
      );

  @override
  Future<PlacementResultModel> getResult(String attemptId) async =>
      PlacementResultModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.placementResult(attemptId))),
      );

  @override
  Future<void> acceptLevel(String attemptId, String levelId) => _client.post(
    ApiEndpoints.placementAccept(attemptId),
    data: {'levelId': levelId},
  );
}

/// Mock mode (`env/mock.json`): the contract's examples from the bundled
/// assets the tests also use. Each opening of the test's intro shows the next
/// status, so all of them can be seen. Deleted once the endpoints are confirmed.
final class PlacementFakeDataSource implements PlacementRemoteDataSource {
  PlacementFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
  });

  static const asset = 'assets/mock/placement/summary.json';
  static const attemptAsset = 'assets/mock/placement/attempt.json';
  static String stageAsset(int stage) =>
      'assets/mock/placement/stage_$stage.json';
  static const resultAssets = [
    'assets/mock/placement/result_a2.json',
    'assets/mock/placement/result_pre_a1.json',
    'assets/mock/placement/result_b2.json',
  ];
  static const statusAssets = [
    'assets/mock/placement/status_none.json',
    'assets/mock/placement/status_in_progress.json',
    'assets/mock/placement/status_retake_available.json',
    'assets/mock/placement/status_retake_locked.json',
  ];

  final AssetBundle _bundle;
  final Duration latency;
  var _opened = 0;
  var _failedOnce = false;
  var _resultFailedOnce = false;
  var _results = 0;

  @override
  Future<PlacementSummaryModel> getSummary() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return PlacementSummaryModel.fromJson(asJsonMap(ApiClient.unwrap(body)));
  }

  @override
  Future<PlacementStatusModel> getStatus() async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(
      await _bundle.loadString(statusAssets[_opened++ % statusAssets.length]),
    );
    return PlacementStatusModel.fromJson(asJsonMap(ApiClient.unwrap(body)));
  }

  @override
  Future<void> restartTest() => Future<void>.delayed(latency);

  @override
  Future<void> deferTest(String enrollmentId) => Future<void>.delayed(latency);

  Future<Map<String, Object?>> _data(String path) async {
    await Future<void>.delayed(latency);
    return asJsonMap(
      ApiClient.unwrap(jsonDecode(await _bundle.loadString(path))),
    );
  }

  @override
  Future<PlacementAttemptModel> startAttempt() async =>
      PlacementAttemptModel.fromJson(await _data(attemptAsset));

  @override
  Future<PlacementStageModel> getStage(String attemptId, int stage) async =>
      PlacementStageModel.fromJson(await _data(stageAsset(stage)));

  @override
  Future<void> sendAnswer(String attemptId, Map<String, Object?> answer) =>
      Future<void>.delayed(latency);

  /// The first result fails once for lack of a connection; then each finished
  /// test comes out at the next of A2, Pre-A1 and B2, so all can be seen.
  @override
  Future<PlacementResultModel> getResult(String attemptId) async {
    if (!_resultFailedOnce) {
      _resultFailedOnce = true;
      await Future<void>.delayed(latency * 3);
      throw const NetworkException('connectionError');
    }
    final data = await _data(resultAssets[_results++ % resultAssets.length]);
    return PlacementResultModel.fromJson(data);
  }

  @override
  Future<void> acceptLevel(String attemptId, String levelId) =>
      Future<void>.delayed(latency);

  /// The second stage fails once for lack of a connection and then asks for
  /// the deciding one, so those screens can be seen. Each mock stage is short.
  @override
  Future<PlacementNextModel> completeStage(String attemptId, int stage) async {
    await Future<void>.delayed(latency);
    if (stage == 2 && !_failedOnce) {
      _failedOnce = true;
      throw const NetworkException('connectionError');
    }
    return PlacementNextModel.fromJson(switch (stage) {
      1 => const {
        'next': {
          'stage': 2,
          'questionCount': 4,
          'listeningCount': 1,
          'deciding': false,
        },
      },
      2 => const {
        'next': {
          'stage': 3,
          'questionCount': 2,
          'listeningCount': 0,
          'deciding': true,
        },
      },
      _ => const {'next': null},
    });
  }
}
