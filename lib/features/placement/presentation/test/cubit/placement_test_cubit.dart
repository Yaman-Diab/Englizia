import 'dart:async';

import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum PlacementView {
  /// Getting the attempt and its first questions ready.
  loading,

  /// That failed: nothing to show but a retry.
  failed,
  question,

  /// A stage ended, and the next is about to start. No score, ever.
  between,

  /// The server asks for the short deciding stage.
  deciding,

  /// A stage ended with no connection: the answers wait on the phone.
  offline,
}

enum PlacementAudio { idle, loading, playing, failed }

final class PlacementTestState extends Equatable {
  const PlacementTestState({
    this.view = PlacementView.loading,
    this.failure,
    this.stageSizes = const [],
    this.stage = 1,
    this.questions = const [],
    this.index = 0,
    this.optionId,
    this.dontKnow = false,
    this.audio = PlacementAudio.idle,
    this.playsLeft = 0,
    this.clipLength = Duration.zero,
    this.playCount = 0,
    this.next,
    this.sending = false,
    this.actionFailure,
    this.finished = false,
  });

  final PlacementView view;

  /// Why the test could not open.
  final Failure? failure;
  final List<int> stageSizes;
  final int stage;
  final List<PlacementQuestion> questions;
  final int index;

  /// The option chosen; «لا أعرف» clears it, and the other way round.
  final String? optionId;
  final bool dontKnow;
  final PlacementAudio audio;
  final int playsLeft;
  final Duration clipLength;

  /// Counts each start of the clip, so its progress ring starts over.
  final int playCount;

  /// What follows the stage just ended.
  final PlacementNextStage? next;

  /// Closing a stage or getting the next one.
  final bool sending;

  /// Why that failed for another reason than the connection, with a retry.
  final Failure? actionFailure;

  /// The test is over: its result follows.
  final bool finished;

  PlacementQuestion? get question =>
      view == PlacementView.question && index < questions.length
      ? questions[index]
      : null;

  int get stageSize => stage <= stageSizes.length ? stageSizes[stage - 1] : 0;

  bool get canGoOn => (optionId != null || dontKnow) && !sending;

  /// How full the current stage's part of the bar is: only what was answered
  /// counts, and a stage that ended is full.
  double get stageProgress {
    if (view != PlacementView.question) return 1;
    return stageSize == 0 ? 0 : (index / stageSize).clamp(0, 1);
  }

  PlacementTestState copyWith({
    PlacementView? view,
    Failure? Function()? failure,
    List<int>? stageSizes,
    int? stage,
    List<PlacementQuestion>? questions,
    int? index,
    String? Function()? optionId,
    bool? dontKnow,
    PlacementAudio? audio,
    int? playsLeft,
    Duration? clipLength,
    int? playCount,
    PlacementNextStage? Function()? next,
    bool? sending,
    Failure? Function()? actionFailure,
    bool? finished,
  }) => PlacementTestState(
    view: view ?? this.view,
    failure: failure != null ? failure() : this.failure,
    stageSizes: stageSizes ?? this.stageSizes,
    stage: stage ?? this.stage,
    questions: questions ?? this.questions,
    index: index ?? this.index,
    optionId: optionId != null ? optionId() : this.optionId,
    dontKnow: dontKnow ?? this.dontKnow,
    audio: audio ?? this.audio,
    playsLeft: playsLeft ?? this.playsLeft,
    clipLength: clipLength ?? this.clipLength,
    playCount: playCount ?? this.playCount,
    next: next != null ? next() : this.next,
    sending: sending ?? this.sending,
    actionFailure: actionFailure != null ? actionFailure() : this.actionFailure,
    finished: finished ?? this.finished,
  );

  @override
  List<Object?> get props => [
    view,
    failure,
    stageSizes,
    stage,
    questions,
    index,
    optionId,
    dontKnow,
    audio,
    playsLeft,
    clipLength,
    playCount,
    next,
    sending,
    actionFailure,
    finished,
  ];
}

/// The placement test's questions (requirements v3.0 §12.2, design "Placement
/// Question"): one at a time, with no going back, no feedback and no score, as
/// the server does the marking. Each answer is kept on the phone when given, so
/// a stage that ends offline only waits. A failed clip doesn't count as a
/// listen; one stopped does, and so does one cut off by the stop sheet.
class PlacementTestCubit extends Cubit<PlacementTestState> {
  PlacementTestCubit(this._placement, this._player)
    : super(const PlacementTestState());

  final PlacementRepository _placement;
  final ClipPlayer _player;
  String _attemptId = '';
  Timer? _clipEnd;

  /// The question whose answer is already kept, when closing its stage failed
  /// and the learner tries again.
  int? _keptIndex;

  /// Changes with each question, so a clip still loading can't play on another.
  var _clipToken = 0;

  Future<void> start() async {
    emit(state.copyWith(view: PlacementView.loading, failure: () => null));
    final attempt = await _placement.startAttempt();
    if (isClosed) return;
    switch (attempt) {
      case Err(:final failure):
        emit(
          state.copyWith(view: PlacementView.failed, failure: () => failure),
        );
      case Ok(value: final attempt):
        _attemptId = attempt.id;
        final stage = await _placement.getStage(attempt.id, attempt.stage);
        if (isClosed) return;
        switch (stage) {
          case Err(:final failure):
            emit(
              state.copyWith(
                view: PlacementView.failed,
                failure: () => failure,
              ),
            );
          case Ok(value: final questions):
            final done =
                attempt.answered +
                _placement.unsentAnswers(attempt.id, attempt.stage);
            emit(
              state.copyWith(
                stageSizes: attempt.stageSizes,
                stage: attempt.stage,
                questions: questions,
              ),
            );
            if (done >= questions.length) {
              // Everything was answered: only closing the stage was left.
              emit(state.copyWith(view: PlacementView.question, index: done));
              await _completeStage();
            } else {
              _show(done);
            }
        }
    }
  }

