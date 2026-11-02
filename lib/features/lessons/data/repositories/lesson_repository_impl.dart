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
import 'package:englizia/features/lessons/data/models/grammar_model.dart';
import 'package:englizia/features/lessons/data/models/lesson_result_model.dart';
import 'package:englizia/features/lessons/data/models/reader_model.dart';
import 'package:englizia/features/lessons/data/models/vocabulary_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/entities/vocabulary.dart';
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
  static const _watchKind = 'watch';
  static const _wordKind = 'word';
  static const _contentDoneKind = 'contentDone';
  static const _shadowingKind = 'shadowing';

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

  Map<String, Object?> _watches() {
    final saved = _settings.videoWatch;
    if (saved == null) return {};
    try {
      return asJsonMap(jsonDecode(saved));
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saved video watching unreadable');
      return {};
    }
  }

  @override
  WatchState? savedWatch(String lessonId) {
    final saved = _watches()[lessonId];
    return saved == null ? null : watchFromJson(asJsonMap(saved));
  }

  @override
  Future<void> saveWatch(String lessonId, WatchState watch) async {
    final watches = _watches()..[lessonId] = watchToJson(watch);
    try {
      await _settings.setVideoWatch(jsonEncode(watches));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saving video watching failed');
    }
  }

  @override
  Future<void> sendWatch(
    String lessonId,
    int lessonVersion,
    WatchState watch,
  ) async {
    final store = _store();
    store.unsent.removeWhere(
      (entry) => entry['kind'] == _watchKind && entry['lessonId'] == lessonId,
    );
    await _keep(store);
    await _enqueue(
      _watchKind,
      lessonId,
      SettingsStorageService.randomId(),
      watchToJson(watch, lessonVersion: lessonVersion),
    );
  }

  @override
  VideoQuality get videoQuality => videoQualityFromName(_settings.videoQuality);

  @override
  Future<void> setVideoQuality(VideoQuality quality) =>
      _settings.setVideoQuality(quality.name);

  @override
  ReaderPrefs get readerPrefs {
    final saved = _settings.readerPrefs;
    if (saved == null) return const ReaderPrefs();
    try {
      return readerPrefsFromJson(asJsonMap(jsonDecode(saved)));
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Reader settings unreadable');
      return const ReaderPrefs();
    }
  }

  @override
  Future<void> setReaderPrefs(ReaderPrefs prefs) =>
      _settings.setReaderPrefs(jsonEncode(readerPrefsToJson(prefs)));

  @override
  bool get readerTipSeen => _settings.readerTipSeen;

  @override
  Future<void> setReaderTipSeen() => _settings.setReaderTipSeen();

  Map<String, Object?> _savedWords() {
    final saved = _settings.savedWords;
    if (saved == null) return {};
    try {
      return asJsonMap(jsonDecode(saved));
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saved words unreadable');
      return {};
    }
  }

  @override
  Set<String> savedWords(String lessonId) => {
    for (final id in switch (_savedWords()[lessonId]) {
      final List<Object?> ids => ids,
      _ => const <Object?>[],
    })
      if (id is String) id,
  };

  @override
  Future<void> setWordSaved(SavedWord word, {required bool saved}) => _keepWord(
    word.lessonId,
    word.span.id,
    savedWordToJson(word, saved: saved),
    saved: saved,
  );

  @override
  Future<void> setVocabSaved(
    String lessonId,
    VocabWord word, {
    required bool saved,
  }) => _keepWord(
    lessonId,
    word.id,
    vocabWordToJson(word, saved: saved),
    saved: saved,
  );

  Future<void> _keepWord(
    String lessonId,
    String id,
    Map<String, Object?> request, {
    required bool saved,
  }) async {
    final ids = savedWords(lessonId);
    saved ? ids.add(id) : ids.remove(id);
    final all = _savedWords()..[lessonId] = ids.toList();
    try {
      await _settings.setSavedWords(jsonEncode(all));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saving a word failed');
    }
    await _enqueue(
      _wordKind,
      lessonId,
      SettingsStorageService.randomId(),
      request,
    );
  }

  @override
  Future<void> saveShadowingScore(ShadowingScore score) => _enqueue(
    _shadowingKind,
    score.lessonId,
    SettingsStorageService.randomId(),
    shadowingScoreToJson(score),
  );

  @override
  Future<void> sendContentDone(String lessonId, int lessonVersion) => _enqueue(
    _contentDoneKind,
    lessonId,
    SettingsStorageService.randomId(),
    {'lessonVersion': lessonVersion},
  );

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
          _watchKind => _remote.sendWatch(lessonId, request),
          _wordKind => _remote.sendWord(lessonId, request),
          _contentDoneKind => _remote.sendContentDone(lessonId, request),
          _shadowingKind => _remote.sendShadowing(lessonId, request),
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
