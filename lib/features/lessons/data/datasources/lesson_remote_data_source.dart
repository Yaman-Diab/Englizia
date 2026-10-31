import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/models/lesson_result_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:flutter/services.dart';

abstract interface class LessonRemoteDataSource {
  Future<LessonModel> getLesson(String lessonId);

  /// [request] comes from `attemptToJson`.
  Future<void> sendAnswer(String lessonId, Map<String, Object?> request);

  /// [request] comes from `attemptToJson`; true when the answer is right.
  Future<bool> reviewAnswer(String lessonId, Map<String, Object?> request);

  /// [request] comes from `attemptToJson`.
  Future<Evaluation> reviewSpoken(
    String lessonId,
    Map<String, Object?> request,
  );

  /// [request] comes from `completionToJson`.
  Future<LessonResult> completeLesson(
    String lessonId,
    Map<String, Object?> request,
  );

  /// [request] comes from `watchToJson`.
  Future<void> sendWatch(String lessonId, Map<String, Object?> request);

  /// [request] comes from `savedWordToJson`.
  Future<void> sendWord(String lessonId, Map<String, Object?> request);

  Future<void> sendContentDone(String lessonId, Map<String, Object?> request);

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
  Future<LessonResult> completeLesson(
    String lessonId,
    Map<String, Object?> request,
  ) async => lessonResultFromJson(
    asJsonMap(
      await _client.post(
        ApiEndpoints.lessonCompletion(lessonId),
        data: request,
      ),
    ),
  );

  @override
  Future<Evaluation> reviewSpoken(
    String lessonId,
    Map<String, Object?> request,
  ) async => spokenReviewFromJson(
    asJsonMap(
      await _client.post(
        ApiEndpoints.lessonSpokenReview(lessonId),
        data: request,
      ),
    ),
  );

  @override
  Future<void> sendWord(String lessonId, Map<String, Object?> request) =>
      _client.post(ApiEndpoints.lessonWords(lessonId), data: request);

  @override
  Future<void> sendContentDone(String lessonId, Map<String, Object?> request) =>
      _client.post(ApiEndpoints.lessonContentDone(lessonId), data: request);

  @override
  Future<void> sendWatch(String lessonId, Map<String, Object?> request) =>
      _client.post(ApiEndpoints.lessonWatch(lessonId), data: request);

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
  static const grammarAsset = 'assets/mock/lessons/grammar.json';
  static const bookAsset = 'assets/mock/lessons/grammar_book.json';
  static const textAsset = 'assets/mock/lessons/interactive_text.json';
  static const brokenTextAsset =
      'assets/mock/lessons/interactive_text_broken.json';
  static const reviewsAsset = 'assets/mock/lessons/spoken_reviews.json';
  static const resultsAsset = 'assets/mock/lessons/results.json';

  /// How long the mock server takes to judge, as the design's sample does.
  static const reviewLatency = Duration(milliseconds: 1800);

  final AssetBundle _bundle;
  final Duration latency;

  /// Every other review fails, so both ends of it can be seen in mock mode.
  var _reviews = 0;

  /// Each finished lesson shows the next scenario of the design, in turn.
  var _results = 0;
  final _completions = <String>{};

  @override
  Future<LessonModel> getLesson(String lessonId) async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(
      await _bundle.loadString(switch (lessonId) {
        'les_gv' => grammarAsset,
        'les_book' => bookAsset,
        'les_it' => textAsset,
        'les_it_broken' => brokenTextAsset,
        _ => asset,
      }),
    );
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

  /// A scenario marked offline fails once, like a phone with no connection, and
  /// what was kept for later goes through.
  @override
  Future<LessonResult> completeLesson(
    String lessonId,
    Map<String, Object?> request,
  ) async {
    await Future<void>.delayed(latency);
    final results =
        jsonDecode(await _bundle.loadString(resultsAsset))! as List<Object?>;
    final result = asJsonMap(results[_results % results.length]);
    final repeat = !_completions.add('${request['completionId']}');
    if (!repeat) _results++;
    if (repeat || result.readBool('offline') == null) {
      return lessonResultFromJson(result);
    }
    throw const NetworkException('connectionError');
  }

  /// Every outcome can be seen in mock mode by what is said or typed: "football"
  /// answers something else, "quota" ends the allowance and "later" fails.
  @override
  Future<Evaluation> reviewSpoken(
    String lessonId,
    Map<String, Object?> request,
  ) async {
    await Future<void>.delayed(reviewLatency);
    final said = '${asJsonMap(request['answer'])['text']}'.toLowerCase();
    if (said.contains('later')) {
      throw const NetworkException('connectionError');
    }
    final reviews = asJsonMap(
      jsonDecode(await _bundle.loadString(reviewsAsset)),
    );
    return spokenReviewFromJson(
      asJsonMap(
        reviews[said.contains('quota')
            ? 'quotaOut'
            : said.contains('football')
            ? 'offTopic'
            : 'answered'],
      ),
    );
  }

  @override
  Future<void> sendWord(String lessonId, Map<String, Object?> request) =>
      Future<void>.delayed(latency);

  @override
  Future<void> sendContentDone(String lessonId, Map<String, Object?> request) =>
      Future<void>.delayed(latency);

  @override
  Future<void> sendWatch(String lessonId, Map<String, Object?> request) =>
      Future<void>.delayed(latency);

  @override
  Future<void> sendReport(String lessonId, Map<String, Object?> request) =>
      Future<void>.delayed(latency);
}
