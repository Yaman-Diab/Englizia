import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/grammar_model.dart';
import 'package:englizia/features/lessons/domain/entities/teacher_question.dart';
import 'package:flutter/services.dart';

abstract interface class TeacherQuestionRemoteDataSource {
  Future<List<TeacherQuestion>> list(String lessonId);

  /// [request] comes from `questionToJson`.
  Future<TeacherQuestion> ask(String lessonId, Map<String, Object?> request);
}

final class TeacherQuestionRemoteDataSourceImpl
    implements TeacherQuestionRemoteDataSource {
  const TeacherQuestionRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<TeacherQuestion>> list(String lessonId) async =>
      questionsFromJson(
        await _client.get(ApiEndpoints.lessonQuestions(lessonId)),
      );

  @override
  Future<TeacherQuestion> ask(
    String lessonId,
    Map<String, Object?> request,
  ) async => questionFromJson(
    asJsonMap(
      await _client.post(ApiEndpoints.lessonQuestions(lessonId), data: request),
    ),
  );
}

/// Mock mode: a learner's own questions from the bundled asset, and those asked
/// since. Deleted once the endpoints are confirmed.
final class TeacherQuestionFakeDataSource
    implements TeacherQuestionRemoteDataSource {
  TeacherQuestionFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 500),
  });

  static const asset = 'assets/mock/lessons/questions.json';

  final AssetBundle _bundle;
  final Duration latency;
  final _asked = <TeacherQuestion>[];

  @override
  Future<List<TeacherQuestion>> list(String lessonId) async {
    await Future<void>.delayed(latency);
    return [
      ..._asked,
      ...questionsFromJson(
        ApiClient.unwrap(jsonDecode(await _bundle.loadString(asset))),
      ),
    ];
  }

  @override
  Future<TeacherQuestion> ask(
    String lessonId,
    Map<String, Object?> request,
  ) async {
    await Future<void>.delayed(latency);
    final question = questionFromJson({
      ...request,
      'askedAt': DateTime.now().toUtc().toIso8601String(),
    });
    _asked.insert(0, question);
    return question;
  }
}
