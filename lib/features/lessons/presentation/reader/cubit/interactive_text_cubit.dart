import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:equatable/equatable.dart';
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

final class InteractiveTextState extends Equatable {
  const InteractiveTextState({
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
  });

  final LoadStatus load;
  final Failure? failure;
  final String? title;
  final ReaderContent? content;
  final ReaderPrefs prefs;
  final Duration position;
  final bool playing;

  /// It has played, so the word said can be marked.
  final bool started;
  final int current;

  /// The word being said, in the current sentence.
  final int? word;

  /// Sentences whose translation is open: it stays after the sound moves on.
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
  final double speed;

  InteractiveTextState copyWith({
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
  }) => InteractiveTextState(
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
  ];
}

/// An interactive text (requirements v3.0 §8.2–§8.3, design "Interactive Text"):
/// the sound leads and the text follows it, by the timings that come with each
/// word. The sound only reports now and then, so the page's frames carry the time
/// on between reports, and only a change of word reaches the state's listeners
/// that care (`tick`).
class InteractiveTextCubit extends Cubit<InteractiveTextState> {
  InteractiveTextCubit(this._lessons, this._engine, {required this.lessonId})
    : super(const InteractiveTextState());

  /// The speeds, in the order the button goes through them.
  static const _speeds = [1.0, 1.25, .75];
  static const _noticeHold = Duration(seconds: 3);

  /// A report this close to the running time only shakes the marking.
  static const _driftAllowed = Duration(milliseconds: 250);

  final LessonRepository _lessons;
  final VideoEngine _engine;
  final String lessonId;
  int _lessonVersion = 0;
  StreamSubscription<VideoSnapshot>? _changes;
  Timer? _notice;
  bool _opened = false;
  bool _endToldServer = false;

  /// Where a part of the sound stops by itself: one sentence, or one word.
  Duration? _stopAt;

  /// What to go back to when a word's card closes.
  bool _resumeAfterCard = false;
  Duration? _resumeAt;

  Future<void> start() async {
    emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    final result = await _lessons.getLesson(lessonId);
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
        _lessonVersion = lesson.version;
        _changes ??= _engine.changes.listen(_follow);
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            title: lesson.outline.title,
            content: content,
            prefs: _lessons.readerPrefs,
            saved: _lessons.savedWords(lessonId),
            showTip: !_lessons.readerTipSeen,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  void _follow(VideoSnapshot snapshot) {
    if (isClosed) return;
    if (snapshot.failed) {
      _opened = false;
      emit(state.copyWith(audioFailed: true, playing: false));
      return;
    }
    if (!snapshot.ready) return;
    if (snapshot.playing != state.playing) {
      emit(state.copyWith(playing: snapshot.playing));
    }
    final drift = snapshot.position - state.position;
    if (drift.abs() > _driftAllowed) _moveTo(snapshot.position);
    if (snapshot.ended) _finish();
  }

  /// A frame passed while it plays.
  void tick(Duration elapsed) {
    if (!state.playing) return;
    _moveTo(state.position + elapsed * state.speed);
  }

  void _moveTo(Duration position) {
    final content = state.content;
    if (content == null) return;
    if (position >= content.duration) return _finish();
    final stop = _stopAt;
    if (stop != null && position >= stop) {
      _stopAt = null;
      emit(state.copyWith(position: stop));
      unawaited(_engine.pause());
      emit(state.copyWith(playing: false));
      return;
    }
    final place = content.placeAt(position);
    // «توقف بعد كل جملة»: where the sentence playing ends.
    if (state.prefs.stopEachSentence &&
        state.playing &&
        place.sentence != state.current) {
      final end = content.sentences[state.current].end;
      emit(state.copyWith(position: end, word: () => null));
      unawaited(_engine.pause());
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

  void _finish() {
    final content = state.content;
    if (content == null) return;
    _stopAt = null;
    unawaited(_engine.pause());
    emit(
      state.copyWith(
        position: content.duration,
        playing: false,
        word: () => null,
        finished: true,
      ),
    );
    reachedEnd();
  }

  /// The end of the text was reached, which is what completes it (S §8.3).
  void reachedEnd() {
    if (_endToldServer) return;
    _endToldServer = true;
    unawaited(_lessons.sendContentDone(lessonId, _lessonVersion));
  }

  Future<void> _start({Duration? from}) async {
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
    if (!_opened) {
      _opened = true;
      await _engine.open(content.audioUrl, from: at, speed: state.speed);
    } else {
      if (from != null) await _engine.seekTo(from);
      await _engine.play();
    }
  }

  Future<void> play() {
    _stopAt = null;
    final atEnd = state.position >= (state.content?.duration ?? Duration.zero);
    if (atEnd) {
      emit(state.copyWith(position: Duration.zero, current: 0));
      return _start(from: Duration.zero);
    }
    return _start();
  }

  Future<void> pause() async {
    emit(state.copyWith(playing: false));
    await _engine.pause();
  }

  Future<void> togglePlay() => state.playing ? pause() : play();

  /// «استمع» under a sentence: that one alone.
  Future<void> listenTo(int sentence) {
    final target = state.content!.sentences[sentence];
    _stopAt = target.end;
    emit(state.copyWith(position: target.start, current: sentence));
    return _start(from: target.start);
  }

  /// A sentence pressed becomes the current one, and the sound goes there.
  Future<void> goTo(int sentence) async {
    final target = state.content!.sentences[sentence];
    _stopAt = null;
    emit(
      state.copyWith(
        position: target.start,
        current: sentence,
        word: () => null,
      ),
    );
    if (_opened) await _engine.seekTo(target.start);
  }

  /// The bar moved by hand.
  Future<void> seekTo(Duration position) async {
    _stopAt = null;
    _moveTo(position);
    if (_opened) await _engine.seekTo(position);
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
    _hideTip();
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
    if (resume) await _start(from: _resumeAt);
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
    _stopAt = words.last.end;
    await _start(from: words.first.start);
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
    await _lessons.setWordSaved(
      SavedWord(
        lessonId: lessonId,
        span: span,
        sentence: state.content!.sentences[selection.sentence],
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

  void _hideTip() {
    if (state.showTip) closeTip();
  }

  void closeTip() {
    emit(state.copyWith(showTip: false));
    unawaited(_lessons.setReaderTipSeen());
  }

  Future<void> cycleSpeed() async {
    final speed = _speeds[(_speeds.indexOf(state.speed) + 1) % _speeds.length];
    emit(state.copyWith(speed: speed));
    if (_opened) await _engine.setSpeed(speed);
  }

  Future<void> setPrefs(ReaderPrefs prefs) async {
    final modeChanged = prefs.mode != state.prefs.mode;
    emit(state.copyWith(prefs: prefs, revealed: modeChanged ? const {} : null));
    await _lessons.setReaderPrefs(prefs);
  }

  /// «إعادة المحاولة».
  Future<void> retryAudio() async {
    emit(state.copyWith(audioFailed: false));
    await _start();
  }

  @override
  Future<void> close() async {
    _notice?.cancel();
    await _changes?.cancel();
    await _engine.dispose();
    return super.close();
  }
}
