import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/unit_test.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/repositories/unit_test_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum UnitTestPhase {
  loading,

  /// Before a try: what it takes, and whether it can start.
  intro,
  answering,
  sending,
  result,

  /// The test couldn't be read.
  failure,
}

final class UnitTestViewState extends Equatable {
  const UnitTestViewState({
    this.phase = UnitTestPhase.loading,
    this.test,
    this.index = 0,
    this.answers = const {},
    this.result,
    this.failure,
    this.sendFailed = false,
    this.retryAt,
    this.now,
    this.audio = ClipStatus.idle,
    this.slow = false,
    this.clipLength = Duration.zero,
    this.playCount = 0,
    this.choosing = false,
    this.chosen = false,
  });

  final UnitTestPhase phase;
  final UnitTest? test;
  final int index;

  /// Each question's answer by its id, kept until the whole is sent.
  final Map<String, ExerciseDraft> answers;
  final UnitTestResult? result;
  final Failure? failure;

  /// The last send failed: the answers are still here.
  final bool sendFailed;

  /// When another try opens, while a failed one waits.
  final DateTime? retryAt;

  /// The clock the wait counts down on: the server's, as [retryAt] is.
  final DateTime? now;
  final ClipStatus audio;
  final bool slow;
  final Duration clipLength;
  final int playCount;

  /// A level's choice on its way, and made.
  final bool choosing;
  final bool chosen;

  Exercise? get question {
    final questions = test?.questions ?? const <Exercise>[];
    return index < questions.length ? questions[index] : null;
  }

  ExerciseDraft? get draft => switch (question) {
    final question? => answers[question.id],
    null => null,
  };

  bool get isLast => index >= (test?.questions.length ?? 0) - 1;

  bool get canGoOn => draft?.isComplete ?? false;

  /// The time left before another try; null when none is waited for.
  Duration? get waitLeft {
    final at = retryAt;
    final clock = now;
    if (at == null || clock == null) return null;
    final left = at.difference(clock);
    return left > Duration.zero ? left : null;
  }

  bool get canStart =>
      switch (test?.status.state) {
        UnitTestState.available || UnitTestState.passed => true,
        UnitTestState.cooldown => waitLeft == null,
        _ => false,
      } &&
      waitLeft == null;

  UnitTestViewState copyWith({
    UnitTestPhase? phase,
    UnitTest? Function()? test,
    int? index,
    Map<String, ExerciseDraft>? answers,
    UnitTestResult? Function()? result,
    Failure? Function()? failure,
    bool? sendFailed,
    DateTime? Function()? retryAt,
    DateTime? Function()? now,
    ClipStatus? audio,
    bool? slow,
    Duration? clipLength,
    int? playCount,
    bool? choosing,
    bool? chosen,
  }) => UnitTestViewState(
    phase: phase ?? this.phase,
    test: test != null ? test() : this.test,
    index: index ?? this.index,
    answers: answers ?? this.answers,
    result: result != null ? result() : this.result,
    failure: failure != null ? failure() : this.failure,
    sendFailed: sendFailed ?? this.sendFailed,
    retryAt: retryAt != null ? retryAt() : this.retryAt,
    now: now != null ? now() : this.now,
    audio: audio ?? this.audio,
    slow: slow ?? this.slow,
    clipLength: clipLength ?? this.clipLength,
    playCount: playCount ?? this.playCount,
    choosing: choosing ?? this.choosing,
    chosen: chosen ?? this.chosen,
  );

  @override
  List<Object?> get props => [
    phase,
    test,
    index,
    answers,
    result,
    failure,
    sendFailed,
    retryAt,
    now,
    audio,
    slow,
    clipLength,
    playCount,
    choosing,
    chosen,
  ];
}

/// A unit's test (the backend's note B-33b): online only, one question at a
/// time with no hint, mark or explanation, the answers kept here until the
/// whole goes at once; the server marks it. Closing the app starts it again.
class UnitTestCubit extends Cubit<UnitTestViewState> {
  UnitTestCubit(
    this._tests,
    this._lessons,
    ClipPlayer player, {
    required this.testId,
    DateTime Function()? now,
  }) : _clip = ClipPlayback(player),
       _now = now ?? DateTime.now,
       super(const UnitTestViewState());

  static const slowSpeed = .75;

  /// How often the wait's countdown moves.
  static const tick = Duration(seconds: 1);

  final UnitTestRepository _tests;
  final LessonRepository _lessons;
  final ClipPlayback _clip;
  final DateTime Function() _now;
  final String testId;
  Timer? _clock;

  /// This try's id, the same on every resend.
  String? _submissionId;

