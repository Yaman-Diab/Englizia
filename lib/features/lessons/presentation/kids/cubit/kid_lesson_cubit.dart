import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/kid_lesson.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'kid_media_steps.dart';

enum KidStage { loading, failed, playing, done }

/// How the guide looks: at ease, saying something, pleased, cheering the
/// child on after a miss, or listening while the child speaks.
enum KidMood { welcome, talking, happy, encourage, listening }

enum KidVideoStatus { idle, playing, done }

/// A picture story's place: the page, the word being told, whether pages turn
/// by themselves, a marked word's card, and the page just turned from.
final class KidStoryView extends Equatable {
  const KidStoryView({
    this.page = 0,
    this.word = -1,
    this.auto = false,
    this.opened,
    this.turnedFrom,
    this.forward = true,
  });

  final int page;
  final int word;
  final bool auto;
  final KidWord? opened;
  final int? turnedFrom;
  final bool forward;

  KidStoryView copyWith({
    int? page,
    int? word,
    bool? auto,
    KidWord? Function()? opened,
    int? Function()? turnedFrom,
    bool? forward,
  }) => KidStoryView(
    page: page ?? this.page,
    word: word ?? this.word,
    auto: auto ?? this.auto,
    opened: opened != null ? opened() : this.opened,
    turnedFrom: turnedFrom != null ? turnedFrom() : this.turnedFrom,
    forward: forward ?? this.forward,
  );

  @override
  List<Object?> get props => [page, word, auto, opened, turnedFrom, forward];
}

/// A song's place: the line and word sung, how far it is, and its speed.
final class KidSongView extends Equatable {
  const KidSongView({
    this.status = KidVideoStatus.idle,
    this.line = -1,
    this.word = -1,
    this.progress = 0,
    this.speed = KidSongStep.slow,
  });

  final KidVideoStatus status;
  final int line;
  final int word;
  final double progress;
  final double speed;

  KidSongView copyWith({
    KidVideoStatus? status,
    int? line,
    int? word,
    double? progress,
    double? speed,
  }) => KidSongView(
    status: status ?? this.status,
    line: line ?? this.line,
    word: word ?? this.word,
    progress: progress ?? this.progress,
    speed: speed ?? this.speed,
  );

  @override
  List<Object?> get props => [status, line, word, progress, speed];
}

enum KidTalkPhase {
  /// The character asks.
  opening,

  /// Pictures to pick from.
  choose,

  /// The pick goes up, and the character answers it.
  reply,

  /// «ردّد»: the sentence to say.
  echo,
  recording,

  /// Said: the star is on it, and the character says goodbye.
  echoed,
}

final class KidDialogueView extends Equatable {
  const KidDialogueView({
    this.phase = KidTalkPhase.opening,
    this.picked,
    this.line = '',
    this.lineAudioUrl,
    this.lines = 0,
  });

  final KidTalkPhase phase;
  final int? picked;

  /// What the character says now, and how many lines it has said: it hops at
  /// each one.
  final String line;
  final String? lineAudioUrl;
  final int lines;

  KidDialogueView copyWith({
    KidTalkPhase? phase,
    int? picked,
    String? line,
    String? lineAudioUrl,
    int? lines,
  }) => KidDialogueView(
    phase: phase ?? this.phase,
    picked: picked ?? this.picked,
    line: line ?? this.line,
    lineAudioUrl: lineAudioUrl ?? this.lineAudioUrl,
    lines: lines ?? this.lines,
  );

  @override
  List<Object?> get props => [phase, picked, line, lineAudioUrl, lines];
}

enum KidSpeakPhase { idle, recording, done }

final class KidLessonState extends Equatable {
  const KidLessonState({
    this.stage = KidStage.loading,
    this.failure,
    this.lesson,
    this.step = 0,
    this.progress = 0,
    this.mood = KidMood.welcome,
    this.speaking = false,
    this.questionPlaying = false,
    this.right,
    this.wrong = const {},
    this.flash,
    this.hint = false,
    this.picked,
    this.matched = const {},
    this.wordFlash,
    this.video = KidVideoStatus.idle,
    this.videoProgress = 0,
    this.stars = 0,
    this.won = 0,
    this.wonFrom,
    this.story = const KidStoryView(),
    this.song = const KidSongView(),
    this.dialogue = const KidDialogueView(),
    this.speak = KidSpeakPhase.idle,
  });

