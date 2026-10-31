import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class ExerciseState extends Equatable {
  const ExerciseState({
    this.load = LoadStatus.loading,
    this.failure,
    this.lessonVersion = 0,
    this.xpPerAnswer,
    this.explainEnabled = false,
    this.questions = const [],
    this.index = 0,
    this.draft,
    this.evaluation,
    this.hintOpen = false,
    this.hinted = const {},
    this.done = const {},
    this.right = const {},
    this.uncounted = const {},
    this.pending = const {},
    this.outline = const LessonOutline(),
    this.audio = ClipStatus.idle,
    this.slow = false,
    this.clipLength = Duration.zero,
    this.playCount = 0,
    this.online = true,
    this.finished = false,
    this.speechOff = false,
  });

  final LoadStatus load;
  final Failure? failure;
  final int lessonVersion;
  final int? xpPerAnswer;
  final bool explainEnabled;
  final List<Exercise> questions;
  final int index;

  /// The answer so far. What only draws a question stays in its widget; what
  /// the button, the marks or the attempt need comes here.
  final ExerciseDraft? draft;

  /// What checking found: the answers are locked and marked.
  final Evaluation? evaluation;
  final bool hintOpen;

  /// Questions whose hint was opened: the button stays "used".
  final Set<String> hinted;

  /// Questions checked.
  final Set<String> done;

  /// Right at the first attempt.
  final Set<String> right;

  /// Skipped, so counted neither way (S §7.6).
  final Set<String> uncounted;

  /// Waiting for the server to judge them.
  final Set<String> pending;
  final LessonOutline outline;
  final ClipStatus audio;

  /// Playing at the slower speed.
  final bool slow;
  final Duration clipLength;

  /// Counts each start of a clip, so its progress ring starts over.
  final int playCount;

  /// With none, answers are kept on the phone and "check" still works.
  final bool online;

  /// The last question is done: the lesson's end follows.
  final bool finished;

  /// «لا أستطيع التحدث الآن»: no more speech questions in this lesson.
  final bool speechOff;

  Exercise? get question => index < questions.length ? questions[index] : null;

  bool get hintUsed => hinted.contains(question?.id);

  bool get checked => evaluation != null;

  bool get canCheck => (draft?.isComplete ?? false) && !checked;

  /// «تحقق» is under the question. Typing an answer that speaking would check
  /// by itself brings it back.
  bool get showsCheck =>
      !(question?.checksItself ?? false) ||
      switch (draft) {
        SpokenDraft(typed: true) => true,
        _ => false,
      };

  /// How far along the bar: this question counts once moved past, not when it
  /// is merely answered.
  int get position => finished ? questions.length : index;

  ExerciseState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    int? lessonVersion,
    int? xpPerAnswer,
    bool? explainEnabled,
    List<Exercise>? questions,
    int? index,
    ExerciseDraft? Function()? draft,
    Evaluation? Function()? evaluation,
    bool? hintOpen,
    Set<String>? hinted,
    Set<String>? done,
    Set<String>? right,
    Set<String>? uncounted,
    Set<String>? pending,
    LessonOutline? outline,
    ClipStatus? audio,
    bool? slow,
    Duration? clipLength,
    int? playCount,
    bool? online,
    bool? finished,
    bool? speechOff,
  }) => ExerciseState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    lessonVersion: lessonVersion ?? this.lessonVersion,
    xpPerAnswer: xpPerAnswer ?? this.xpPerAnswer,
    explainEnabled: explainEnabled ?? this.explainEnabled,
    questions: questions ?? this.questions,
    index: index ?? this.index,
    draft: draft != null ? draft() : this.draft,
    evaluation: evaluation != null ? evaluation() : this.evaluation,
    hintOpen: hintOpen ?? this.hintOpen,
    hinted: hinted ?? this.hinted,
    done: done ?? this.done,
    right: right ?? this.right,
    uncounted: uncounted ?? this.uncounted,
    pending: pending ?? this.pending,
    outline: outline ?? this.outline,
    audio: audio ?? this.audio,
    slow: slow ?? this.slow,
    clipLength: clipLength ?? this.clipLength,
    playCount: playCount ?? this.playCount,
    online: online ?? this.online,
    finished: finished ?? this.finished,
    speechOff: speechOff ?? this.speechOff,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    lessonVersion,
    xpPerAnswer,
    explainEnabled,
    questions,
    index,
    draft,
    evaluation,
    hintOpen,
    hinted,
    done,
    right,
    uncounted,
    pending,
    outline,
    audio,
    slow,
    clipLength,
    playCount,
    online,
    finished,
    speechOff,
  ];
}

