import 'dart:async';
import 'dart:convert';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';

final class LessonRepositoryImpl implements LessonRepository {
  LessonRepositoryImpl(this._remote, {required SettingsStorageService settings})
    : _settings = settings;

  final LessonRemoteDataSource _remote;
  final SettingsStorageService _settings;

  /// The answers on their way, so they go one at a time and in order.
  Future<void>? _sending;

  @override
  Future<Result<Lesson>> getLesson(String lessonId) => guard(() async {
    final model = await _remote.getLesson(lessonId);
    return model.toEntity(await _settings.installationId());
  });

  @override
  Future<void> saveAttempt(ExerciseAttempt attempt) async {
    final store = _store();
    store.unsent.add({
      'lessonId': attempt.lessonId,
      'request': attemptToJson(attempt, SettingsStorageService.randomId()),
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
      final request = asJsonMap(first['request']);
      await _remote.sendAnswer(first['lessonId']! as String, request);
      final store = _store();
      store.unsent.removeWhere(
        (a) => asJsonMap(a['request'])['attemptId'] == request['attemptId'],
      );
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