  final KidStage stage;
  final Failure? failure;
  final Lesson? lesson;
  final int step;

  /// The screens done, which the bar's star rides on.
  final int progress;
  final KidMood mood;

  /// The guide's voice plays: its bubble is ringed.
  final bool speaking;

  /// The question's own sound plays: the big speaker is ringed.
  final bool questionPlaying;

  /// A choice: the right one once found, the wrong ones tried (dimmed and
  /// locked), the one flashing just now, and after two misses the right one
  /// ringed and pulsing.
  final String? right;
  final Set<String> wrong;
  final String? flash;
  final bool hint;

  /// Matching: the picture chosen, the pairs done, the word flashing.
  final String? picked;
  final Set<String> matched;
  final String? wordFlash;

  final KidVideoStatus video;
  final double videoProgress;

  /// The lesson's end: how many of its five stars are filled.
  final int stars;

  /// Right answers so far, and the card the last one was: a star flies from
  /// it to the bar.
  final int won;
  final String? wonFrom;

  final KidStoryView story;
  final KidSongView song;
  final KidDialogueView dialogue;
  final KidSpeakPhase speak;

  KidLesson? get kids => lesson?.kids;

  int get stepCount => kids?.steps.length ?? 0;

  KidStep? get current {
    final steps = kids?.steps ?? const [];
    return step < steps.length ? steps[step] : null;
  }

  /// The question a question step asks.
  Exercise? get question => switch (current) {
    KidQuestionStep(:final id) =>
      lesson!.exercises.where((exercise) => exercise.id == id).firstOrNull,
    _ => null,
  };

  KidLessonState copyWith({
    KidStage? stage,
    Failure? Function()? failure,
    Lesson? lesson,
    int? step,
    int? progress,
    KidMood? mood,
    bool? speaking,
    bool? questionPlaying,
    String? Function()? right,
    Set<String>? wrong,
    String? Function()? flash,
    bool? hint,
    String? Function()? picked,
    Set<String>? matched,
    String? Function()? wordFlash,
    KidVideoStatus? video,
    double? videoProgress,
    int? stars,
    int? won,
    String? wonFrom,
    KidStoryView? story,
    KidSongView? song,
    KidDialogueView? dialogue,
    KidSpeakPhase? speak,
  }) => KidLessonState(
    stage: stage ?? this.stage,
    failure: failure != null ? failure() : this.failure,
    lesson: lesson ?? this.lesson,
    step: step ?? this.step,
    progress: progress ?? this.progress,
    mood: mood ?? this.mood,
    speaking: speaking ?? this.speaking,
    questionPlaying: questionPlaying ?? this.questionPlaying,
    right: right != null ? right() : this.right,
    wrong: wrong ?? this.wrong,
    flash: flash != null ? flash() : this.flash,
    hint: hint ?? this.hint,
    picked: picked != null ? picked() : this.picked,
    matched: matched ?? this.matched,
    wordFlash: wordFlash != null ? wordFlash() : this.wordFlash,
    video: video ?? this.video,
    videoProgress: videoProgress ?? this.videoProgress,
    stars: stars ?? this.stars,
    won: won ?? this.won,
    wonFrom: wonFrom ?? this.wonFrom,
    story: story ?? this.story,
    song: song ?? this.song,
    dialogue: dialogue ?? this.dialogue,
    speak: speak ?? this.speak,
  );

  @override
  List<Object?> get props => [
    stage,
    failure,
    lesson,
    step,
    progress,
    mood,
    speaking,
    questionPlaying,
    right,
    wrong,
    flash,
    hint,
    picked,
    matched,
    wordFlash,
    video,
    videoProgress,
    stars,
    won,
    wonFrom,
    story,
    song,
    dialogue,
    speak,
  ];
}

