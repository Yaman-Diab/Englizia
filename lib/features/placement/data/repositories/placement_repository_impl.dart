import 'dart:convert';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/models/placement_models.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';

/// The test as the server runs it (docs/api/placement.md): a stage's answers
/// stay on the phone until the stage ends and then go together, so a stage
/// that ends with no connection only waits, and sending it again is safe.
final class PlacementRepositoryImpl implements PlacementRepository {
  PlacementRepositoryImpl(
    this._remote, {
    required SettingsStorageService settings,
    required Future<bool> Function() hasSession,
    DateTime Function() now = DateTime.now,
  }) : _settings = settings,
       _hasSession = hasSession,
       _now = now;

  final PlacementRemoteDataSource _remote;
  final SettingsStorageService _settings;
  final Future<bool> Function() _hasSession;
  final DateTime Function() _now;

  String? _trackId;

  /// One read of the state for the screen's two questions at once.
  Future<PlacementStateModel>? _reading;

  /// The session as the server last gave it: its stage's questions.
  PlacementSessionModel? _session;

  static const _unavailable = ApiException(statusCode: ApiStatusCodes.notFound);

  @override
  void useTrack(String? trackId) => _trackId = trackId;

  Future<String> _track() async {
    if (_trackId case final id?) return id;
    final active = await _remote.activeTrackId();
    if (active == null) throw _unavailable;
    return _trackId = active;
  }

  /// Fresh from the server, and kept for an open with no connection.
  Future<PlacementStateModel> _state() => _reading ??= () async {
    // Before an account exists the server has nothing to say.
    if (!await _hasSession()) {
      throw const ApiException(statusCode: ApiStatusCodes.unauthorized);
    }
    final state = await _remote.getState(await _track());
    await _keepState(state);
    return state;
  }().whenComplete(() => _reading = null);

  @override
  Future<Result<PlacementSummary>> getSummary() => guard(() async {
    final state = await _state();
    if (state.unavailable) throw _unavailable;
    return state.summary;
  });

  @override
  Future<Result<PlacementStatus>> getStatus() async {
    final result = await guard(() async {
      final state = await _state();
      if (state.unavailable) throw _unavailable;
      return _statusOf(state);
    });
    if (result case Err(failure: NetworkFailure())) {
      if (_keptState() case final kept? when !kept.unavailable) {
        return Ok(_statusOf(kept));
      }
    }
    return result;
  }

  PlacementStatus _statusOf(PlacementStateModel state) => state.status(
    now: _now().toUtc(),
    answered: (session, stage) => _progress(session).keptOf(stage).length,
  );

  @override
  Future<Result<PlacementAttempt>> startAttempt() => guard(() async {
    final session = await _remote.startSession(await _track());
    _session = session;
    await _noteSize(session);
    return PlacementAttempt(
      id: session.id,
      stageSizes: await _sizes(session),
      stage: session.stage,
      answered: _progress(session.id).keptOf(session.stage).length,
    );
  });

  @override
  Future<Result<List<PlacementQuestion>>> getStage(
    String attemptId,
    int stage,
  ) => guard(() async {
    var session = _session;
    if (session == null || session.id != attemptId || session.stage != stage) {
      session = _session = await _remote.getSession(attemptId);
    }
    return session.questions(await _settings.installationId());
  });

  @override
  Future<void> saveAnswer(PlacementAnswer answer) async {
    final progress = _progress(answer.attemptId)
      ..kept.removeWhere((kept) => kept['questionId'] == answer.questionId)
      ..kept.add({
        'stage': answer.stage,
        'questionId': answer.questionId,
        'optionId': answer.optionId,
      });
    await _keepProgress(progress);
  }