  /// Reads the test, once the lessons' answers waiting on the phone have
  /// gone: the server opens it only when it has every lesson done.
  Future<void> start() async {
    emit(state.copyWith(phase: UnitTestPhase.loading, failure: () => null));
    await _lessons.sendSaved();
    final result = await _tests.getTest(testId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final test):
        emit(
          state.copyWith(
            phase: UnitTestPhase.intro,
            test: () => test,
            retryAt: () => test.status.state == UnitTestState.cooldown
                ? test.status.retryAt
                : null,
            now: _now,
          ),
        );
        _countDown();
      case Err(:final failure):
        emit(
          state.copyWith(phase: UnitTestPhase.failure, failure: () => failure),
        );
    }
  }

  /// «ابدأ الاختبار» / «أعد الاختبار»: a new try, from its first question.
  void begin() {
    if (!state.canStart || (state.test?.questions.isEmpty ?? true)) return;
    _submissionId = SettingsStorageService.randomId();
    emit(
      state.copyWith(
        phase: UnitTestPhase.answering,
        index: 0,
        answers: const {},
        result: () => null,
        sendFailed: false,
        chosen: false,
      ),
    );
    _autoplay();
  }

  void updateDraft(ExerciseDraft draft) {
    final question = state.question;
    if (question == null || state.phase != UnitTestPhase.answering) return;
    emit(state.copyWith(answers: {...state.answers, question.id: draft}));
  }

  /// «التالي», and «أرسل» on the last.
  Future<void> next() async {
    if (!state.canGoOn) return;
    await stopAudio();
    if (state.isLast) return send();
    emit(state.copyWith(index: state.index + 1, playCount: 0));
    _autoplay();
  }

  /// Sends the whole test; again, safely, after a failure.
  Future<void> send() async {
    final test = state.test;
    final submissionId = _submissionId;
    if (test == null || submissionId == null) return;
    emit(state.copyWith(phase: UnitTestPhase.sending, sendFailed: false));
    final result = await _tests.submit(
      test,
      state.answers,
      submissionId: submissionId,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            phase: UnitTestPhase.result,
            result: () => value,
            retryAt: () => value.passed ? null : value.retryAt,
            now: _now,
          ),
        );
        _countDown();
      // A fail's wait wasn't over: back to the start, with how long is left.
      case Err(failure: RateLimitFailure(:final retryAfter)):
        emit(
          state.copyWith(
            phase: UnitTestPhase.intro,
            retryAt: () => retryAfter == null ? null : _now().add(retryAfter),
            now: _now,
          ),
        );
        _countDown();
      // The unit isn't open on the server (a lesson not there yet), or the
      // test went: read it again.
      case Err(:final failure)
          when failure.code == ApiErrorCodes.unitTestLocked ||
              failure is NotFoundFailure:
        await start();
      case Err():
        emit(state.copyWith(phase: UnitTestPhase.answering, sendFailed: true));
    }
  }

  /// «انتقل» or «ابقَ» on the level suggested.
  Future<Failure?> chooseLevel({required bool move}) async {
    final suggestion = state.result?.suggestion;
    if (suggestion == null || state.choosing) return null;
    emit(state.copyWith(choosing: true));
    final result = await _tests.chooseLevel(suggestion.id, move: move);
    if (isClosed) return null;
    switch (result) {
      case Ok():
        emit(state.copyWith(choosing: false, chosen: true));
        return null;
      case Err(:final failure):
        emit(state.copyWith(choosing: false));
        return failure;
    }
  }

  /// The wait counts down on the server's clock (`ServerClock`); when it is
  /// over the test is read again, as its state has changed.
  void _countDown() {
    _clock?.cancel();
    if (state.waitLeft == null) return;
    _clock = Timer.periodic(tick, (_) {
      if (isClosed) return;
      emit(state.copyWith(now: _now));
      if (state.waitLeft == null) {
        _clock?.cancel();
        if (state.phase == UnitTestPhase.intro) unawaited(start());
      }
    });
  }

  void _autoplay() {
    if (state.question?.autoplays ?? false) unawaited(_play(slow: false));
  }

  Future<void> togglePlay() async {
    if (state.audio == ClipStatus.playing) {
      await stopAudio();
    } else if (state.audio != ClipStatus.loading) {
      await _play(slow: false);
    }
  }

  Future<void> playSlow() async {
    if (state.audio == ClipStatus.loading) return;
    await stopAudio();
    await _play(slow: true);
  }

  Future<void> _play({required bool slow}) async {
    final question = state.question;
    final clip = question?.clipUrl;
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

  Future<void> stopAudio() async {
    _clip.stop();
    if (state.audio == ClipStatus.playing ||
        state.audio == ClipStatus.loading) {
      emit(state.copyWith(audio: ClipStatus.idle, slow: false));
    }
  }

  @override
  Future<void> close() {
    _clip.stop();
    _clock?.cancel();
    return super.close();
  }
}
