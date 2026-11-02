import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/presentation/video/player_contract.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A tapped word's card: a span, or a word with only a meaning.
final class ReaderSelection extends Equatable {
  const ReaderSelection({
    required this.sentence,
    required this.word,
    this.span,
  });

  final int sentence;
  final int word;
  final ReaderSpan? span;

  @override
  List<Object?> get props => [sentence, word, span];
}

/// One state for the one reader (S §8.2). The player's values stay at their
/// defaults in a text, which has no video.
final class ReaderState extends Equatable implements PlayerState {
  const ReaderState({
    this.load = LoadStatus.loading,
    this.failure,
    this.title,
    this.content,
    this.prefs = const ReaderPrefs(),
    this.position = Duration.zero,
    this.playing = false,
    this.started = false,
    this.current = 0,
    this.word,
    this.open = const {},
    this.revealed = const {},
    this.selection,
    this.saved = const {},
    this.savedNotice = false,
    this.audioFailed = false,
    this.following = true,
    this.showTip = false,
    this.finished = false,
    this.speed = 1,
    this.stage = VideoStage.cover,
    this.resumeFrom,
    this.bufferedTo = Duration.zero,
    this.buffering = false,
    this.slowConnection = false,
    this.quality = VideoQuality.auto,
  });

  final LoadStatus load;
  final Failure? failure;
  final String? title;
  final ReaderContent? content;
  final ReaderPrefs prefs;
  @override
  final Duration position;
  @override
  final bool playing;

  /// It has played, so the word said can be marked.
  final bool started;
  final int current;

  /// The word being said, in the current sentence.
  final int? word;

  /// Sentences whose translation was switched by hand: opened in a text, where it
  /// stays after the sound moves on, and closed in a video, where the current one
  /// shows it.
  final Set<int> open;

  /// Sentences shown while practising listening.
  final Set<int> revealed;
  final ReaderSelection? selection;

  /// Ids of the spans in the word bank.
  final Set<String> saved;
  final bool savedNotice;
  final bool audioFailed;

  /// The list keeps the sentence in view, until the learner scrolls by hand.
  final bool following;
  final bool showTip;
  final bool finished;
  @override
  final double speed;
  @override
  final VideoStage stage;
  @override
  final Duration? resumeFrom;
  @override
  final Duration bufferedTo;
  @override
  final bool buffering;
  @override
  final bool slowConnection;
  @override
  final VideoQuality quality;

  @override
  String? get lessonTitle => title;

  @override
  LessonVideo? get video => content?.video?.video;

  @override
  Duration get duration => content?.duration ?? Duration.zero;

  /// The text under the player is the caption (S §8.4).
  @override
  bool get captions => false;

  @override
  String? get caption => null;

  ReaderState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    String? title,
    ReaderContent? content,
    ReaderPrefs? prefs,
    Duration? position,
    bool? playing,
    bool? started,
    int? current,
    int? Function()? word,
    Set<int>? open,
    Set<int>? revealed,
    ReaderSelection? Function()? selection,
    Set<String>? saved,
    bool? savedNotice,
    bool? audioFailed,
    bool? following,
    bool? showTip,
    bool? finished,
    double? speed,
    VideoStage? stage,
    Duration? Function()? resumeFrom,
    Duration? bufferedTo,
    bool? buffering,
    bool? slowConnection,
    VideoQuality? quality,
  }) => ReaderState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    title: title ?? this.title,
    content: content ?? this.content,
    prefs: prefs ?? this.prefs,
    position: position ?? this.position,
    playing: playing ?? this.playing,
    started: started ?? this.started,
    current: current ?? this.current,
    word: word != null ? word() : this.word,
    open: open ?? this.open,
    revealed: revealed ?? this.revealed,
    selection: selection != null ? selection() : this.selection,
    saved: saved ?? this.saved,
    savedNotice: savedNotice ?? this.savedNotice,
    audioFailed: audioFailed ?? this.audioFailed,
    following: following ?? this.following,
    showTip: showTip ?? this.showTip,
    finished: finished ?? this.finished,
    speed: speed ?? this.speed,
    stage: stage ?? this.stage,
    resumeFrom: resumeFrom != null ? resumeFrom() : this.resumeFrom,
    bufferedTo: bufferedTo ?? this.bufferedTo,
    buffering: buffering ?? this.buffering,
    slowConnection: slowConnection ?? this.slowConnection,
    quality: quality ?? this.quality,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    title,
    content,
    prefs,
    position,
    playing,
    started,
    current,
    word,
    open,
    revealed,
    selection,
    saved,
    savedNotice,
    audioFailed,
    following,
    showTip,
    finished,
    speed,
    stage,
    resumeFrom,
    bufferedTo,
    buffering,
    slowConnection,
    quality,
  ];
}

