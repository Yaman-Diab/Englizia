import 'dart:async';
import 'dart:convert';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/models/lesson_result_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';

final class LessonRepositoryImpl implements LessonRepository {
  LessonRepositoryImpl(this._remote, {required SettingsStorageService settings})
    : _settings = settings;

  final LessonRemoteDataSource _remote;
  final SettingsStorageService _settings;

  /// Lessons kept to open offline: small enough for preferences (ADR 12).
  static const _cachedLessons = 5;

  /// What the server refuses for good: resending can't help, and keeping it
  /// first in the queue would hold back the rest.
  /// ASSUMPTION(api): docs/api/lessons.md.
  static const _rejected = {400, 404, 409, 410, 422};

  static const _answerKind = 'answer';
  static const _reportKind = 'report';
  static const _completionKind = 'completion';

  /// What is on its way, so it goes one at a time and in order.
  Future<void>? _sending;

  /// Each lesson's completion keeps its id through every try.
  final _completionIds = <String, String>{};

  @override
  Future<Result<Lesson>> getLesson(String lessonId) async {
    final seed = await _settings.installationId();
    final cached = _cachedLesson(lessonId, seed);
    // A lesson in progress carries on with the version it started on.
    if (cached != null && !progress(lessonId).isEmpty) return Ok(cached);
    final fetched = await guard(() async {
      final model = await _remote.getLesson(lessonId);
      final lesson = model.toEntity(seed);
      await _cacheLesson(lessonId, model.json);
      return lesson;
    });
    return switch (fetched) {
      Err(failure: NetworkFailure()) when cached != null => Ok(cached),
      _ => fetched,
    };
  }

  Lesson? _cachedLesson(String lessonId, String seed) {
    final json = _cache()[lessonId];
    if (json == null) return null;
    try {
      return LessonModel(asJsonMap(json)).toEntity(seed);
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Cached lesson unreadable');
      return null;
    }
  }

  Map<String, Object?> _cache() {
    final saved = _settings.lessonCache;
    if (saved == null) return {};
    try {
      return asJsonMap(jsonDecode(saved));
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Lesson cache unreadable');
      return {};
    }
  }

  /// Newest last. The oldest go first, but never one in progress, which has to
  /// carry on with its own version.
  Future<void> _cacheLesson(String lessonId, Map<String, Object?> json) async {
    final cache = _cache()
      ..remove(lessonId)
      ..[lessonId] = json;
    final inProgress = _store().lessons;
    final spare = [
      for (final id in cache.keys)
        if (id != lessonId && !inProgress.containsKey(id)) id,
    ];
    final over = cache.length - _cachedLessons;
    spare.take(over < 0 ? 0 : over).forEach(cache.remove);
    try {
      await _settings.setLessonCache(jsonEncode(cache));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Caching the lesson failed');
    }
  }

  @override
  Future<String> saveAttempt(ExerciseAttempt attempt) async {
    final id = SettingsStorageService.randomId();
    await _enqueue(
      _answerKind,
      attempt.lessonId,
      id,
      attemptToJson(attempt, id),
    );
    return id;
  }

  @override
  Future<Result<bool>> reviewAttempt(
    ExerciseAttempt attempt,
    String attemptId,
  ) => guard(
    () => _remote.reviewAnswer(
      attempt.lessonId,
      attemptToJson(attempt, attemptId),
    ),
  );

  @override
  Future<Result<Evaluation>> reviewSpoken(ExerciseAttempt attempt) async {
    final id = SettingsStorageService.randomId();
    final request = attemptToJson(attempt, id);
    final result = await guard(
      () => _remote.reviewSpoken(attempt.lessonId, request),
    );
    if (result is Err) {
      await _enqueue(_answerKind, attempt.lessonId, id, request);
    }
    return result;
  }

  @override
  Future<Result<LessonResult>> completeLesson(LessonSummary summary) async {
    final lessonId = summary.lessonId;
    final id = _completionIds[lessonId] ??= SettingsStorageService.randomId();
    final request = completionToJson(summary, id);
    Future<void> keep() async {
      if (_store().unsent.any((entry) => entry['id'] == id)) return;
      await _enqueue(_completionKind, lessonId, id, request);
    }

    await sendSaved();
    // The server must have the answers first, or its numbers would be wrong.
    if (_store().unsent.isNotEmpty) {
      await keep();
      return const Err(NetworkFailure());
    }
    final result = await guard(() => _remote.completeLesson(lessonId, request));
    if (result is Err) {
      await keep();
    } else {
      _completionIds.remove(lessonId);
    }
    return result;
  }

  @override
  Future<void> saveReport(ExerciseReport report) async {
    final id = SettingsStorageService.randomId();
    await _enqueue(_reportKind, report.lessonId, id, reportToJson(report, id));
  }

  Future<void> _enqueue(
    String kind,
    String lessonId,
    String id,
    Map<String, Object?> request,
  ) async {
    final store = _store();
    store.unsent.add({
      'id': id,
      'kind': kind,
      'lessonId': lessonId,
      'request': request,
    });
    await _keep(store);
    unawaited(sendSaved());
  }

  @override
  Future<void> sendSaved() async {
    // A failure only leaves them for the next time.
    await guard(
      () => _sending ??= _sendAll().whenComplete(() => _sending = null),
    );
  }

  Future<void> _sendAll() async {
    while (true) {
      final unsent = _store().unsent;
      if (unsent.isEmpty) return;
      final first = unsent.first;
      final lessonId = first['lessonId']! as String;
      final request = asJsonMap(first['request']);
      try {
        await switch (first['kind']) {
          _reportKind => _remote.sendReport(lessonId, request),
          _completionKind => _remote.completeLesson(lessonId, request),
          _ => _remote.sendAnswer(lessonId, request),
        };
      } on ApiException catch (error, stackTrace) {
        if (!_rejected.contains(error.statusCode)) rethrow;
        AppLogger.error(
          error,
          stackTrace,
          'Something sent refused, and dropped',
        );
      }
      final store = _store();
      store.unsent.removeWhere((entry) => entry['id'] == first['id']);
      await _keep(store);
    }
  }

  @override
  ExerciseProgress progress(String lessonId) => _store().progress(lessonId);

  @override
  Future<void> saveProgress(String lessonId, ExerciseProgress progress) async {
    final store = _store()..setProgress(lessonId, progress);
    await _keep(store);
  }

  @override
  Future<void> clearProgress(String lessonId) async {
    final store = _store();
    store.lessons.remove(lessonId);
    await _keep(store);
  }

  LessonStoreModel _store() {
    final saved = _settings.lessonProgress;
    if (saved == null) return LessonStoreModel();
    try {
      return LessonStoreModel.fromJson(asJsonMap(jsonDecode(saved)));
    } on Object catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saved lesson progress unreadable');
      return LessonStoreModel();
    }
  }

  /// Not kept costs only that: the session goes on.
  Future<void> _keep(LessonStoreModel store) async {
    try {
      await _settings.setLessonProgress(jsonEncode(store.toJson()));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saving lesson progress failed');
    }
  }
}
