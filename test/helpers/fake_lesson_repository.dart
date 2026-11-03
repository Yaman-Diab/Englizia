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
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/kid_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/entities/vocabulary.dart';
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

/// The mock kids' lesson as it came.
Map<String, Object?> kidLessonJson() => asJsonMap(
  ApiClient.unwrap(
    jsonDecode(File(LessonFakeDataSource.kidAsset).readAsStringSync()),
  ),
);

/// The mock kids' lesson.
Lesson kidLesson() => LessonModel(kidLessonJson()).toEntity('seed');

/// The mock kids' lesson of a story, a song, a dialogue and a word to say.
Lesson kidMediaLesson() => LessonModel(
  asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(LessonFakeDataSource.kidMediaAsset).readAsStringSync()),
    ),
  ),
).toEntity('seed');

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

  /// What the server says when a lesson is completed.
  Result<LessonResult> completion = const Ok(LessonResult(xp: 15));
  final completions = <LessonSummary>[];

  /// When set, completing a lesson waits for it.
  Future<void>? completionGate;

  /// When set, a review waits for it.
  Future<void>? reviewGate;
  int? xpPerAnswer;
  LessonOutline outline = const LessonOutline();
  GrammarContent? grammar;
  ReaderContent? reader;
  VocabContent? vocabulary;
  KidLesson? kids;
  final vocabSent = <(VocabWord, bool)>[];
  final shadowingScores = <ShadowingScore>[];
  ReaderPrefs prefs = const ReaderPrefs();
  bool tipSeen = true;
  final savedWordIds = <String>{};
  final wordsSent = <(SavedWord, bool)>[];
  var contentDone = 0;
  final watches = <String, WatchState>{};
  final watchesSent = <WatchState>[];
  VideoQuality quality = VideoQuality.auto;
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
              outline: outline,
              grammar: grammar,
              reader: reader,
              vocabulary: vocabulary,
              kids: kids,
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
  ReaderPrefs get readerPrefs => prefs;

  @override
  Future<void> setReaderPrefs(ReaderPrefs prefs) async => this.prefs = prefs;

  @override
  bool get readerTipSeen => tipSeen;

  @override
  Future<void> setReaderTipSeen() async => tipSeen = true;

  @override
  Set<String> savedWords(String lessonId) => savedWordIds;

  @override
  Future<void> setWordSaved(SavedWord word, {required bool saved}) async =>
      wordsSent.add((word, saved));

  @override
  Future<void> setVocabSaved(
    String lessonId,
    VocabWord word, {
    required bool saved,
  }) async => vocabSent.add((word, saved));

  @override
  Future<void> saveShadowingScore(ShadowingScore score) async =>
      shadowingScores.add(score);

  @override
  Future<void> sendContentDone(String lessonId, int lessonVersion) async =>
      contentDone++;

  @override
  WatchState? savedWatch(String lessonId) => watches[lessonId];

  @override
  Future<void> saveWatch(String lessonId, WatchState watch) async =>
      watches[lessonId] = watch;

  @override
  Future<void> sendWatch(
    String lessonId,
    int lessonVersion,
    WatchState watch,
  ) async => watchesSent.add(watch);

  @override
  VideoQuality get videoQuality => quality;

  @override
  Future<void> setVideoQuality(VideoQuality quality) async =>
      this.quality = quality;

  @override
  Future<Result<LessonResult>> completeLesson(LessonSummary summary) async {
    completions.add(summary);
    await completionGate;
    return completion;
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