  @override
  Future<Result<PlacementNextStage?>> completeStage(
    String attemptId,
    int stage,
  ) => guard(() async {
    final progress = _progress(attemptId);
    PlacementSessionModel session;
    try {
      session = await _remote.submitStage(
        attemptId,
        stage,
        progress.answersOf(stage),
      );
    } on ApiException catch (error) {
      if (error.code != ApiErrorCodes.placementStageNotCurrent) rethrow;
      // Sent before, or the session went on: it says where it stands.
      session = await _remote.getSession(attemptId);
      if (!session.completed && session.stage <= stage) rethrow;
    }
    _session = session;
    progress.kept.removeWhere((kept) => kept['stage'] == stage);
    await _keepProgress(progress);
    await _noteSize(session);
    final next = session.next;
    // A status kept from before names the stage just left behind.
    await _settings.clearPlacementStatus();
    if (next == null) await _settings.clearPlacementProgress();
    return next;
  });

  @override
  int unsentAnswers(String attemptId, int stage) =>
      _progress(attemptId).keptOf(stage).length;

  @override
  int playsUsed(String attemptId, String questionId) =>
      _progress(attemptId).plays[questionId] ?? 0;

  @override
  Future<void> savePlays(String attemptId, String questionId, int plays) async {
    final progress = _progress(attemptId);
    progress.plays[questionId] = plays;
    await _keepProgress(progress);
  }

  @override
  Future<Result<PlacementResult>> getResult(String attemptId) =>
      guard(() async {
        // Its levels are the track's, so they come with the state, not with
        // the session.
        final state = await _state();
        await _settings.clearPlacementProgress();
        return state.result;
      });

  @override
  Future<Result<void>> acceptLevel(String attemptId, {required bool lower}) =>
      guard(() async {
        final track = await _track();
        final choice = lower ? 'lower' : 'result';
        try {
          await _remote.choose(attemptId, track, choice);
        } on ApiException catch (error) {
          if (error.code != ApiErrorCodes.placementSessionNotLatest) rethrow;
          // A newer result is the one to choose from.
          final latest = (await _state()).resultSessionId;
          if (latest == null || latest == attemptId) rethrow;
          await _remote.choose(latest, track, choice);
        }
        await _settings.clearPlacementStatus();
      });

  @override
  Future<Result<void>> deferTest() async => const Ok(null);

  /// How many questions each stage has, known or estimated from the test's
  /// totals: the bar is drawn before the stages are seen.
  Future<List<int>> _sizes(PlacementSessionModel session) async {
    final sizes = _progress(session.id).sizes;
    final state = _keptState();
    final total = state?.questionsWithoutTiebreak ?? 0;
    final deciding = (state?.questionsWithTiebreak ?? 0) - total;
    int? known(int stage) => sizes['$stage'];
    final first =
        known(1) ?? (known(2) != null ? total - known(2)! : null) ?? total ~/ 2;
    final second = known(2) ?? total - first;
    return [first, second, if (session.stage >= 3) known(3) ?? deciding];
  }

  Future<void> _noteSize(PlacementSessionModel session) async {
    if (session.completed) return;
    final progress = _progress(session.id);
    progress.sizes['${session.stage}'] = session.questions('').length;
    await _keepProgress(progress);
  }

  /// What is kept for [attemptId]; anything kept for another one is over.
  PlacementProgressModel _progress(String attemptId) {
    final saved = PlacementProgressModel.decode(_settings.placementProgress);
    return saved?.attemptId == attemptId
        ? saved!
        : PlacementProgressModel(attemptId);
  }

  Future<void> _keepProgress(PlacementProgressModel progress) async {
    try {
      await _settings.setPlacementProgress(progress.encode());
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saving placement answers failed');
    }
  }

  Future<void> _keepState(PlacementStateModel state) async {
    try {
      await _settings.setPlacementStatus(jsonEncode(state.json));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saving the placement status failed');
    }
  }

  PlacementStateModel? _keptState() {
    final saved = _settings.placementStatus;
    if (saved == null) return null;
    try {
      return PlacementStateModel(
        (jsonDecode(saved) as Map).cast<String, Object?>(),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Saved placement status unreadable');
      return null;
    }
  }
}