/// A lesson's exercises (requirements v3.0 §7.1, design "Exercise"): one
/// question at a time, with no hearts, timer or points. It runs the session and
/// knows no template's details: a draft comes in, `evaluate` marks it, and the
/// attempt stays on the phone under a stable id, so the connection never stops
/// the learner.
class ExerciseCubit extends Cubit<ExerciseState> {
  ExerciseCubit(
    this._lessons,
    ClipPlayer player,
    this._connectivity,
    this._sounds, {
    required this.lessonId,
  }) : _clip = ClipPlayback(player),
       super(const ExerciseState());

  /// "Slower" plays the same file at this speed (S §7.3).
  static const slowSpeed = .75;

  final LessonRepository _lessons;
  final ClipPlayback _clip;
  final ConnectivityService _connectivity;
  final SoundPlayer _sounds;
  final String lessonId;
  StreamSubscription<bool>? _connection;
  final _clock = Stopwatch();
  var _secondsBefore = 0;

  int get _seconds => _secondsBefore + _clock.elapsed.inSeconds;

  /// What the lesson's end starts from.
  LessonSummary get summary => LessonSummary(
    lessonId: lessonId,
    lessonVersion: state.lessonVersion,
    rightFirstTime: state.right.length,
    counted: state.done.length - state.uncounted.length - state.pending.length,
    pending: state.pending.length,
    seconds: _seconds,
    outline: state.outline,
  );

