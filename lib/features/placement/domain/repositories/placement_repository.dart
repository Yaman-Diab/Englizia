import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';

abstract interface class PlacementRepository {
  /// The published placement test, as introduced to the learner.
  Future<Result<PlacementSummary>> getSummary();

  /// Where this account stands with the test. With no connection, the last
  /// status this account got on this phone, its days brought up to date;
  /// `NetworkFailure` only when there is none.
  Future<Result<PlacementStatus>> getStatus();

  /// Throws away the unfinished test, so the questions begin a new one.
  Future<Result<void>> restartTest();

  /// The attempt to carry on with: the unfinished one, or a new one.
  Future<Result<PlacementAttempt>> startAttempt();

  /// All the questions of [stage], so a stage can't stop halfway for lack of a
  /// connection.
  Future<Result<List<PlacementQuestion>>> getStage(String attemptId, int stage);

  /// Keeps the answer on the phone and sends it when it can, under a stable id
  /// so it never counts twice. Never fails: [completeStage] reports what
  /// could not be sent.
  Future<void> saveAnswer(PlacementAnswer answer);

  /// Sends what is left of [stage] and closes it. Returns what follows, or
  /// null when the test is over. `NetworkFailure` keeps everything for a retry.
  Future<Result<PlacementNextStage?>> completeStage(
    String attemptId,
    int stage,
  );

  /// Answers of [stage] kept on the phone, not on the server yet.
  int unsentAnswers(String attemptId, int stage);

  /// How often the clip of [questionId] was played, as stopping the test
  /// doesn't give those back.
  int playsUsed(String attemptId, String questionId);

  Future<void> savePlays(String attemptId, String questionId, int plays);

  /// Puts the test off: the learner starts from the track's first level, and
  /// the test stays available.
  Future<Result<void>> deferTest();
}