/// What an interactive text and an interactive video share (requirements v3.0
/// §8.2): the media leads and the text follows it, by the timings that come with
/// each word. The media only reports now and then, so the page's frames carry the
/// time on between reports, and only a change of word reaches the state's listeners
/// that care (`tick`).
abstract class ReaderCubit extends Cubit<ReaderState> {
  ReaderCubit(this.lessons, this.engine, {required this.lessonId})
    : super(const ReaderState());

  static const _noticeHold = Duration(seconds: 3);

  /// A report this close to the running time only shakes the marking.
  static const _driftAllowed = Duration(milliseconds: 250);

  @protected
  final LessonRepository lessons;

  /// For a video's picture; the cubit only tells it what to do.
  final VideoEngine engine;
  final String lessonId;
  StreamSubscription<VideoSnapshot>? _changes;
  Timer? _notice;

  /// The media was asked to open.
  @protected
  bool opened = false;

  /// Where a part of the media stops by itself: one sentence, or one word.
  @protected
  Duration? stopAt;

  /// What to go back to when a word's card closes.
  bool _resumeAfterCard = false;
  Duration? _resumeAt;

  /// Whether this reader stops at each sentence's end.
  @protected
  bool get stopsEachSentence;

  /// A saved word's video, to find its moment again.
  @protected
  String? get videoId => null;

  /// What the lesson's package means for this reader, on top of [ready].
  @protected
  ReaderState readyState(
    ReaderState ready,
    Lesson lesson,
    ReaderContent content,
  );

  /// Follows a report from the media.
  @protected
  void follow(VideoSnapshot snapshot);

  /// Asks the media to open at [at], and to play.
  @protected
  Future<void> openMedia(Duration at);

  /// The end was reached.
  @protected
  void onFinished();

  /// A sentence pressed.
  Future<void> goTo(int sentence);

