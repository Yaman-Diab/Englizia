import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/server_clock.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/data/datasources/unit_test_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/unit_test_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/unit_test.dart';
import 'package:englizia/features/lessons/domain/repositories/unit_test_repository.dart';

final class UnitTestRepositoryImpl implements UnitTestRepository {
  UnitTestRepositoryImpl(
    this._remote, {
    required SettingsStorageService settings,
    ServerClock? clock,
  }) : _settings = settings,
       _clock = clock;

  /// A level check that can't be answered any more: answered before, closed
  /// (the learner left the level, or the level suggested went), or unknown.
  static const _levelCheckGone = {
    ApiErrorCodes.levelCheckAlreadyChosen,
    ApiErrorCodes.levelCheckClosed,
    ApiErrorCodes.levelCheckNotFound,
  };

  final UnitTestRemoteDataSource _remote;
  final SettingsStorageService _settings;
  final ServerClock? _clock;

  /// Each test as it came, which its answers are built from.
  final _models = <String, UnitTestModel>{};

  @override
  Future<Result<UnitTest>> getTest(String testId) => guard(() async {
    final model = await _remote.getTest(testId);
    final test = model.toEntity(await _settings.installationId());
    _models[testId] = model;
    // A wait is about to be counted: on the server's time, asked for now.
    if (test.status.state == UnitTestState.cooldown) await _askTheTime();
    return test;
  });

  /// When the server can't be asked, the clock stands as it last heard.
  Future<void> _askTheTime() async {
    try {
      if (await _remote.serverTime() case final time?) _clock?.read(time);
    } on Exception catch (error) {
      AppLogger.warning('The server\'s time wasn\'t read: $error');
    }
  }

  @override
  Future<Result<UnitTestResult>> submit(
    UnitTest test,
    Map<String, ExerciseDraft> answers, {
    required String submissionId,
  }) => guard(() async {
    final model = _models[test.id];
    if (model == null) throw StateError('Unit test sent before it came');
    try {
      final answer = await _remote.submit(
        test.id,
        model.submission(answers, submissionId: submissionId),
      );
      // The wait before another try counts from the server's own time.
      if (answer.readDateTime('serverTime') case final time?) {
        _clock?.read(time);
      }
      return unitTestResultFromJson(
        answer,
        passPercent: test.status.passPercent,
      );
    } on ApiException catch (error) {
      // Too soon after a fail: the wait the server gives, as a wait.
      if (error.code != ApiErrorCodes.unitTestRetryNotYet) rethrow;
      throw ApiException(
        statusCode: ApiStatusCodes.tooManyRequests,
        code: error.code,
        retryAfter: error.retryAfter,
        traceId: error.traceId,
      );
    }
  });

  @override
  Future<Result<void>> chooseLevel(String suggestionId, {required bool move}) =>
      guard(() async {
        try {
          await _remote.chooseLevel(suggestionId, move: move);
        } on ApiException catch (error) {
          // Nothing is left to choose: the card goes, and the map says where
          // the learner stands.
          if (!_levelCheckGone.contains(error.code)) rethrow;
        }
      });
}
