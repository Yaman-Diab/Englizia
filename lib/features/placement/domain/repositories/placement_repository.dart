import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';

abstract interface class PlacementRepository {
  /// The track the test is for, from here on; null is the learner's active
  /// one. The test and its result are the account's, but each track has its
  /// own levels to start from.
  void useTrack(String? trackId);

  /// The published placement test, as introduced to the learner. Needs an
  /// account: before one, `UnauthorizedFailure` with no request.
  Future<Result<PlacementSummary>> getSummary();

  /// Where this account stands with the test. With no connection, the last
  /// status this account got on this phone, its days brought up to date;
  /// `NetworkFailure` only when there is none.
  Future<Result<PlacementStatus>> getStatus();

  /// The attempt to carry on with: the unfinished one, or a new one.
  Future<Result<PlacementAttempt>> startAttempt();

  /// All the questions of [stage], so a stage can't stop halfway for lack of a
  /// connection.
  Future<Result<List<PlacementQuestion>>> getStage(String attemptId, int stage);

  /// Keeps the answer on the phone: the server hears of a stage only when it
  /// ends. Never fails.
  Future<void> saveAnswer(PlacementAnswer answer);

  /// Sends [stage]'s answers and closes it. Returns what follows, or null when
  /// the test is over. `NetworkFailure` keeps everything for a retry; sending
  /// the same stage again is safe.
  Future<Result<PlacementNextStage?>> completeStage(
    String attemptId,
    int stage,
  );

  /// Answers of [stage] kept on the phone, not on the server yet: where the
  /// stage carries on.
  int unsentAnswers(String attemptId, int stage);

  /// How often the clip of [questionId] was played, as stopping the test
  /// doesn't give those back.
  int playsUsed(String attemptId, String questionId);

  Future<void> savePlays(String attemptId, String questionId, int plays);

  /// The result of a finished attempt, marked by the server.
  Future<Result<PlacementResult>> getResult(String attemptId);

  /// Starts the learner from the level measured, or from the one below it.
  Future<Result<void>> acceptLevel(String attemptId, {required bool lower});

  /// Puts the test off: the learner is already at the track's first level,
  /// and the test stays available. Nothing to tell the server.
  Future<Result<void>> deferTest();
}
