part of 'kid_lesson_cubit.dart';

/// The kids' media screens (requirements v3.0 §13.3, design "Kid Media"): a
/// picture story told page by page, a song on its video's clock, a written
/// dialogue answered with pictures and repeated, and «كرّر بعدي». Each ends
/// with a star flying to the bar, as a right answer does.
extension KidMediaSteps on KidLessonCubit {
  /// ASSUMPTION(design): how long a page takes to turn, the wait before the
  /// next page turns by itself, before the character answers a pick, and the
  /// wait after a story's last word.
  static const pageTurn = Duration(milliseconds: 400);
  static const autoTurn = Duration(milliseconds: 800);
  static const replyWait = Duration(milliseconds: 700);
  static const toldTail = Duration(milliseconds: 300);

  KidStoryStep? get _story => switch (state.current) {
    final KidStoryStep step => step,
    _ => null,
  };

  void _setStory(KidStoryView story) => _set(state.copyWith(story: story));

  void _setSong(KidSongView song) => _set(state.copyWith(song: song));

  void _setDialogue(KidDialogueView dialogue) =>
      _set(state.copyWith(dialogue: dialogue));

  /// [url], then [then], whether it plays or not.
  Future<void> _hear(String? url, {void Function()? then}) async {
    _voice.stop();
    if (url == null) {
      then?.call();
      return;
    }
    final outcome = await _voice.start(url, onEnd: () => then?.call());
    if (outcome is ClipUnavailable) then?.call();
  }

  /// The page told aloud, each word marked from its timing in the sound. It
  /// is told once both its sound and its last word are over.
  Future<void> narrate() async {
    final story = _story;
    if (story == null || isClosed) return;
    final index = state.story.page;
    final page = story.pages[index];
    var waiting = 2;
    void told() {
      if (isClosed || state.story.page != index || --waiting > 0) return;
      _setStory(state.story.copyWith(word: -1));
      if (state.story.auto) _later(autoTurn, () => turnPage(1));
    }

    void markWords() {
      for (final (i, word) in page.words.indexed) {
        _later(word.start, () {
          if (state.story.page == index) {
            _setStory(state.story.copyWith(word: i));
          }
        });
      }
      final last = page.words.isEmpty ? Duration.zero : page.words.last.start;
      _later(last + toldTail, told);
    }

    final url = page.audioUrl;
    if (url == null) {
      waiting = 1;
      return markWords();
    }
    final outcome = await _voice.start(url, onEnd: told);
    switch (outcome) {
      case ClipPlaying():
        markWords();
      case ClipUnavailable():
        waiting = 1;
        markWords();
      case ClipCancelled():
        break;
    }
  }

  /// The next page, or the one before; past the last, the story is done.
  void turnPage(int by) {
    final story = _story;
    if (story == null || state.story.turnedFrom != null) return;
    final next = state.story.page + by;
    if (next < 0) return;
    if (next >= story.pages.length) return _win(KidLessonCubit.storyCard);
    _hush();
    _setStory(
      state.story.copyWith(
        page: next,
        word: -1,
        opened: () => null,
        turnedFrom: () => state.story.page,
        forward: by > 0,
      ),
    );
    _later(pageTurn, () {
      _setStory(state.story.copyWith(turnedFrom: () => null));
      unawaited(narrate());
    });
  }

  /// «اقلب الصفحات وحدها».
  void toggleAutoTurn() =>
      _setStory(state.story.copyWith(auto: !state.story.auto));

  /// A marked word, pressed: its card, and its voice.
  void openMarked(KidWord word) {
    _hush();
    _setStory(state.story.copyWith(opened: () => word, word: -1));
    unawaited(_hear(word.audioUrl));
  }

  void closeMarked() => _setStory(state.story.copyWith(opened: () => null));

  /// The song from its start, at its speed.
  Future<void> playSong() async {
    final step = state.current;
    if (step is! KidSongStep || step.videoUrl == null) return;
    _hush();
    _setSong(
      state.song.copyWith(
        status: KidVideoStatus.playing,
        line: -1,
        word: -1,
        progress: 0,
      ),
    );
    await _videoChanges?.cancel();
    _videoChanges = _video.changes.listen((shot) => _onSong(shot, step));
    await _video.open(step.videoUrl!, speed: state.song.speed);
  }

