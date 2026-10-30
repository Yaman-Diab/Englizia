import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';

abstract interface class LessonRepository {
  /// The lesson's questions, with their keys.
  Future<Result<List<Exercise>>> getExercises(String lessonId);

  /// Keeps the answer on the phone and sends it when it can, under a stable
  /// attempt id, so the server ignores a repeat. Never fails.
  Future<void> saveAnswer(ExerciseAnswer answer);

  /// Sends what the phone kept, as when the connection is back.
  Future<void> sendSaved();

  ExerciseProgress progress(String lessonId);

  Future<void> saveProgress(String lessonId, ExerciseProgress progress);

  /// The lesson's exercises are done: it starts over if opened again.
  Future<void> clearProgress(String lessonId);
}