  Future<void> start() async {
    emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    final result = await lessons.getLesson(lessonId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final lesson):
        final content = lesson.reader;
        if (content == null) {
          emit(
            state.copyWith(
              load: LoadStatus.failure,
              failure: () => const UnknownFailure(),
            ),
          );
          return;
        }
        _changes ??= engine.changes.listen(follow);
        emit(
          readyState(
            state.copyWith(
              load: LoadStatus.ready,
              title: lesson.outline.title,
              content: content,
              prefs: lessons.readerPrefs,
              saved: lessons.savedWords(lessonId),
            ),
            lesson,
            content,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  /// Takes the media's time when it has drifted from the running one.
  @protected
  void syncTime(VideoSnapshot snapshot) {
    final drift = snapshot.position - state.position;
    if (drift.abs() > _driftAllowed) moveTo(snapshot.position);
  }

  /// A frame passed while it plays.
  void tick(Duration elapsed) {
    if (isClosed || !state.playing || state.buffering) return;
    moveTo(state.position + elapsed * state.speed);
  }

  /// Where a moment falls. Between two sentences that is the next one, unless a
  /// reader keeps the last one a while.
  @protected
  ReaderPlace placeAt(ReaderContent content, Duration position) =>
      content.placeAt(position);

  @protected
  void moveTo(Duration position) {
    final content = state.content;
    if (content == null) return;
    if (position >= content.duration) return finish();
    final stop = stopAt;
    if (stop != null && position >= stop) {
      stopAt = null;
      emit(state.copyWith(position: stop));
      unawaited(engine.pause());
      emit(state.copyWith(playing: false));
      return;
    }
    final place = placeAt(content, position);
    // «توقف بعد كل جملة»: where the sentence playing ends.
    if (stopsEachSentence && state.playing && place.sentence != state.current) {
      final end = content.sentences[state.current].end;
      emit(state.copyWith(position: end, word: () => null));
      unawaited(engine.pause());
      emit(state.copyWith(playing: false));
      return;
    }
    emit(
      state.copyWith(
        position: position,
        current: place.sentence,
        word: () => place.word,
      ),
    );
  }

  @protected
  void finish() {
    final content = state.content;
    if (content == null) return;
    stopAt = null;
    unawaited(engine.pause());
    emit(
      state.copyWith(
        position: content.duration,
        playing: false,
        word: () => null,
        finished: true,
      ),
    );
    onFinished();
  }

  @protected
  Future<void> startPlaying({Duration? from}) async {
    final content = state.content;
    if (content == null) return;
    final at = from ?? state.position;
    emit(
      state.copyWith(
        position: at,
        playing: true,
        started: true,
        following: true,
        showTip: false,
      ),
    );
    if (!opened) {
      opened = true;
      await openMedia(at);
    } else {
      if (from != null) await engine.seekTo(from);
      await engine.play();
    }
  }

  Future<void> play() {
    stopAt = null;
    final atEnd = state.position >= (state.content?.duration ?? Duration.zero);
    if (atEnd) {
      emit(
        state.copyWith(position: Duration.zero, current: 0, finished: false),
      );
      return startPlaying(from: Duration.zero);
    }
    return startPlaying();
  }

  Future<void> pause() async {
    emit(state.copyWith(playing: false));
    await engine.pause();
  }

  Future<void> togglePlay() => state.playing ? pause() : play();

  /// The bar moved by hand.
  Future<void> seekTo(Duration position) async {
    stopAt = null;
    moveTo(position);
    if (opened) await engine.seekTo(position);
  }

  void toggleTranslation(int sentence) {
    final open = {...state.open};
    if (!open.remove(sentence)) open.add(sentence);
    emit(state.copyWith(open: open));
  }

  void reveal(int sentence) =>
      emit(state.copyWith(revealed: {...state.revealed, sentence}));

  /// A word pressed: its span's card, or its meaning's, or nothing, and then the
  /// press belongs to its sentence. Returns whether it opened a card.
  bool selectWord(int sentence, int word) {
    final content = state.content!;
    final target = content.sentences[sentence];
    final span = content.spanOf(target, target.words[word]);
    if (span == null && target.words[word].gloss == null) return false;
    if (state.selection == null) {
      _resumeAfterCard = state.playing;
      _resumeAt = state.position;
    }
    if (state.playing) unawaited(pause());
    if (state.showTip) closeTip();
    emit(
      state.copyWith(
        selection: () =>
            ReaderSelection(sentence: sentence, word: word, span: span),
      ),
    );
    return true;
  }

  /// The card closes, and what was playing carries on.
  Future<void> closeCard() async {
    emit(state.copyWith(selection: () => null));
    final resume = _resumeAfterCard;
    _resumeAfterCard = false;
    if (resume) await startPlaying(from: _resumeAt);
    _resumeAt = null;
  }

  /// The card's sound: cut from the sentence's by the words' timings (S §8.2).
  Future<void> sayCard() async {
    final selection = state.selection;
    if (selection == null || state.audioFailed) return;
    final sentence = state.content!.sentences[selection.sentence];
    final words = [
      for (final word in sentence.words)
        if (selection.span?.wordIds.contains(word.id) ??
            word == sentence.words[selection.word])
          word,
    ];
    stopAt = words.last.end;
    await startPlaying(from: words.first.start);
  }

  Future<void> toggleSaved() async {
    final selection = state.selection;
    final span = selection?.span;
    if (selection == null || span == null) return;
    final saving = !state.saved.contains(span.id);
    final saved = {...state.saved};
    saving ? saved.add(span.id) : saved.remove(span.id);
    _notice?.cancel();
    emit(state.copyWith(saved: saved, savedNotice: saving));
    if (saving) {
      _notice = Timer(_noticeHold, () {
        if (!isClosed) emit(state.copyWith(savedNotice: false));
      });
    }
    await lessons.setWordSaved(
      SavedWord(
        lessonId: lessonId,
        span: span,
        sentence: state.content!.sentences[selection.sentence],
        videoId: videoId,
      ),
      saved: saving,
    );
  }

  /// The learner took over the scrolling.
  void stopFollowing() {
    if (state.playing && state.following) {
      emit(state.copyWith(following: false));
    }
  }

  /// «الجملة الحالية».
  void followAgain() => emit(state.copyWith(following: true));

  void closeTip() {
    emit(state.copyWith(showTip: false));
    unawaited(lessons.setReaderTipSeen());
  }

  Future<void> setPrefs(ReaderPrefs prefs) async {
    final modeChanged = prefs.mode != state.prefs.mode;
    emit(state.copyWith(prefs: prefs, revealed: modeChanged ? const {} : null));
    await lessons.setReaderPrefs(prefs);
  }

  @override
  Future<void> close() async {
    _notice?.cancel();
    await _changes?.cancel();
    await engine.dispose();
    return super.close();
  }
}