  void _onSong(VideoSnapshot shot, KidSongStep step) {
    if (isClosed || state.song.status != KidVideoStatus.playing) return;
    final position = shot.position;
    var line = -1;
    var word = -1;
    for (final (l, words) in step.lines.indexed) {
      for (final (w, timed) in words.indexed) {
        if (timed.start <= position) {
          line = l;
          word = w;
        }
      }
    }
    final length = shot.duration > Duration.zero
        ? shot.duration
        : step.videoLength;
    final share = length == null || length == Duration.zero
        ? 0.0
        : (position.inMilliseconds / length.inMilliseconds).clamp(0.0, 1.0);
    final ended = shot.ended || shot.failed || share >= 1;
    _setSong(
      state.song.copyWith(
        status: ended ? KidVideoStatus.done : KidVideoStatus.playing,
        line: ended ? -1 : line,
        word: ended ? -1 : word,
        progress: ended ? 1 : share,
      ),
    );
    if (ended) unawaited(_stopVideo());
  }

  /// 0.75 or normal speed, at once if it plays.
  Future<void> toggleSongSpeed() async {
    final speed = state.song.speed == KidSongStep.slow
        ? KidSongStep.normal
        : KidSongStep.slow;
    _setSong(state.song.copyWith(speed: speed));
    if (state.song.status == KidVideoStatus.playing) {
      await _video.setSpeed(speed);
    }
  }

  /// The song is over: on to the next screen.
  void songDone() => _win(KidLessonCubit.songNext);

  void _characterSays(KidLine line, {void Function()? then}) {
    _setDialogue(
      state.dialogue.copyWith(
        line: line.text,
        lineAudioUrl: line.audioUrl,
        lines: state.dialogue.lines + 1,
      ),
    );
    unawaited(_hear(line.audioUrl, then: then));
  }

  /// The character's line, heard again.
  Future<void> replayCharacter() => _hear(state.dialogue.lineAudioUrl);

  /// A reply, picked by its picture.
  void pickReply(int index) {
    final step = state.current;
    if (step is! KidDialogueStep ||
        state.dialogue.phase != KidTalkPhase.choose) {
      return;
    }
    _hush();
    unawaited(_sounds.play(AppSound.correct));
    _setDialogue(
      state.dialogue.copyWith(phase: KidTalkPhase.reply, picked: index),
    );
    final reply = step.replies[index];
    _later(replyWait, () {
      _set(state.copyWith(mood: KidMood.happy));
      _characterSays(
        reply.answer,
        then: () {
          _setDialogue(state.dialogue.copyWith(phase: KidTalkPhase.echo));
          _set(state.copyWith(mood: KidMood.welcome));
          unawaited(
            _say(
              step.echoInstructionAudioUrl,
              then: () => unawaited(_hear(reply.echo.audioUrl)),
            ),
          );
        },
      );
    });
  }

  /// The sentence to repeat, heard again.
  Future<void> playEcho() async {
    final step = state.current;
    final picked = state.dialogue.picked;
    if (step is! KidDialogueStep || picked == null) return;
    await _hear(step.replies[picked].echo.audioUrl);
  }

  /// The model word, heard.
  Future<void> playModel() => _play(switch (state.current) {
    KidSpeakStep(:final word) => word.audioUrl,
    _ => null,
  }, question: true);

  /// The child is speaking: the guide listens.
  void listening() {
    _hush();
    switch (state.current) {
      case KidDialogueStep() when state.dialogue.phase == KidTalkPhase.echo:
        _setDialogue(state.dialogue.copyWith(phase: KidTalkPhase.recording));
      case KidSpeakStep() when state.speak == KidSpeakPhase.idle:
        _set(state.copyWith(speak: KidSpeakPhase.recording));
      default:
        return;
    }
    _set(state.copyWith(mood: KidMood.listening));
  }

  /// The child spoke, whatever was heard: the try itself earns the star.
  void tried() {
    switch (state.current) {
      case final KidDialogueStep step
          when state.dialogue.phase == KidTalkPhase.recording ||
              state.dialogue.phase == KidTalkPhase.echo:
        unawaited(_sounds.play(AppSound.achievement));
        _setDialogue(state.dialogue.copyWith(phase: KidTalkPhase.echoed));
        _set(state.copyWith(mood: KidMood.happy));
        _later(
          replyWait,
          () => _characterSays(
            step.closing,
            then: () => _win(KidLessonCubit.echoCard),
          ),
        );
      case KidSpeakStep() when state.speak != KidSpeakPhase.done:
        _set(state.copyWith(speak: KidSpeakPhase.done));
        _win(KidLessonCubit.micButton);
      default:
        break;
    }
  }
}
