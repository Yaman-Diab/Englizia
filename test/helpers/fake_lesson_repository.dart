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

/// The example's questions, each with its options in the order written, which
/// the app's own order would otherwise hide from a test.
List<Exercise> sampleExercises() {
  final lesson = LessonModel(sampleLessonJson()).toEntity('seed');
  final written = {
    for (final q in sampleLessonJson().readList('exercises')!)
      asJsonMap(q).readString('id'): [
        for (final o in asJsonMap(q).readList('options')!)
          asJsonMap(o).readString('id'),
      ],
  };
  return [
    for (final exercise in lesson.exercises)
      _inOrder(exercise, written[exercise.id]!),
  ];
}

Exercise _inOrder(Exercise exercise, List<String?> ids) {
  final options = switch (exercise) {
    final ChoiceExercise e => [
      for (final id in ids) e.options.firstWhere((o) => o.id == id),
    ],
  };
  return switch (exercise) {
    final MultipleChoiceExercise e => MultipleChoiceExercise(
      id: e.id,
      instruction: e.instruction,
      options: options,
      answerId: e.answerId,
      before: e.before,
      after: e.after,
      hint: e.hint,
      bookReference: e.bookReference,
    ),
    final ImageChoiceExercise e => ImageChoiceExercise(
      id: e.id,
      instruction: e.instruction,
      options: options,
      answerId: e.answerId,
      word: e.word,
      audioUrl: e.audioUrl,
      hint: e.hint,
      bookReference: e.bookReference,
    ),
    final ListenChooseExercise e => ListenChooseExercise(
      id: e.id,
      instruction: e.instruction,
      options: options,
      answerId: e.answerId,
      audioUrl: e.audioUrl,
      hint: e.hint,
      bookReference: e.bookReference,
    ),
  };
}

class FakeLessonRepository implements LessonRepository {
  FakeLessonRepository({List<Exercise>? exercises, this.failure})
    : exercises = exercises ?? sampleExercises();

  static const version = 3;

  List<Exercise> exercises;
  Failure? failure;
  final attempts = <ExerciseAttempt>[];
  final saved = <String, ExerciseProgress>{};
  var sends = 0;
  var cleared = 0;

  @override
  Future<Result<Lesson>> getLesson(String lessonId) async {
    final failure = this.failure;
    return failure == null
        ? Ok(Lesson(id: lessonId, version: version, exercises: exercises))
        : Err(failure);
  }

  @override
  Future<void> saveAttempt(ExerciseAttempt attempt) async =>
      attempts.add(attempt);

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