/// A kids' lesson (requirements v3.0 §13.2, design "Kid Lesson"): the guide
/// says each screen's instruction, pressing is answering, a right answer sends
/// a star to the bar and moves on, and a wrong one is tried again. Answers go
/// to the server as any lesson's, which keeps the mistakes on their concepts
/// without a word to the child.
class KidLessonCubit extends Cubit<KidLessonState> {
  KidLessonCubit(
    this._lessons,
    ClipPlayer player,
    this._sounds,
    this._video, {
    required this.lessonId,
    DateTime Function()? now,
  }) : _voice = ClipPlayback(player),
       _now = now ?? DateTime.now,
       super(const KidLessonState());

  /// ASSUMPTION(design): the waits of the design's sample.
  static const flashHold = Duration(milliseconds: 420);
  static const moodHold = Duration(milliseconds: 1800);
  static const nextAfterWin = Duration(milliseconds: 1800);
  static const nextAfterPress = Duration(milliseconds: 260);
  static const pairHold = Duration(milliseconds: 1300);
  static const firstStar = Duration(milliseconds: 500);
  static const starGap = Duration(milliseconds: 420);
  static const starCount = 5;

  /// Where the media screens' stars fly from.
  static const storyCard = 'story';
  static const songNext = 'song';
  static const echoCard = 'echo';
  static const micButton = 'mic';

  /// After this many misses on one question, the right answer is shown.
  static const _missesForHint = 2;

  final LessonRepository _lessons;
  final ClipPlayback _voice;
  final SoundPlayer _sounds;
  final VideoEngine _video;
  final DateTime Function() _now;
  final String lessonId;

  /// The letter's video, whose picture the page shows.
  VideoEngine get engine => _video;

  final _timers = <Timer>[];
  StreamSubscription<VideoSnapshot>? _videoChanges;
  late DateTime _startedAt;
  var _misses = 0;

  /// The questions answered right at the first press, and those whose first
  /// answer went to the server.
  var _rightFirstTime = 0;
  final _sent = <String>{};
  final _pairMistakes = <String>{};

  void _later(Duration wait, void Function() then) =>
      _timers.add(Timer(wait, () => isClosed ? null : then()));

