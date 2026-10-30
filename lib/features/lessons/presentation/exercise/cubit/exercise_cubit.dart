import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class ExerciseState extends Equatable {
  const ExerciseState({
    this.load = LoadStatus.loading,
    this.failure,
    this.lessonVersion = 0,
    this.questions = const [],
    this.index = 0,
    this.draft,
    this.evaluation,
    this.hintOpen = false,
    this.hinted = const {},
    this.done = const {},
    this.audio = ClipStatus.idle,
    this.slow = false,
    this.clipLength = Duration.zero,
    this.playCount = 0,
    this.online = true,
    this.finished = false,
  });

  final LoadStatus load;
  final Failure? failure;
  final int lessonVersion;
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

  Exercise? get question => index < questions.length ? questions[index] : null;

  bool get hintUsed => hinted.contains(question?.id);

  bool get checked => evaluation != null;

  bool get canCheck => (draft?.isComplete ?? false) && !checked;

  /// How far along the bar: this question counts once moved past, not when it
  /// is merely answered.
  int get position => finished ? questions.length : index;

  ExerciseState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    int? lessonVersion,
    List<Exercise>? questions,
    int? index,
    ExerciseDraft? Function()? draft,
    Evaluation? Function()? evaluation,
    bool? hintOpen,
    Set<String>? hinted,
    Set<String>? done,
    ClipStatus? audio,
    bool? slow,
    Duration? clipLength,
    int? playCount,
    bool? online,
    bool? finished,
  }) => ExerciseState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    lessonVersion: lessonVersion ?? this.lessonVersion,
    questions: questions ?? this.questions,
    index: index ?? this.index,
    draft: draft != null ? draft() : this.draft,
    evaluation: evaluation != null ? evaluation() : this.evaluation,
    hintOpen: hintOpen ?? this.hintOpen,
    hinted: hinted ?? this.hinted,
    done: done ?? this.done,
    audio: audio ?? this.audio,
    slow: slow ?? this.slow,
    clipLength: clipLength ?? this.clipLength,
    playCount: playCount ?? this.playCount,
    online: online ?? this.online,
    finished: finished ?? this.finished,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    lessonVersion,
    questions,
    index,
    draft,
    evaluation,
    hintOpen,
    hinted,
    done,
    audio,
    slow,
    clipLength,
    playCount,
    online,
    finished,
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
    this._connectivity, {
    required this.lessonId,
  }) : _clip = ClipPlayback(player),
       super(const ExerciseState());

  /// "Slower" plays the same file at this speed (S §7.3).
  static const slowSpeed = .75;

  final LessonRepository _lessons;
  final ClipPlayback _clip;
  final ConnectivityService _connectivity;
  final String lessonId;
  StreamSubscription<bool>? _connection;

  Future<void> start() async {
    _connection ??= _connectivity.onlineChanges.listen(_setOnline);
    final online = await _connectivity.isOnline();
    if (isClosed) return;
    if (online) unawaited(_lessons.sendSaved());
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
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            lessonVersion: lesson.version,
            questions: lesson.exercises,
            hinted: progress.hinted,
            done: progress.done,
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
      if (!state.done.contains(state.questions[i].id)) {
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
  /// question, as this one has been answered.
  Future<void> check() async {
    final question = state.question;
    final draft = state.draft;
    if (question == null || draft == null || !state.canCheck) return;
    await stopAudio();
    emit(
      state.copyWith(
        evaluation: () => evaluate(question, draft),
        done: {...state.done, question.id},
      ),
    );
    await _saveProgress();
    await _lessons.saveAttempt(
      ExerciseAttempt(
        lessonId: lessonId,
        lessonVersion: state.lessonVersion,
        questionId: question.id,
        draft: draft,
        hinted: state.hintUsed,
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
    ExerciseProgress(done: state.done, hinted: state.hinted),
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

  Future<void> _play({required bool slow}) async {
    final question = state.question;
    final url = question?.clipUrl;
    if (question == null || url == null) return;
    emit(state.copyWith(audio: ClipStatus.loading, slow: slow));
    final outcome = await _clip.start(
      url,
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
    if (isClosed) return;
    emit(state.copyWith(online: online));
    if (online) unawaited(_lessons.sendSaved());
  }

  @override
  Future<void> close() async {
    _clip.stop();
    await _connection?.cancel();
    return super.close();
  }
}
