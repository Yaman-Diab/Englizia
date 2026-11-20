import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/placement/data/models/placement_models.dart';
import 'package:englizia/features/tracks/data/datasources/enrollments_reader.dart';
import 'package:flutter/services.dart';

abstract interface class PlacementRemoteDataSource {
  /// The learner's active track, or null when they joined none.
  Future<String?> activeTrackId();

  Future<PlacementStateModel> getState(String trackId);

  /// The running session, or a new one at its first stage.
  Future<PlacementSessionModel> startSession(String trackId);

  Future<PlacementSessionModel> getSession(String sessionId);

  /// [answers] are `{questionId, optionId}` or `{questionId, dontKnow: true}`,
  /// one for each question of [stage].
  Future<PlacementSessionModel> submitStage(
    String sessionId,
    int stage,
    List<Map<String, Object?>> answers,
  );

  /// [choice] is `result` or `lower`.
  Future<void> choose(String sessionId, String trackId, String choice);
}

final class PlacementRemoteDataSourceImpl implements PlacementRemoteDataSource {
  const PlacementRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<String?> activeTrackId() => EnrollmentsReader(_client).activeTrackId();

  @override
  Future<PlacementStateModel> getState(String trackId) async =>
      PlacementStateModel(
        asJsonMap(
          await _client.get(
            ApiEndpoints.placement,
            query: {'trackId': trackId},
          ),
        ),
      );

  @override
  Future<PlacementSessionModel> startSession(String trackId) async =>
      PlacementSessionModel(
        asJsonMap(
          await _client.post(
            ApiEndpoints.placementSessions,
            data: {'trackId': trackId},
          ),
        ),
      );

  @override
  Future<PlacementSessionModel> getSession(String sessionId) async =>
      PlacementSessionModel(
        asJsonMap(await _client.get(ApiEndpoints.placementSession(sessionId))),
      );

  @override
  Future<PlacementSessionModel> submitStage(
    String sessionId,
    int stage,
    List<Map<String, Object?>> answers,
  ) async => PlacementSessionModel(
    asJsonMap(
      await _client.post(
        ApiEndpoints.placementStage(sessionId, stage),
        data: {'answers': answers},
      ),
    ),
  );

  @override
  Future<void> choose(String sessionId, String trackId, String choice) =>
      _client.post(
        ApiEndpoints.placementChoose(sessionId),
        data: {'trackId': trackId, 'choice': choice},
      );
}

/// Mock mode (`env/mock.json`): a session that goes through the dev server's
/// own answers, saved as they came (`assets/mock/placement/`), with its state
/// kept in memory. Deleted once the endpoints are confirmed (docs/STATUS.md).
final class PlacementFakeDataSource implements PlacementRemoteDataSource {
  PlacementFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 600),
  });

  static const _folder = 'assets/mock/placement';
  static const availableAsset = '$_folder/placement_available.json';
  static const inProgressAsset = '$_folder/placement_in_progress.json';
  static const resultAsset = '$_folder/placement_result.json';
  static const doneAsset = '$_folder/placement_done.json';
  static const stage1Asset = '$_folder/session_stage_1.json';
  static const stage2Asset = '$_folder/session_stage_2.json';
  static const completedAsset = '$_folder/session_completed.json';

  final AssetBundle _bundle;
  final Duration latency;

  /// 0 none · 1 at stage 1 · 2 at stage 2 · 3 finished · 4 chosen.
  var _step = 0;

  Future<Map<String, Object?>> _read(String asset) async {
    await Future<void>.delayed(latency);
    return asJsonMap(
      ApiClient.unwrap(jsonDecode(await _bundle.loadString(asset))),
    );
  }

  @override
  Future<String?> activeTrackId() async => 'trk_general';

  @override
  Future<PlacementStateModel> getState(String trackId) async =>
      PlacementStateModel(
        await _read(switch (_step) {
          0 => availableAsset,
          1 || 2 => inProgressAsset,
          3 => resultAsset,
          _ => doneAsset,
        }),
      );

  @override
  Future<PlacementSessionModel> startSession(String trackId) async {
    if (_step >= 3) {
      throw const ApiException(
        statusCode: ApiStatusCodes.conflict,
        code: ApiErrorCodes.placementRetakeNotYet,
      );
    }
    if (_step == 0) _step = 1;
    return _session();
  }

  Future<PlacementSessionModel> _session() async => PlacementSessionModel(
    await _read(switch (_step) {
      1 => stage1Asset,
      2 => stage2Asset,
      _ => completedAsset,
    }),
  );

  @override
  Future<PlacementSessionModel> getSession(String sessionId) => _session();

  @override
  Future<PlacementSessionModel> submitStage(
    String sessionId,
    int stage,
    List<Map<String, Object?>> answers,
  ) async {
    // The same stage again answers as the session now stands.
    if (stage == _step && _step < 3) _step++;
    return _session();
  }

  @override
  Future<void> choose(String sessionId, String trackId, String choice) async {
    await Future<void>.delayed(latency);
    _step = 4;
  }
}
