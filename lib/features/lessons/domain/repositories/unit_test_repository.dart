import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/unit_test.dart';

abstract interface class UnitTestRepository {
  /// The test with its questions. Online only: it isn't kept on the phone.
  Future<Result<UnitTest>> getTest(String testId);

  /// Sends the whole test, one answer for each question by its id, under
  /// [submissionId], the same on every resend of this try.
  Future<Result<UnitTestResult>> submit(
    UnitTest test,
    Map<String, ExerciseDraft> answers, {
    required String submissionId,
  });

  /// «انتقل» ([move]) or «ابقَ» on a suggested level.
  Future<Result<void>> chooseLevel(String suggestionId, {required bool move});
}