  void _hush() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _voice.stop();
  }

  Future<void> start() async {
    emit(const KidLessonState());
    final result = await _lessons.getLesson(lessonId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value) when value.kids != null:
        _startedAt = _now();
        emit(state.copyWith(stage: KidStage.playing, lesson: value));
        _enter();
      case Ok():
        emit(
          state.copyWith(
            stage: KidStage.failed,
            failure: () => const UnknownFailure(),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(stage: KidStage.failed, failure: () => failure));
    }
  }

  /// Says [url], with the guide talking, then does [then].
  Future<void> _say(String? url, {void Function()? then}) async {
    _voice.stop();
    if (url == null) {
      then?.call();
      return;
    }
    emit(state.copyWith(speaking: true, mood: _moodWhileTalking));
    final outcome = await _voice.start(url, onEnd: () => _said(then));
    if (outcome is ClipUnavailable) _said(then);
  }

  KidMood get _moodWhileTalking => switch (state.mood) {
    KidMood.happy || KidMood.encourage => state.mood,
    _ => KidMood.talking,
  };

  void _said(void Function()? then) {
    if (isClosed) return;
    emit(
      state.copyWith(
        speaking: false,
        mood: state.mood == KidMood.talking ? KidMood.welcome : state.mood,
      ),
    );
    then?.call();
  }

  /// A word, a letter or a question's sound: no guide talking, only heard.
  Future<void> _play(String? url, {bool question = false}) async {
    _voice.stop();
    if (url == null) return;
    if (question) emit(state.copyWith(questionPlaying: true));
    void ended() {
      if (!isClosed && question) emit(state.copyWith(questionPlaying: false));
    }

    final outcome = await _voice.start(url, onEnd: ended);
    if (outcome is ClipUnavailable) ended();
  }

  void _enter() {
    _misses = 0;
    final step = state.current;
    unawaited(
      _say(
        step?.instructionAudioUrl,
        then: () => switch (step) {
          KidWordStep(:final word) => unawaited(_play(word.audioUrl)),
          KidQuestionStep() => unawaited(playQuestion()),
          KidStoryStep() => unawaited(narrate()),
          final KidDialogueStep dialogue => _characterSays(
            dialogue.opening,
            then: () => _setDialogue(
              state.dialogue.copyWith(phase: KidTalkPhase.choose),
            ),
          ),
          KidSpeakStep() => unawaited(playModel()),
          _ => null,
        },
      ),
    );
  }

  /// The guide, pressed: the instruction again.
  void replayInstruction() {
    if (state.stage == KidStage.done) {
      unawaited(_say(state.kids!.voice.done));
      return;
    }
    _enter();
  }

  Future<void> playQuestion() => _play(switch (state.question) {
    ListenChooseExercise(:final audioUrl) => audioUrl,
    ImageChoiceExercise(:final audioUrl) => audioUrl,
    _ => null,
  }, question: true);

  Future<void> sayWord(KidWord word) => _play(word.audioUrl);

  Future<void> sayLetter() => _play(switch (state.current) {
    KidLetterStep(:final audioUrl) => audioUrl,
    _ => null,
  });

  /// «التالي» on a word or a letter.
  void next() {
    if (state.current is KidQuestionStep) return;
    _hush();
    landed();
    _later(nextAfterPress, () => _go(state.step + 1));
  }

  /// The star reached the bar: one more screen done.
  void landed() {
    emit(state.copyWith(progress: (state.step + 1).clamp(0, state.stepCount)));
    unawaited(_sounds.play(AppSound.achievement));
  }

  void _go(int step) {
    _hush();
    unawaited(_stopVideo());
    if (step >= state.stepCount) return _finish();
    emit(
      KidLessonState(
        stage: KidStage.playing,
        lesson: state.lesson,
        step: step,
        progress: state.progress,
        won: state.won,
      ),
    );
    _enter();
  }

  void _set(KidLessonState next) => emit(next);

  /// A letter or a picture, pressed.
  void pick(String optionId) {
    final question = state.question;
    if (question is! ChoiceExercise ||
        state.right != null ||
        state.wrong.contains(optionId)) {
      return;
    }
    _send(question, ChoiceDraft(optionId));
    if (optionId == question.answerId) {
      if (_misses == 0) _rightFirstTime++;
      emit(state.copyWith(right: () => optionId, hint: false));
      _win(optionId);
      return;
    }
    _misses++;
    emit(
      state.copyWith(
        wrong: {...state.wrong, optionId},
        flash: () => optionId,
        hint: _misses >= _missesForHint,
      ),
    );
    _miss();
  }

  /// A picture to match, pressed.
  void pickPicture(String pairId) {
    if (state.matched.contains(pairId)) return;
    emit(state.copyWith(picked: () => pairId));
  }

  /// A word to match, pressed: alone it is only heard, so a child who can't
  /// read yet can still match.
  void pickWord(String pairId) {
    final question = state.question;
    if (question is! MatchingExercise || state.matched.contains(pairId)) {
      return;
    }
    final picked = state.picked;
    if (picked == null) {
      unawaited(sayWord(_kidWord(pairId)));
      return;
    }
    if (picked != pairId) {
      _misses++;
      _pairMistakes.add(picked);
      emit(state.copyWith(wordFlash: () => pairId));
      _miss();
      return;
    }
    final matched = {...state.matched, pairId};
    emit(state.copyWith(matched: matched, picked: () => null));
    if (matched.length == question.pairs.length) {
      if (_misses == 0) _rightFirstTime++;
      _send(
        question,
        PairsDraft(
          total: question.pairs.length,
          matched: matched,
          mistakes: {..._pairMistakes},
        ),
      );
      _win(pairId);
      return;
    }
    unawaited(_sounds.play(AppSound.correct));
    emit(state.copyWith(mood: KidMood.happy));
    unawaited(sayWord(_kidWord(pairId)));
    _later(pairHold, () => emit(state.copyWith(mood: KidMood.welcome)));
  }

  KidWord _kidWord(String word) =>
      state.kids!.words.where((w) => w.word == word).firstOrNull ??
      KidWord(word: word, image: '');

  /// The first answer to each question goes to the server, as in any lesson.
  void _send(Exercise question, ExerciseDraft draft) {
    if (!_sent.add(question.id)) return;
    unawaited(
      _lessons.saveAttempt(
        ExerciseAttempt(
          lessonId: lessonId,
          lessonVersion: state.lesson!.version,
          questionId: question.id,
          draft: draft,
          hinted: false,
        ),
      ),
    );
  }

  void _win(String from) {
    _hush();
    unawaited(_sounds.play(AppSound.correct));
    emit(
      state.copyWith(mood: KidMood.happy, won: state.won + 1, wonFrom: from),
    );
    unawaited(_say(state.kids!.voice.praise));
    _later(nextAfterWin, () => _go(state.step + 1));
  }

  void _miss() {
    unawaited(_sounds.play(AppSound.incorrect));
    emit(state.copyWith(mood: KidMood.encourage));
    unawaited(_say(state.kids!.voice.tryAgain));
    _later(
      flashHold,
      () => emit(state.copyWith(flash: () => null, wordFlash: () => null)),
    );
    _later(moodHold, () {
      if (state.right == null) emit(state.copyWith(mood: KidMood.welcome));
    });
  }

  /// The letter's video, from the start.
  Future<void> playVideo() async {
    final step = state.current;
    if (step is! KidLetterStep || step.videoUrl == null) return;
    _hush();
    emit(state.copyWith(video: KidVideoStatus.playing, videoProgress: 0));
    await _videoChanges?.cancel();
    _videoChanges = _video.changes.listen(
      (snapshot) => _onVideo(snapshot, step),
    );
    await _video.open(step.videoUrl!);
  }

  void _onVideo(VideoSnapshot snapshot, KidLetterStep step) {
    if (isClosed || state.video != KidVideoStatus.playing) return;
    final length = snapshot.duration > Duration.zero
        ? snapshot.duration
        : step.videoLength;
    final share = length == null || length == Duration.zero
        ? 0.0
        : (snapshot.position.inMilliseconds / length.inMilliseconds).clamp(
            0.0,
            1.0,
          );
    final ended = snapshot.ended || snapshot.failed || share >= 1;
    emit(
      state.copyWith(
        videoProgress: ended ? 1 : share,
        video: ended ? KidVideoStatus.done : KidVideoStatus.playing,
      ),
    );
    if (ended) unawaited(_stopVideo());
  }

  Future<void> _stopVideo() async {
    await _videoChanges?.cancel();
    _videoChanges = null;
    await _video.pause();
  }

  /// The way out was opened: the guide asks.
  void askToLeave() {
    _hush();
    unawaited(_say(state.kids?.voice.leave));
  }

  /// «ابقَ»: the screen again, as it was.
  void stay() {
    _hush();
    _enter();
  }

  void _finish() {
    emit(
      KidLessonState(
        stage: KidStage.done,
        lesson: state.lesson,
        step: state.stepCount,
        progress: state.stepCount,
        mood: KidMood.happy,
      ),
    );
    final lesson = state.lesson!;
    final questions = lesson.kids!.steps.whereType<KidQuestionStep>().length;
    unawaited(
      _lessons.completeLesson(
        LessonSummary(
          lessonId: lessonId,
          lessonVersion: lesson.version,
          rightFirstTime: _rightFirstTime,
          counted: questions,
          pending: 0,
          seconds: _now().difference(_startedAt).inSeconds,
          outline: lesson.outline,
        ),
      ),
    );
    for (var star = 1; star <= starCount; star++) {
      _later(firstStar + starGap * (star - 1), () {
        emit(state.copyWith(stars: star));
        unawaited(_sounds.play(AppSound.achievement));
      });
    }
    _later(
      firstStar + starGap * starCount,
      () => unawaited(_say(lesson.kids!.voice.done)),
    );
  }

  /// «العب مرة أخرى»: the lesson from its start.
  void again() {
    _hush();
    _misses = 0;
    _rightFirstTime = 0;
    _sent.clear();
    _pairMistakes.clear();
    _startedAt = _now();
    emit(KidLessonState(stage: KidStage.playing, lesson: state.lesson));
    _enter();
  }

  @override
  Future<void> close() async {
    _hush();
    await _videoChanges?.cancel();
    await _video.dispose();
    return super.close();
  }
}
