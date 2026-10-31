import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';

abstract interface class LessonRepository {
  /// The lesson with its exercises and keys.
  Future<Result<Lesson>> getLesson(String lessonId);

  /// Keeps the answer on the phone and sends it when it can, under a stable
  /// attempt id, so the server ignores a repeat. Never fails.
  Future<void> saveAttempt(ExerciseAttempt attempt);

  /// Sends what the phone kept, as when the connection is back.
  Future<void> sendSaved();

  ExerciseProgress progress(String lessonId);

  Future<void> saveProgress(String lessonId, ExerciseProgress progress);

  /// The lesson's exercises are done: it starts over if opened again.
  Future<void> clearProgress(String lessonId);
}
