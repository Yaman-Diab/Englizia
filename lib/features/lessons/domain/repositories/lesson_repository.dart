import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';

abstract interface class LessonRepository {
  /// The lesson with its exercises and keys.
  Future<Result<Lesson>> getLesson(String lessonId);

  /// Keeps the answer on the phone and sends it when it can, under a stable
  /// attempt id, so the server ignores a repeat. Never fails. Returns that id.
  Future<String> saveAttempt(ExerciseAttempt attempt);

  /// Asks the server to judge what the phone can't: true when it is right.
  Future<Result<bool>> reviewAttempt(ExerciseAttempt attempt, String attemptId);

  /// Asks the server's AI to judge the learner's own words: [SpokenAnswered],
  /// [SpokenOffTopic] or [ReviewQuotaOut]. When it can't, the answer stays on the
  /// phone to be judged later, and the failure says so.
  Future<Result<Evaluation>> reviewSpoken(ExerciseAttempt attempt);

  /// Keeps the report on the phone and sends it when it can. Never fails.
  Future<void> saveReport(ExerciseReport report);

  /// Sends what the phone kept, as when the connection is back.
  Future<void> sendSaved();

  ExerciseProgress progress(String lessonId);

  Future<void> saveProgress(String lessonId, ExerciseProgress progress);

  /// The lesson's exercises are done: it starts over if opened again.
  Future<void> clearProgress(String lessonId);
}