  void _show(int index) {
    _clipToken++;
    final question = state.questions[index];
    final used = _placement.playsUsed(_attemptId, question.id);
    emit(
      PlacementTestState(
        view: PlacementView.question,
        stageSizes: state.stageSizes,
        stage: state.stage,
        questions: state.questions,
        index: index,
        playsLeft: (question.maxPlays - used).clamp(0, question.maxPlays),
        playCount: state.playCount,
      ),
    );
  }

  void choose(String optionId) {
    if (state.question == null || state.sending) return;
    emit(state.copyWith(optionId: () => optionId, dontKnow: false));
  }

  void chooseDontKnow() {
    if (state.question == null || state.sending) return;
    emit(state.copyWith(optionId: () => null, dontKnow: true));
  }

  /// «التالي»: keeps the answer, then the next question or the stage's end.
  Future<void> next() async {
    final question = state.question;
    if (question == null || !state.canGoOn) return;
    await _endClip(counted: false);
    if (_keptIndex != state.index) {
      _keptIndex = state.index;
      await _placement.saveAnswer(
        PlacementAnswer(
          attemptId: _attemptId,
          stage: state.stage,
          questionId: question.id,
          optionId: state.optionId,
          plays: question.maxPlays - state.playsLeft,
        ),
      );
    }
    if (isClosed) return;
    if (state.index + 1 < state.questions.length) {
      _show(state.index + 1);
    } else {
      await _completeStage();
    }
  }

  /// «تابع» between stages, and «إعادة المحاولة» after one ended offline.
  Future<void> goOn() async {
    if (state.sending) return;
    if (state.next == null) {
      await _completeStage();
    } else {
      await _openNextStage();
    }
  }

  /// Tries again what failed for another reason than the connection.
  Future<void> retry() => state.question == null ? goOn() : next();

  Future<void> _completeStage() async {
    emit(state.copyWith(sending: true, actionFailure: () => null));
    final result = await _placement.completeStage(_attemptId, state.stage);
    if (isClosed) return;
    switch (result) {
      case Ok(value: null):
        emit(state.copyWith(sending: false, finished: true));
      case Ok(value: final PlacementNextStage next):
        emit(
          state.copyWith(
            sending: false,
            next: () => next,
            view: next.deciding
                ? PlacementView.deciding
                : PlacementView.between,
            stageSizes: [
              for (var i = 0; i < next.stage; i++)
                i == next.stage - 1
                    ? next.questionCount
                    : i < state.stageSizes.length
                    ? state.stageSizes[i]
                    : 0,
            ],
          ),
        );
      case Err(failure: NetworkFailure()):
        emit(state.copyWith(sending: false, view: PlacementView.offline));
      case Err(:final failure):
        emit(state.copyWith(sending: false, actionFailure: () => failure));
    }
  }

  Future<void> _openNextStage() async {
    final next = state.next!;
    emit(state.copyWith(sending: true, actionFailure: () => null));
    final result = await _placement.getStage(_attemptId, next.stage);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final questions):
        _keptIndex = null;
        emit(
          state.copyWith(
            sending: false,
            stage: next.stage,
            questions: questions,
            next: () => null,
          ),
        );
        _show(0);
      case Err(failure: NetworkFailure()):
        emit(state.copyWith(sending: false, view: PlacementView.offline));
      case Err(:final failure):
        emit(state.copyWith(sending: false, actionFailure: () => failure));
    }
  }

  /// Plays the question's clip, or stops it, which counts as a listen.
  Future<void> togglePlay() async {
    final question = state.question;
    if (question == null) return;
    switch (state.audio) {
      case PlacementAudio.playing:
        await _endClip(counted: true);
      case PlacementAudio.loading:
        return;
      case PlacementAudio.idle || PlacementAudio.failed:
        if (state.playsLeft <= 0) return;
        final token = _clipToken;
        emit(state.copyWith(audio: PlacementAudio.loading));
        final length = await _player.load(question.audioUrl);
        if (isClosed || token != _clipToken) return;
        if (length == null) {
          emit(state.copyWith(audio: PlacementAudio.failed));
          return;
        }
        emit(
          state.copyWith(
            audio: PlacementAudio.playing,
            clipLength: length,
            playCount: state.playCount + 1,
          ),
        );
        unawaited(_player.play());
        _clipEnd = Timer(length, () => _endClip(counted: true));
    }
  }

  /// The stop sheet is opening: the clip stops there, and counts.
  Future<void> interrupt() => _endClip(counted: true);

  Future<void> _endClip({required bool counted}) async {
    _clipToken++;
    _clipEnd?.cancel();
    _clipEnd = null;
    final question = state.question;
    if (state.audio != PlacementAudio.playing || question == null) return;
    unawaited(_player.stop());
    final left = counted ? state.playsLeft - 1 : state.playsLeft;
    emit(
      state.copyWith(
        audio: PlacementAudio.idle,
        playsLeft: left.clamp(0, question.maxPlays),
      ),
    );
    if (counted) {
      await _placement.savePlays(
        _attemptId,
        question.id,
        question.maxPlays - state.playsLeft,
      );
    }
  }

  @override
  Future<void> close() async {
    _clipEnd?.cancel();
    if (state.audio == PlacementAudio.playing) unawaited(_player.stop());
    return super.close();
  }
}
