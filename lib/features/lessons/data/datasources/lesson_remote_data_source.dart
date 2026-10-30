import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:flutter/services.dart';

abstract interface class LessonRemoteDataSource {
  Future<LessonModel> getLesson(String lessonId);

  /// [request] comes from `attemptToJson`.
  Future<void> sendAnswer(String lessonId, Map<String, Object?> request);

  /// [request] comes from `attemptToJson`; true when the answer is right.
  Future<bool> reviewAnswer(String lessonId, Map<String, Object?> request);

  /// [request] comes from `reportToJson`.
  Future<void> sendReport(String lessonId, Map<String, Object?> request);
}

final class LessonRemoteDataSourceImpl implements LessonRemoteDataSource {
  const LessonRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<LessonModel> getLesson(String lessonId) async =>
      LessonModel(asJsonMap(await _client.get(ApiEndpoints.lesson(lessonId))));

  @override
  Future<void> sendAnswer(String lessonId, Map<String, Object?> request) =>
      _client.post(ApiEndpoints.lessonAnswers(lessonId), data: request);

  @override
  Future<bool> reviewAnswer(
    String lessonId,
    Map<String, Object?> request,
  ) async => reviewFromJson(
    asJsonMap(
      await _client.post(
        ApiEndpoints.lessonAnswerReview(lessonId),
        data: request,
      ),
    ),
  );

  @override
  Future<void> sendReport(String lessonId, Map<String, Object?> request) =>
      _client.post(ApiEndpoints.lessonReports(lessonId), data: request);
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled asset
/// the tests also use. Deleted once the endpoints are confirmed.
final class LessonFakeDataSource implements LessonRemoteDataSource {
  LessonFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 500),
  });

  static const asset = 'assets/mock/lessons/lesson.json';

  /// How long the mock server takes to judge, as the design's sample does.
  static const reviewLatency = Duration(milliseconds: 1800);

  final AssetBundle _bundle;
  final Duration latency;

  /// Every other review fails, so both ends of it can be seen in mock mode.
  var _reviews = 0;

  @override
  Future<LessonModel> getLesson(String lessonId) async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return LessonModel(asJsonMap(ApiClient.unwrap(body)));
  }

  @override
  Future<void> sendAnswer(String lessonId, Map<String, Object?> request) =>
      Future<void>.delayed(latency);

  @override
  Future<bool> reviewAnswer(
    String lessonId,
    Map<String, Object?> request,
  ) async {
    await Future<void>.delayed(reviewLatency);
    final fails = _reviews.isOdd;
    _reviews++;
    if (fails) throw const NetworkException('connectionError');
    return true;
  }

  @override
  Future<void> sendReport(String lessonId, Map<String, Object?> request) =>
      Future<void>.delayed(latency);
}
