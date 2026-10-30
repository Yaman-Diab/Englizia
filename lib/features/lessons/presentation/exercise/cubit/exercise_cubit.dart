import 'dart:async';

import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ExerciseAudio { idle, loading, playing, failed }

final class ExerciseState extends Equatable {
  const ExerciseState({
    this.load = LoadStatus.loading,
    this.failure,
    this.questions = const [],
    this.index = 0,
    this.selectedId,
    this.checked = false,
    this.hintOpen = false,
    this.hinted = const {},
    this.audio = ExerciseAudio.idle,
    this.slow = false,
    this.clipLength = Duration.zero,
    this.playCount = 0,
    this.online = true,
    this.finished = false,
  });

  final LoadStatus load;
  final Failure? failure;
  final List<Exercise> questions;
  final int index;
  final String? selectedId;

  /// The answer is in: the options are locked and marked.
  final bool checked;
  final bool hintOpen;

  /// Questions whose hint was opened: the button stays "used".
  final Set<String> hinted;
  final ExerciseAudio audio;

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

  ExerciseOption? get selected {
    for (final option in question?.options ?? const <ExerciseOption>[]) {
      if (option.id == selectedId) return option;
    }
    return null;
  }

  bool get canCheck => selectedId != null && !checked;

  /// Questions done, for the bar: this one counts once it is checked and moved
  /// past, not when it is merely answered.
  int get done => finished ? questions.length : index;

  ExerciseState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    List<Exercise>? questions,
    int? index,
    String? Function()? selectedId,
    bool? checked,
    bool? hintOpen,
    Set<String>? hinted,
    ExerciseAudio? audio,
    bool? slow,
    Duration? clipLength,
    int? playCount,
    bool? online,
    bool? finished,
  }) => ExerciseState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    questions: questions ?? this.questions,
    index: index ?? this.index,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
    checked: checked ?? this.checked,
    hintOpen: hintOpen ?? this.hintOpen,
    hinted: hinted ?? this.hinted,
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
    questions,
    index,
    selectedId,
    checked,
    hintOpen,
    hinted,
    audio,
    slow,
    clipLength,
    playCount,
    online,
    finished,
  ];
}

/// A lesson's exercises (requirements v3.0 §7.1, design "Exercise"): one
/// question at a time, with no hearts, timer or points. Answers are marked here,
/// as the keys come with the lesson, and kept on the phone under a stable id, so
/// the connection never stops the learner.
class ExerciseCubit extends Cubit<ExerciseState> {
  ExerciseCubit(
    this._lessons,
    this._player,
    this._connectivity, {
    required this.lessonId,
  }) : super(const ExerciseState());

  /// "Slower" plays the same file at this speed (S §7.3).
  static const slowSpeed = .75;

  final LessonRepository _lessons;
  final ClipPlayer _player;
  final ConnectivityService _connectivity;
  final String lessonId;
  StreamSubscription<bool>? _connection;
  Timer? _clipEnd;

  /// Changes with each question and stop, so a clip still loading can't play.
  var _clipToken = 0;

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
    final result = await _lessons.getExercises(lessonId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final progress = _lessons.progress(lessonId);
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            questions: value,
            hinted: progress.hinted,
          ),
        );
        if (value.isEmpty || progress.position >= value.length) {
          await _finish();
        } else {
          _show(progress.position);
        }
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  void _show(int index) {
    emit(
      state.copyWith(
        index: index,
        selectedId: () => null,
        checked: false,
        hintOpen: false,
        audio: ExerciseAudio.idle,
        slow: false,
      ),
    );
    // A listening question plays once by itself (S §7.3).
    if (state.question?.kind == ExerciseKind.listeningChoice) {
      unawaited(_play(slow: false));
    }
  }

  void select(String optionId) {
    if (state.checked) return;
    emit(state.copyWith(selectedId: () => optionId));
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

  /// «تحقق»: locks the options, and keeps the answer.
  Future<void> check() async {
    final question = state.question;
    final selectedId = state.selectedId;
    if (question == null || selectedId == null || state.checked) return;
    await stopAudio();
    emit(state.copyWith(checked: true));
    await _saveProgress();
    await _lessons.saveAnswer(
      ExerciseAnswer(
        lessonId: lessonId,
        questionId: question.id,
        optionId: selectedId,
        hinted: state.hintUsed,
      ),
    );
  }

  /// «التالي», after checking.
  Future<void> next() async {
    if (!state.checked) return;
    await stopAudio();
    final next = state.index + 1;
    if (next >= state.questions.length) {
      await _finish();
      return;
    }
    _show(next);
  }

  Future<void> _finish() async {
    await _lessons.clearProgress(lessonId);
    if (!isClosed) emit(state.copyWith(finished: true));
  }

  /// A checked question counts as done, so leaving after it can't answer it
  /// twice.
  Future<void> _saveProgress() => _lessons.saveProgress(
    lessonId,
    ExerciseProgress(
      position: state.checked ? state.index + 1 : state.index,
      hinted: state.hinted,
    ),
  );

  /// The big button: plays the clip, or stops it.
  Future<void> togglePlay() async {
    if (state.audio == ExerciseAudio.playing) {
      await stopAudio();
    } else if (state.audio != ExerciseAudio.loading) {
      await _play(slow: false);
    }
  }

  /// «أبطأ»: the same file, slower, from its start.
  Future<void> playSlow() async {
    if (state.audio == ExerciseAudio.loading) return;
    await stopAudio();
    await _play(slow: true);
  }

  Future<void> _play({required bool slow}) async {
    final question = state.question;
    if (question == null || question.audioUrl.isEmpty) return;
    final token = ++_clipToken;
    emit(state.copyWith(audio: ExerciseAudio.loading, slow: slow));
    final length = await _player.load(question.audioUrl);
    if (isClosed || token != _clipToken) return;
    if (length == null) {
      // Never stops the answer: the options stay open (S §7.1). An image
      // choice has only its word's button, which simply goes quiet.
      emit(
        state.copyWith(
          audio: question.kind == ExerciseKind.listeningChoice
              ? ExerciseAudio.failed
              : ExerciseAudio.idle,
          slow: false,
        ),
      );
      return;
    }
    final played = slow
        ? Duration(microseconds: (length.inMicroseconds / slowSpeed).round())
        : length;
    emit(
      state.copyWith(
        audio: ExerciseAudio.playing,
        clipLength: played,
        playCount: state.playCount + 1,
      ),
    );
    unawaited(_player.play(speed: slow ? slowSpeed : 1));
    _clipEnd = Timer(played, () {
      if (!isClosed) {
        emit(state.copyWith(audio: ExerciseAudio.idle, slow: false));
      }
    });
  }

  /// Stops any clip, as the exit sheet does on opening.
  Future<void> stopAudio() async {
    _clipToken++;
    _clipEnd?.cancel();
    _clipEnd = null;
    if (state.audio == ExerciseAudio.playing) {
      unawaited(_player.stop());
    }
    if (state.audio == ExerciseAudio.playing ||
        state.audio == ExerciseAudio.loading) {
      emit(state.copyWith(audio: ExerciseAudio.idle, slow: false));
    }
  }

  void _setOnline(bool online) {
    if (isClosed) return;
    emit(state.copyWith(online: online));
    if (online) unawaited(_lessons.sendSaved());
  }

  @override
  Future<void> close() async {
    _clipEnd?.cancel();
    if (state.audio == ExerciseAudio.playing) unawaited(_player.stop());
    await _connection?.cancel();
    return super.close();
  }
}
