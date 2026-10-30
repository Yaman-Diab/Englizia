import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/models/placement_status_model.dart';
import 'package:englizia/features/placement/data/models/placement_test_models.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';

final class PlacementRepositoryImpl implements PlacementRepository {
  PlacementRepositoryImpl(
    this._remote, {
    required SettingsStorageService settings,
    DateTime Function() now = DateTime.now,
  }) : _settings = settings,
       _now = now;

  final PlacementRemoteDataSource _remote;
  final SettingsStorageService _settings;
  final DateTime Function() _now;

  /// The answers on their way, so they go one at a time and in order.
  Future<void>? _sending;

  @override
  Future<Result<PlacementSummary>> getSummary() =>
      guard(() async => (await _remote.getSummary()).entity);

  @override
  Future<Result<PlacementStatus>> getStatus() async {
    final result = await guard(() async {
      final status = await _remote.getStatus();
      await _save(status);
      return status.entity;
    });
    if (result case Err(failure: NetworkFailure())) {
      if (_savedStatus() case final saved?) return Ok(saved);
    }
    return result;
  }

  @override
  Future<Result<void>> restartTest() => guard(() async {
    await _remote.restartTest();
    // What is saved still names the question left behind.
    await _settings.clearPlacementStatus();
    await _settings.clearPlacementProgress();
  });

  @override
  Future<Result<PlacementAttempt>> startAttempt() =>
      guard(() async => (await _remote.startAttempt()).entity);

  @override
  Future<Result<List<PlacementQuestion>>> getStage(
    String attemptId,
    int stage,
  ) => guard(() async => (await _remote.getStage(attemptId, stage)).questions);

  @override
  Future<void> saveAnswer(PlacementAnswer answer) async {
    final progress = _progress(answer.attemptId);
    progress.unsent.add({
      'answerId': SettingsStorageService.randomId(),
      'stage': answer.stage,
      'questionId': answer.questionId,
      'optionId': answer.optionId,
      'dontKnow': answer.optionId == null,
      'plays': answer.plays,
    });
    await _keep(progress);
    unawaited(guard(() => _sendAll(answer.attemptId)));
  }

  @override
  Future<Result<PlacementNextStage?>> completeStage(
    String attemptId,
    int stage,
  ) => guard(() async {
    await _sendAll(attemptId);
    // One may have joined while the last ones were on their way.
    await _sendAll(attemptId);
    return (await _remote.completeStage(attemptId, stage)).entity;
  });

  @override
  int unsentAnswers(String attemptId, int stage) => _progress(
    attemptId,
  ).unsent.where((answer) => answer['stage'] == stage).length;

  @override
  int playsUsed(String attemptId, String questionId) =>
      _progress(attemptId).plays[questionId] ?? 0;

  @override
  Future<void> savePlays(String attemptId, String questionId, int plays) async {
    final progress = _progress(attemptId);
    progress.plays[questionId] = plays;
    await _keep(progress);
  }

  /// What is kept for [attemptId]; anything kept for another one is over.
  PlacementProgressModel _progress(String attemptId) {
    final saved = PlacementProgressModel.decode(_settings.placementProgress);
    return saved?.attemptId == attemptId
        ? saved!
        : PlacementProgressModel(attemptId);
  }

  Future<void> _keep(PlacementProgressModel progress) async {
    try {
      await _settings.setPlacementProgress(progress.encode());
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saving placement answers failed');
    }
  }

  Future<void> _sendAll(String attemptId) =>
      _sending ??= _sendInOrder(attemptId).whenComplete(() => _sending = null);

  Future<void> _sendInOrder(String attemptId) async {
    while (true) {
      final unsent = _progress(attemptId).unsent;
      if (unsent.isEmpty) return;
      final first = unsent.first;
      await _remote.sendAnswer(attemptId, {
        for (final entry in first.entries)
          if (entry.key != 'stage') entry.key: entry.value,
      });
      final progress = _progress(attemptId);
      progress.unsent.removeWhere((a) => a['answerId'] == first['answerId']);
      await _keep(progress);
    }
  }

  @override
  Future<Result<void>> deferTest() => guard(() async {
    final id =
        _savedModel()?.$1.enrollmentId ??
        (await _remote.getStatus()).enrollmentId;
    if (id == null) {
      throw const FormatException('Placement status has no enrollment id');
    }
    await _remote.deferTest(id);
  });

  /// Keeps [status] for when there is no connection. Not kept costs only that.
  Future<void> _save(PlacementStatusModel status) async {
    try {
      await _settings.setPlacementStatus(
        jsonEncode({
          _savedAtKey: _now().toUtc().toIso8601String(),
          _statusKey: status.json,
        }),
      );
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saving the placement status failed');
    }
  }

  /// The saved status and when it was saved; null with none, or a broken one.
  (PlacementStatusModel, DateTime)? _savedModel() {
    final saved = _settings.placementStatus;
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved) as Map<String, Object?>;
      return (
        PlacementStatusModel.fromJson(
          json[_statusKey]! as Map<String, Object?>,
        ),
        DateTime.parse(json[_savedAtKey]! as String),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saved placement status unreadable');
      return null;
    }
  }

  /// The saved status as it reads today. A wait that ran out while offline
  /// still says a day: only the server can say the test is open again.
  PlacementStatus? _savedStatus() {
    final saved = _savedModel();
    if (saved == null) return null;
    final (model, savedAt) = saved;
    final passed = max(0, _now().difference(savedAt).inDays);
    return switch (model.entity) {
      PlacementRetakeOpen(:final level, :final daysAgo) => PlacementRetakeOpen(
        level: level,
        daysAgo: daysAgo + passed,
      ),
      PlacementRetakeLocked(:final daysLeft) => PlacementRetakeLocked(
        daysLeft: max(1, daysLeft - passed),
      ),
      final status => status,
    };
  }

  static const _savedAtKey = 'savedAt';
  static const _statusKey = 'status';
}
