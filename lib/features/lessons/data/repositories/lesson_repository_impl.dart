import 'dart:async';
import 'dart:convert';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/media/kept_lesson.dart';
import 'package:englizia/core/media/media_vault.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/data/models/grammar_model.dart';
import 'package:englizia/features/lessons/data/models/lesson_result_model.dart';
import 'package:englizia/features/lessons/data/models/reader_model.dart';
import 'package:englizia/features/lessons/data/models/server_lesson.dart';
import 'package:englizia/features/lessons/data/models/sync_model.dart';
import 'package:englizia/features/lessons/data/models/vocabulary_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/lessons/domain/entities/vocabulary.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';

final class LessonRepositoryImpl implements LessonRepository {
  LessonRepositoryImpl(
    this._remote, {
    required SettingsStorageService settings,
    MediaVault vault = const NoMediaVault(),
    DateTime Function()? now,
    Future<void> Function()? onAccountGone,
  }) : _settings = settings,
       _vault = vault,
       _now = now ?? DateTime.now,
       _onAccountGone = onAccountGone;

  final LessonRemoteDataSource _remote;
  final SettingsStorageService _settings;

  /// The lessons downloaded to open with no connection (ADR 22).
  final MediaVault _vault;
  final DateTime Function() _now;

  /// The server no longer has the account: the session ends here.
  final Future<void> Function()? _onAccountGone;

  /// Lessons kept to open offline: small enough for preferences (ADR 12).
  static const _cachedLessons = 5;

  /// What the server refuses for good: resending can't help, and keeping it
  /// first in the queue would hold back the rest. For what still goes one by
  /// one, to endpoints that are proposed.
  /// ASSUMPTION(api): docs/api/lessons.md.
  static const _rejected = {400, 404, 409, 410, 422};

  /// The most answers one sync carries (docs/api/lessons.md).
  static const _syncLimit = 200;

  /// `attempts[3].clientCreatedAt`: the place of an answer the server couldn't
  /// read, in the request that carried it.
  static final _attemptPlace = RegExp(r'^attempts\[(\d+)\]');

  static const _answerKind = 'answer';
  static const _reportKind = 'report';
  static const _completionKind = 'completion';
  static const _watchKind = 'watch';
  static const _wordKind = 'word';
  static const _contentDoneKind = 'contentDone';
  static const _shadowingKind = 'shadowing';

  /// What is on its way, so it goes one at a time and in order.
  Future<void>? _sending;

  /// The lessons opened while the app runs, as each came: an answer is sent in
  /// the terms of the lesson the learner saw.
  final _opened = <String, LessonModel>{};

  final _verdicts = StreamController<AttemptVerdict>.broadcast();

  /// How many answers go at once: fewer after the server found them too many.
  var _batch = _syncLimit;

  /// The server found the request itself malformed, which sending again can't
  /// mend: the answers stay on the phone, and wait for a version that can.
  var _syncBroken = false;

  /// How long the server asked to wait, the last time a sync failed.
  Duration? _askedToWait;

  /// Each lesson's completion keeps its id through every try.
  final _completionIds = <String, String>{};

  /// Completed while the app runs: a unit kept from before still shows them
  /// done, sent or not.
  final _completedHere = <String>{};

  @override
  Future<Result<Lesson>> getLesson(String lessonId) async {
    final seed = await _settings.installationId();
    final cached = _cachedLesson(lessonId, seed);
    // A lesson in progress carries on with the version it started on.
    if (cached != null && !progress(lessonId).isEmpty) return Ok(cached);
    final fetched = await guard(() async {
      final model = await _remote.getLesson(lessonId);
      final lesson = _open(lessonId, model, seed);
      await _cacheLesson(lessonId, model.json);
      return lesson;
    });
    if (fetched case Err(failure: NetworkFailure())) {
      final kept = cached ?? await _downloadedLesson(lessonId, seed);
      if (kept != null) return Ok(kept);
    }
    return fetched;
  }