  Future<void> start() async {
    _connection ??= _connectivity.onlineChanges.listen(_setOnline);
    final online = await _connectivity.isOnline();
    if (isClosed) return;
    emit(
      state.copyWith(
        online: online,
        load: LoadStatus.loading,
        failure: () => null,
      ),
    );
    final result = await _lessons.getLesson(lessonId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final lesson):
        final progress = _lessons.progress(lessonId);
        _secondsBefore = progress.seconds;
        _clock.start();
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            lessonVersion: lesson.version,
            xpPerAnswer: lesson.xpPerAnswer,
            explainEnabled: lesson.explainEnabled,
            questions: lesson.exercises,
            hinted: progress.hinted,
            done: progress.done,
            right: progress.right,
            uncounted: progress.uncounted,
            pending: progress.pending,
            outline: lesson.outline,
          ),
        );
        await _showFrom(0);
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  /// The first question from [from] not done yet, or the lesson's end.
  Future<void> _showFrom(int from) async {
    for (var i = from; i < state.questions.length; i++) {
      final candidate = state.questions[i];
      if (!state.done.contains(candidate.id) &&
          !(state.speechOff && candidate.isSpeech)) {
        emit(
          state.copyWith(
            index: i,
            draft: () => null,
            evaluation: () => null,
            hintOpen: false,
            audio: ClipStatus.idle,
            slow: false,
          ),
        );
        if (state.question?.autoplays ?? false) {
          unawaited(_play(slow: false));
        }
        return;
      }
    }
    await _lessons.clearProgress(lessonId);
    if (!isClosed) emit(state.copyWith(finished: true));
  }

  /// The answer changed. Locked once checked.
  void updateDraft(ExerciseDraft draft) {
    if (state.checked) return;
    emit(state.copyWith(draft: () => draft));
  }

  /// Opens or closes the hint; opening it once marks the question as helped.
  Future<void> toggleHint() async {
    final id = state.question?.id;
    if (id == null || state.question?.hint == null) return;
    final opening = !state.hintOpen;
    emit(
      state.copyWith(
        hintOpen: opening,
        hinted: opening ? {...state.hinted, id} : null,
      ),
    );
    if (opening) await _saveProgress();
  }

  /// «تحقق»: marks the answer, and keeps it. Leaving now returns to the next
  /// question, as this one has been answered. An order only the server can
  /// judge waits for it; without it, it stays to judge later, and isn't wrong.
  Future<void> check() async {
    final question = state.question;
    final draft = state.draft;
    if (question == null || draft == null || !state.canCheck) return;
    await stopAudio();
    if (question is SpeakAnswerExercise) return _reviewSpoken(question, draft);
    final found = evaluate(question, draft);
    // Not heard enough isn't wrong, and isn't done: there is another try.
    if (found is SpeechEvaluation && !found.correct) {
      emit(state.copyWith(evaluation: () => found));
      return;
    }
    final review = found is SequenceEvaluation && found.needsReview;
    emit(
      state.copyWith(
        evaluation: () => review ? const ReviewPending() : found,
        done: {...state.done, question.id},
        right: _rightAtFirst(found) ? {...state.right, question.id} : null,
        pending: review ? {...state.pending, question.id} : null,
      ),
    );
    if (!review) _sayVerdict(found);
    await _saveProgress();
    final attempt = ExerciseAttempt(
      lessonId: lessonId,
      lessonVersion: state.lessonVersion,
      questionId: question.id,
      draft: draft,
      hinted: state.hintUsed,
    );
    final attemptId = await _lessons.saveAttempt(attempt);
    if (!review) return;
    final result = await _lessons.reviewAttempt(attempt, attemptId);
    if (isClosed) return;
    final Evaluation judged = switch (result) {
      Ok(value: true) => SequenceEvaluation(
        words: [for (final _ in found.words) true],
        correct: true,
      ),
      Ok() => SequenceEvaluation(words: found.words, correct: false),
      Err() => const ReviewLater(),
    };
    emit(
      state.copyWith(
        evaluation: () => judged,
        right: judged.correct ? {...state.right, question.id} : null,
        pending: judged is ReviewLater
            ? null
            : ({...state.pending}..remove(question.id)),
      ),
    );
    if (judged is! ReviewLater) _sayVerdict(judged);
    await _saveProgress();
  }

  /// The server's AI judges the learner's own words. Answering something else
  /// isn't an answer, so the question stays; all else moves on, and an answer it
  /// couldn't judge now is judged later, and never counts as wrong.
  Future<void> _reviewSpoken(
    SpeakAnswerExercise question,
    ExerciseDraft draft,
  ) async {
    emit(state.copyWith(evaluation: () => evaluate(question, draft)));
    final result = await _lessons.reviewSpoken(
      ExerciseAttempt(
        lessonId: lessonId,
        lessonVersion: state.lessonVersion,
        questionId: question.id,
        draft: draft,
        hinted: state.hintUsed,
      ),
    );
    if (isClosed) return;
    final judged = switch (result) {
      Ok(:final value) => value,
      Err() => const ReviewLater(),
    };
    if (judged is SpokenOffTopic) {
      emit(state.copyWith(evaluation: () => judged));
      return;
    }
    emit(
      state.copyWith(
        evaluation: () => judged,
        done: {...state.done, question.id},
        right: judged is SpokenAnswered ? {...state.right, question.id} : null,
        uncounted: judged is ReviewQuotaOut
            ? {...state.uncounted, question.id}
            : null,
        pending: judged is ReviewLater ? {...state.pending, question.id} : null,
      ),
    );
    if (judged is SpokenAnswered) _sayVerdict(judged);
    await _saveProgress();
  }

  /// A matching is right in the end whatever happened on the way.
  bool _rightAtFirst(Evaluation found) => switch (found) {
    PairsEvaluation(:final mistakes) => mistakes.isEmpty,
    _ => found.correct,
  };

  void _sayVerdict(Evaluation evaluation) {
    unawaited(
      _sounds.play(evaluation.correct ? AppSound.correct : AppSound.incorrect),
    );
  }

  /// «أعد المحاولة» on a sentence not heard well enough, or an answer off topic.
  void retrySpeech() =>
      emit(state.copyWith(draft: () => null, evaluation: () => null));

  /// «تخطَّ»: moves on with nothing counted or sent (S §7.5).
  Future<void> skipQuestion() async {
    final question = state.question;
    if (question == null) return;
    await stopAudio();
    emit(
      state.copyWith(
        done: {...state.done, question.id},
        uncounted: {...state.uncounted, question.id},
      ),
    );
    await _saveProgress();
    await _showFrom(state.index + 1);
  }

  /// «لا أستطيع التحدث الآن»: skips the speech questions of this lesson only.
  Future<void> skipSpeech() async {
    await stopAudio();
    emit(state.copyWith(speechOff: true));
    await _showFrom(state.index + 1);
  }

  /// Sends a problem with this question, with the answer given (S §18).
  Future<void> report(ProblemReason reason) async {
    final question = state.question;
    if (question == null) return;
    await _lessons.saveReport(
      ExerciseReport(
        lessonId: lessonId,
        lessonVersion: state.lessonVersion,
        questionId: question.id,
        reason: reason,
        draft: state.draft,
      ),
    );
  }

  /// «التالي», after checking.
  Future<void> next() async {
    if (!state.checked) return;
    await stopAudio();
    await _showFrom(state.index + 1);
  }

  Future<void> _saveProgress() => _lessons.saveProgress(
    lessonId,
    ExerciseProgress(
      done: state.done,
      hinted: state.hinted,
      right: state.right,
      uncounted: state.uncounted,
      pending: state.pending,
      seconds: _seconds,
    ),
  );

  /// The big button: plays the clip, or stops it.
  Future<void> togglePlay() async {
    if (state.audio == ClipStatus.playing) {
      await stopAudio();
    } else if (state.audio != ClipStatus.loading) {
      await _play(slow: false);
    }
  }

  /// «أبطأ»: the same file, slower, from its start.
  Future<void> playSlow() async {
    if (state.audio == ClipStatus.loading) return;
    await stopAudio();
    await _play(slow: true);
  }

  /// The feedback's button: says the right sentence, or stops.
  Future<void> toggleAnswerClip() async {
    if (state.audio == ClipStatus.playing) {
      await stopAudio();
    } else if (state.audio != ClipStatus.loading) {
      await _play(slow: false, url: state.question?.answerClipUrl);
    }
  }

  Future<void> _play({required bool slow, String? url}) async {
    final question = state.question;
    final clip = url ?? question?.clipUrl;
    if (question == null || clip == null) return;
    emit(state.copyWith(audio: ClipStatus.loading, slow: slow));
    final outcome = await _clip.start(
      clip,
      speed: slow ? slowSpeed : 1,
      onEnd: () {
        if (!isClosed) {
          emit(state.copyWith(audio: ClipStatus.idle, slow: false));
        }
      },
    );
    if (isClosed) return;
    switch (outcome) {
      case ClipCancelled():
        return;
      case ClipUnavailable():
        // Never stops the answer: the options stay open (S §7.1).
        emit(
          state.copyWith(
            audio: question.reportsClipFailure
                ? ClipStatus.failed
                : ClipStatus.idle,
            slow: false,
          ),
        );
      case ClipPlaying(:final length):
        emit(
          state.copyWith(
            audio: ClipStatus.playing,
            clipLength: length,
            playCount: state.playCount + 1,
          ),
        );
    }
  }

  /// Stops any clip, as the exit sheet does on opening.
  Future<void> stopAudio() async {
    _clip.stop();
    if (state.audio == ClipStatus.playing ||
        state.audio == ClipStatus.loading) {
      emit(state.copyWith(audio: ClipStatus.idle, slow: false));
    }
  }

  void _setOnline(bool online) {
    if (!isClosed) emit(state.copyWith(online: online));
  }

  @override
  Future<void> close() async {
    _clip.stop();
    await _connection?.cancel();
    return super.close();
  }
}
