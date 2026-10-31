import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/grammar_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';

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

  /// Tells the server the lesson is done, once it has the answers, and returns
  /// its official numbers. When it can't be reached the completion stays on the
  /// phone with the answers, and the failure says so.
  Future<Result<LessonResult>> completeLesson(LessonSummary summary);

  /// How far this phone watched the lesson's video.
  WatchState? savedWatch(String lessonId);

  Future<void> saveWatch(String lessonId, WatchState watch);

  /// Tells the server when it can. Only the latest counts, so it replaces any
  /// earlier one still waiting.
  Future<void> sendWatch(String lessonId, int lessonVersion, WatchState watch);

  VideoQuality get videoQuality;

  Future<void> setVideoQuality(VideoQuality quality);

  ReaderPrefs get readerPrefs;

  Future<void> setReaderPrefs(ReaderPrefs prefs);

  bool get readerTipSeen;

  Future<void> setReaderTipSeen();

  /// Ids of the spans saved from this lesson.
  Set<String> savedWords(String lessonId);

  /// Keeps it on the phone and tells the server when it can.
  Future<void> setWordSaved(SavedWord word, {required bool saved});

  /// The lesson's content was finished. Kept and sent like an answer.
  Future<void> sendContentDone(String lessonId, int lessonVersion);

  /// Keeps the report on the phone and sends it when it can. Never fails.
  Future<void> saveReport(ExerciseReport report);

  /// Sends what the phone kept, as when the connection is back.
  Future<void> sendSaved();

  ExerciseProgress progress(String lessonId);

  Future<void> saveProgress(String lessonId, ExerciseProgress progress);

  /// The lesson's exercises are done: it starts over if opened again.
  Future<void> clearProgress(String lessonId);
}
