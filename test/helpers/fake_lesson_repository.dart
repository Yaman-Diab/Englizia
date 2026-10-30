import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/exercise_model.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';

/// The contract's example lesson: multiple choice, picture, listening, and a
/// long multiple choice with a book reference.
List<Exercise> sampleExercises() => exercisesFromJson(
  asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(LessonFakeDataSource.asset).readAsStringSync()),
    ),
  ),
);

class FakeLessonRepository implements LessonRepository {
  FakeLessonRepository({List<Exercise>? exercises, this.failure})
    : exercises = exercises ?? sampleExercises();

  List<Exercise> exercises;
  Failure? failure;
  final answers = <ExerciseAnswer>[];
  final saved = <String, ExerciseProgress>{};
  var sends = 0;
  var cleared = 0;

  @override
  Future<Result<List<Exercise>>> getExercises(String lessonId) async {
    final failure = this.failure;
    return failure == null ? Ok(exercises) : Err(failure);
  }

  @override
  Future<void> saveAnswer(ExerciseAnswer answer) async => answers.add(answer);

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
