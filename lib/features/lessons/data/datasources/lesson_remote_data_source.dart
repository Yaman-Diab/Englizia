import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:flutter/services.dart';

abstract interface class LessonRemoteDataSource {
  Future<LessonModel> getLesson(String lessonId);

  /// [request] comes from `attemptToJson`.
  Future<void> sendAnswer(String lessonId, Map<String, Object?> request);
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
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled asset
/// the tests also use. Deleted once the endpoints are confirmed.
final class LessonFakeDataSource implements LessonRemoteDataSource {
  const LessonFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 500),
  });

  static const asset = 'assets/mock/lessons/lesson.json';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<LessonModel> getLesson(String lessonId) async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return LessonModel(asJsonMap(ApiClient.unwrap(body)));
  }

  @override
  Future<void> sendAnswer(String lessonId, Map<String, Object?> request) =>
      Future<void>.delayed(latency);
}