  /// Reads [model], and remembers it as the lesson the learner now sees.
  Lesson _open(String lessonId, LessonModel model, String seed) {
    final lesson = model.toEntity(seed);
    _opened[lessonId] = model;
    return lesson;
  }

  /// A downloaded lesson, until its download runs out.
  Future<Lesson?> _downloadedLesson(String lessonId, String seed) async {
    final json = KeptLesson.lessonOf(
      await _vault.readJson(KeptLesson.nameOf(lessonId)),
      _now(),
    );
    if (json == null) return null;
    try {
      return _open(lessonId, LessonModel(json), seed);
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Downloaded lesson unreadable');
      return null;
    }
  }

  @override
  String videoUrl(LessonVideo video, VideoQuality quality) =>
      video.sources
          .where((source) => _vault.has(source.url))
          .firstOrNull
          ?.url ??
      video.urlFor(quality);

  Lesson? _cachedLesson(String lessonId, String seed) {
    final json = _cache()[lessonId];
    if (json == null) return null;
    try {
      return _open(lessonId, LessonModel(asJsonMap(json)), seed);
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
    final lessonId = attempt.lessonId;
    final lesson = _opened[lessonId] ?? _keptModel(lessonId);
    if (lesson == null) return id;
    final store = _store();
    final request = syncAttemptToJson(
      attempt,
      lesson: lesson.own,
      attemptId: id,
      runId: store.runs[lessonId] ??= SettingsStorageService.randomId(),
      at: _now(),
    );
    // A template the server doesn't mark yet is neither kept nor sent.
    if (request == null) return id;
    await _enqueue(_answerKind, lessonId, id, request, store: store);
    return id;
  }

  LessonModel? _keptModel(String lessonId) => switch (_cache()[lessonId]) {
    final Map<Object?, Object?> json => LessonModel(json.cast()),
    _ => null,
  };

  @override
  Stream<AttemptVerdict> get verdicts => _verdicts.stream;

  /// The app's own lives as long as the app; one made for less ends here.
  Future<void> dispose() => _verdicts.close();

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
  Future<Result<Evaluation>> reviewSpoken(ExerciseAttempt attempt) => guard(
    () => _remote.reviewSpoken(
      attempt.lessonId,
      attemptToJson(attempt, SettingsStorageService.randomId()),
    ),
  );

  @override
  Future<Result<LessonResult>> completeLesson(LessonSummary summary) async {
    final lessonId = summary.lessonId;
    // Opened again, it is a new run.
    final store = _store();
    if (store.runs.remove(lessonId) != null) await _keep(store);
    if (_fromServer(lessonId)) return _endOnServer(summary);
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
    _completedHere.add(lessonId);
    final result = await guard(() => _remote.completeLesson(lessonId, request));
    if (result is Err) {
      await keep();
    } else {
      _completionIds.remove(lessonId);
    }
    return result;
  }

  bool _fromServer(String lessonId) =>
      switch (_opened[lessonId] ?? _keptModel(lessonId)) {
        final model? => isServerLesson(model.json),
        null => false,
      };

  /// The server completes a lesson by its answers, with no call of its own:
  /// the end only waits for them to be there. Its numbers are the phone's,
  /// which the server's markings have set right as they came; points, the
  /// goal and the streak aren't the server's to give yet.
  Future<Result<LessonResult>> _endOnServer(LessonSummary summary) async {
    final lessonId = summary.lessonId;
    await sendSaved();
    final waiting = _store().unsent.any(
      (entry) => entry['kind'] == _answerKind && entry['lessonId'] == lessonId,
    );
    if (waiting) return const Err(NetworkFailure());
    _completedHere.add(lessonId);
    return Ok(
      LessonResult(
        rightFirstTime: summary.rightFirstTime,
        counted: summary.counted,
        seconds: summary.seconds,
        pending: summary.pending,
      ),
    );
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
    Map<String, Object?> request, {
    LessonStoreModel? store,
  }) async {
    store ??= _store();
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
  Future<SendOutcome> sendSaved() async {
    _askedToWait = null;
    // A failure only leaves them for the next time.
    final result = await guard(
      () => _sending ??= _sendAll().whenComplete(() => _sending = null),
    );
    return switch (result) {
      Ok() => const SendOutcome.sent(),
      Err(failure: RateLimitFailure(:final retryAfter)) => SendOutcome.waiting(
        retryAfter: retryAfter ?? _askedToWait,
      ),
      Err() => SendOutcome.waiting(retryAfter: _askedToWait),
    };
  }

  /// The answers first, together, as the rest may count on them; then what
  /// still goes one by one.
  Future<void> _sendAll() async {
    await _sendAnswers();
    while (true) {
      final first = _store().unsent
          .where((entry) => entry['kind'] != _answerKind)
          .firstOrNull;
      if (first == null) return;
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
          // A kind this version doesn't know has nowhere to go.
          _ => Future<void>.value(),
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

  /// `POST /app/sync`: the oldest answers first, a batch at a time, until none
  /// is left. Each answer leaves the phone once the server has said what it
  /// did with it; a request that fails whole leaves them all for the next try.
  Future<void> _sendAnswers() async {
    while (!_syncBroken) {
      final batch = await _nextBatch();
      if (batch.isEmpty) return;
      final List<SyncResultModel> results;
      try {
        results = await _remote.sync([
          for (final entry in batch) asJsonMap(entry['request']),
        ], sentAt: _now());
      } on ApiException catch (error, stackTrace) {
        _askedToWait = error.retryAfter;
        // The account was deleted while its token still works: the session
        // ends, and what the phone kept for the account goes with it.
        if (error.statusCode == ApiStatusCodes.notFound &&
            error.code == ApiErrorCodes.userNotFound) {
          AppLogger.warning('Sync: the account is gone');
          await _onAccountGone?.call();
          return;
        }
        if (await _refused(error, stackTrace, batch)) continue;
        if (_syncBroken) return;
        rethrow;
      }
      if (await _settle(batch, results) == 0) {
        throw const FormatException('Sync: no result for the answers sent');
      }
    }
  }

  /// What to send now. An entry kept by a version before the sync existed has
  /// no place in it, and goes.
  Future<List<Map<String, Object?>>> _nextBatch() async {
    final store = _store();
    bool old(Map<String, Object?> entry) =>
        entry['kind'] == _answerKind &&
        asJsonMap(entry['request'])['clientAttemptId'] is! String;
    if (store.unsent.any(old)) {
      store.unsent.removeWhere(old);
      await _keep(store);
    }
    return store.unsent
        .where((entry) => entry['kind'] == _answerKind)
        .take(_batch)
        .toList();
  }

  /// A sync refused whole: true when it is worth sending again now.
  Future<bool> _refused(
    ApiException error,
    StackTrace stackTrace,
    List<Map<String, Object?>> batch,
  ) async {
    if (error.code == ApiErrorCodes.syncBatchTooLarge && batch.length > 1) {
      _batch = (batch.length / 2).ceil();
      return true;
    }
    if (error.statusCode != ApiStatusCodes.badRequest) return false;
    // The server names what it can't read by its place in this request: those
    // go, and the rest is sent again. Anything else it names is the request
    // itself, a bug that sending again only repeats.
    final places = <int>{};
    for (final field in error.fields) {
      final place = _attemptPlace.firstMatch(field)?.group(1);
      if (place == null) {
        places.clear();
        break;
      }
      places.add(int.parse(place));
    }
    AppLogger.error(
      error,
      stackTrace,
      'Sync refused (trace ${error.traceId}): ${error.fields.join(', ')}',
    );
    final gone = {
      for (final place in places)
        if (place < batch.length) batch[place]['id'],
    };
    if (gone.isEmpty) {
      _syncBroken = true;
      return false;
    }
    final store = _store();
    store.unsent.removeWhere((entry) => gone.contains(entry['id']));
    await _keep(store);
    return true;
  }

  /// Takes out of the queue every answer the server has decided on, whatever
  /// it decided, and returns how many. Its marking replaces the phone's where
  /// the two differ.
  Future<int> _settle(
    List<Map<String, Object?>> batch,
    List<SyncResultModel> results,
  ) async {
    final byId = {for (final result in results) result.attemptId: result};
    final store = _store();
    final settled = <Object?>{};
    final verdicts = <AttemptVerdict>[];
    for (final entry in batch) {
      final request = asJsonMap(entry['request']);
      final result = byId[request['clientAttemptId']];
      if (result == null) continue;
      settled.add(entry['id']);
      switch (result.status) {
        case SyncStatus.accepted || SyncStatus.duplicate:
          final correct = result.correct;
          if (correct == null) continue;
          final verdict = AttemptVerdict(
            lessonId: entry['lessonId']! as String,
            questionId: request['questionVersionId']! as String,
            correct: correct,
          );
          verdicts.add(verdict);
          _mark(store, verdict);
        case SyncStatus.rejected:
          AppLogger.warning('Sync: an answer refused, ${result.errorCode}');
        case SyncStatus.unknown:
          AppLogger.warning('Sync: unknown status ${result.statusName}');
      }
    }
    store.unsent.removeWhere((entry) => settled.contains(entry['id']));
    await _keep(store);
    if (!_verdicts.isClosed) verdicts.forEach(_verdicts.add);
    return settled.length;
  }

  /// The lesson's progress on the phone takes the server's marking of a
  /// question it counted.
  void _mark(LessonStoreModel store, AttemptVerdict verdict) {
    final id = verdict.questionId;
    final progress = store.progress(verdict.lessonId);
    if (!progress.done.contains(id) ||
        progress.uncounted.contains(id) ||
        progress.pending.contains(id) ||
        progress.right.contains(id) == verdict.correct) {
      return;
    }
    AppLogger.warning('Sync: the server marked an answer the other way');
    store.setProgress(
      verdict.lessonId,
      ExerciseProgress(
        done: progress.done,
        hinted: progress.hinted,
        right: verdict.correct
            ? {...progress.right, id}
            : ({...progress.right}..remove(id)),
        uncounted: progress.uncounted,
        pending: progress.pending,
        seconds: progress.seconds,
      ),
    );
  }

  @override
  ExerciseProgress progress(String lessonId) => _store().progress(lessonId);

  @override
  Future<void> saveProgress(String lessonId, ExerciseProgress progress) async {
    final store = _store()..setProgress(lessonId, progress);
    await _keep(store);
  }

  @override
  LessonOnPhone onPhone(String lessonId) {
    final store = _store();
    final waiting = store.unsent.any(
      (entry) =>
          entry['kind'] == _completionKind && entry['lessonId'] == lessonId,
    );
    final cached = _cache()[lessonId];
    final done = progress(lessonId).done.length;
    LessonResume? resume;
    if (cached != null && done > 0) {
      final total =
          LessonModel(asJsonMap(cached)).own.readList('exercises')?.length ?? 0;
      if (total > done) {
        resume = LessonResume(question: done + 1, share: done / total);
      }
    }
    return LessonOnPhone(
      kept: cached != null || _vault.hasJson(KeptLesson.nameOf(lessonId)),
      done: waiting || _completedHere.contains(lessonId),
      resume: resume,
    );
  }

  @override
  void forgetCompletions() => _completedHere.clear();

  @override
  Future<void> clearProgress(String lessonId) async {
    final store = _store();
    store.lessons.remove(lessonId);
    store.runs.remove(lessonId);
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
