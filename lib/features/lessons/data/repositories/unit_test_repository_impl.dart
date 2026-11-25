import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
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
  }) : _settings = settings;

  final UnitTestRemoteDataSource _remote;
  final SettingsStorageService _settings;

  /// Each test as it came, which its answers are built from.
  final _models = <String, UnitTestModel>{};

  @override
  Future<Result<UnitTest>> getTest(String testId) => guard(() async {
    final model = await _remote.getTest(testId);
    final test = model.toEntity(await _settings.installationId());
    _models[testId] = model;
    return test;
  });

  @override
  Future<Result<UnitTestResult>> submit(
    UnitTest test,
    Map<String, ExerciseDraft> answers, {
    required String submissionId,
  }) => guard(() async {
    final model = _models[test.id];
    if (model == null) throw StateError('Unit test sent before it came');
    try {
      return unitTestResultFromJson(
        await _remote.submit(
          test.id,
          model.submission(answers, submissionId: submissionId),
        ),
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
      guard(() => _remote.chooseLevel(suggestionId, move: move));
}
