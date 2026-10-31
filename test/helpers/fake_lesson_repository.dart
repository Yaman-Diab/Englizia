import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';

/// The contract's example lesson as it came, with each template in it.
Map<String, Object?> sampleLessonJson() => asJsonMap(
  ApiClient.unwrap(
    jsonDecode(File(LessonFakeDataSource.asset).readAsStringSync()),
  ),
);

/// The example's questions.
List<Exercise> sampleExercises() =>
    LessonModel(sampleLessonJson()).toEntity('seed').exercises;

/// Only the first choice templates of the example.
List<Exercise> sampleChoiceExercises() => sampleExercises()
    .whereType<ChoiceExercise>()
    .where((e) => e is! DialogueExercise && e is! ReadingExercise)
    .toList();

class FakeLessonRepository implements LessonRepository {
  FakeLessonRepository({List<Exercise>? exercises, this.failure})
    : exercises = exercises ?? sampleExercises();

  static const version = 3;

  List<Exercise> exercises;
  Failure? failure;
  final attempts = <ExerciseAttempt>[];
  final reviews = <String>[];
  final reports = <ExerciseReport>[];

  /// What the server says of an order it judges.
  Result<bool> review = const Ok(true);

  /// What the server's AI says of the learner's own words.
  Result<Evaluation> spokenReview = const Ok(
    SpokenAnswered(note: 'A note.', better: 'A better way.'),
  );
  final spokenReviews = <ExerciseAttempt>[];

  /// When set, a review waits for it.
  Future<void>? reviewGate;
  int? xpPerAnswer;
  bool explainEnabled = false;
  final saved = <String, ExerciseProgress>{};
  var sends = 0;
  var cleared = 0;

  @override
  Future<Result<Lesson>> getLesson(String lessonId) async {
    final failure = this.failure;
    return failure == null
        ? Ok(
            Lesson(
              id: lessonId,
              version: version,
              exercises: exercises,
              xpPerAnswer: xpPerAnswer,
              explainEnabled: explainEnabled,
            ),
          )
        : Err(failure);
  }

  @override
  Future<String> saveAttempt(ExerciseAttempt attempt) async {
    attempts.add(attempt);
    return 'attempt-${attempts.length}';
  }

  @override
  Future<Result<Evaluation>> reviewSpoken(ExerciseAttempt attempt) async {
    spokenReviews.add(attempt);
    await reviewGate;
    return spokenReview;
  }

  @override
  Future<Result<bool>> reviewAttempt(
    ExerciseAttempt attempt,
    String attemptId,
  ) async {
    reviews.add(attemptId);
    await reviewGate;
    return review;
  }

  @override
  Future<void> saveReport(ExerciseReport report) async => reports.add(report);

  @override
  Future<void> sendSaved() async => sends++;

  @override
  ExerciseProgress progress(String lessonId) =>
      saved[lessonId] ?? const ExerciseProgress();

  @override
  Future<void> saveProgress(String lessonId, ExerciseProgress progress) async =>
      saved[lessonId] = progress;

  @override
  Future<void> clearProgress(String lessonId) async {
    cleared++;
    saved.remove(lessonId);
  }
}
