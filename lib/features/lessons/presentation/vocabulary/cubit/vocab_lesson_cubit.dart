import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/audio/device_volume.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/vocabulary.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One playing of a sound: its [length], and an [id] so the same sound played
/// again starts its marks over.
final class SoundRun extends Equatable {
  const SoundRun(this.id, this.length);

  final int id;
  final Duration length;

  @override
  List<Object?> get props => [id, length];
}

final class VocabLessonState extends Equatable {
  const VocabLessonState({
    this.load = LoadStatus.loading,
    this.failure,
    this.title,
    this.words = const [],
    this.index = 0,
    this.review = false,
    this.revealed = const {},
    this.saved = const {},
    this.savedNotice = false,
    this.wordRun,
    this.exampleRun,
    this.audioFailed = false,
    this.muted = false,
  });

  final LoadStatus load;
  final Failure? failure;
  final String? title;
  final List<VocabWord> words;

  /// The card on top.
  final int index;

  /// «كلمات هذا الدرس», after the last card.
  final bool review;

  /// Cards whose example's translation was shown.
  final Set<int> revealed;

  /// Ids of the cards in the word bank.
  final Set<String> saved;
  final bool savedNotice;

  /// The word being said, for the ring around its button.
  final SoundRun? wordRun;

  /// The example being said, for the mark that follows it.
  final SoundRun? exampleRun;
  final bool audioFailed;

  /// The phone's volume is down: the first card asks to turn it up.
  final bool muted;

  VocabWord? get word => words.isEmpty ? null : words[index];

  bool get isLast => index == words.length - 1;

  VocabLessonState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    String? title,
    List<VocabWord>? words,
    int? index,
    bool? review,
    Set<int>? revealed,
    Set<String>? saved,
    bool? savedNotice,
    SoundRun? Function()? wordRun,
    SoundRun? Function()? exampleRun,
    bool? audioFailed,
    bool? muted,
  }) => VocabLessonState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    title: title ?? this.title,
    words: words ?? this.words,
    index: index ?? this.index,
    review: review ?? this.review,
    revealed: revealed ?? this.revealed,
    saved: saved ?? this.saved,
    savedNotice: savedNotice ?? this.savedNotice,
    wordRun: wordRun != null ? wordRun() : this.wordRun,
    exampleRun: exampleRun != null ? exampleRun() : this.exampleRun,
    audioFailed: audioFailed ?? this.audioFailed,
    muted: muted ?? this.muted,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    title,
    words,
    index,
    review,
    revealed,
    saved,
    savedNotice,
    wordRun,
    exampleRun,
    audioFailed,
    muted,
  ];
}

/// A vocabulary lesson's cards (requirements v3.0 §8.5, design "Vocab Lesson"):
/// one word a card, said once as it shows, with its meaning in sight from the
/// start, as this is showing and not testing. Browsing every card completes it.
class VocabLessonCubit extends Cubit<VocabLessonState> {
  VocabLessonCubit(
    this._lessons,
    ClipPlayer player,
    this._volume, {
    required this.lessonId,
  }) : _clip = ClipPlayback(player),
       super(const VocabLessonState());

  static const _noticeHold = Duration(seconds: 3);

  final LessonRepository _lessons;
  final ClipPlayback _clip;
  final DeviceVolume _volume;
  final String lessonId;
  int _lessonVersion = 0;
  var _runs = 0;
  bool _endSent = false;
  Timer? _notice;
  StreamSubscription<bool>? _volumeChanges;

  Future<void> start() async {
    emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    final result = await _lessons.getLesson(lessonId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final lesson):
        final content = lesson.vocabulary;
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
        final muted = await _volume.isMuted();
        if (isClosed) return;
        _volumeChanges ??= _volume.mutedChanges.listen(_followVolume);
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            title: lesson.outline.title,
            words: content.words,
            saved: _lessons.savedWords(lessonId),
            muted: muted,
          ),
        );
        _appear();
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  void _followVolume(bool muted) {
    if (isClosed || muted == state.muted) return;
    emit(state.copyWith(muted: muted));
  }

  /// A card shows: its word is said once, unless the sound can't be heard.
  void _appear() {
    if (state.muted || state.audioFailed) return;
    unawaited(sayWord());
  }

  void _stopSounds() {
    _clip.stop();
    emit(state.copyWith(wordRun: () => null, exampleRun: () => null));
  }

  /// The word itself, or its button.
  Future<void> sayWord() => _sayWordOf(state.index, ring: true);

  /// A word of the review's grid.
  Future<void> sayWordAt(int index) => _sayWordOf(index, ring: false);

  Future<void> _sayWordOf(int index, {required bool ring}) async {
    final url = state.words[index].audioUrl;
    if (url == null) return;
    _stopSounds();
    final outcome = await _clip.start(
      url,
      onEnd: () {
        if (!isClosed) emit(state.copyWith(wordRun: () => null));
      },
    );
    if (isClosed) return;
    switch (outcome) {
      case ClipPlaying(:final length) when ring:
        emit(state.copyWith(wordRun: () => SoundRun(++_runs, length)));
      case ClipUnavailable():
        emit(state.copyWith(audioFailed: true));
      case ClipPlaying() || ClipCancelled():
        break;
    }
  }

  /// The example said, its words marked as they go.
  Future<void> sayExample() async {
    final url = state.word?.example.audioUrl;
    if (url == null) return;
    _stopSounds();
    final outcome = await _clip.start(
      url,
      onEnd: () {
        if (!isClosed) emit(state.copyWith(exampleRun: () => null));
      },
    );
    if (isClosed) return;
    switch (outcome) {
      case ClipPlaying(:final length):
        emit(state.copyWith(exampleRun: () => SoundRun(++_runs, length)));
      case ClipUnavailable():
        emit(state.copyWith(audioFailed: true));
      case ClipCancelled():
        break;
    }
  }

  /// «التالي», or the card sent on by hand. After the last, the review.
  void next() {
    _stopSounds();
    if (state.isLast) {
      emit(state.copyWith(review: true));
      if (!_endSent) {
        _endSent = true;
        unawaited(_lessons.sendContentDone(lessonId, _lessonVersion));
      }
      return;
    }
    emit(state.copyWith(index: state.index + 1));
    _appear();
  }

  void previous() {
    if (state.index == 0) return;
    _stopSounds();
    emit(state.copyWith(index: state.index - 1));
    _appear();
  }

  /// «راجع البطاقات مرة أخرى».
  void again() {
    _stopSounds();
    emit(state.copyWith(review: false, index: 0));
    _appear();
  }

  void reveal() =>
      emit(state.copyWith(revealed: {...state.revealed, state.index}));

  Future<void> toggleSaved() async {
    final word = state.word;
    if (word == null) return;
    final saving = !state.saved.contains(word.id);
    final saved = {...state.saved};
    saving ? saved.add(word.id) : saved.remove(word.id);
    _notice?.cancel();
    emit(state.copyWith(saved: saved, savedNotice: saving));
    if (saving) {
      _notice = Timer(_noticeHold, () {
        if (!isClosed) emit(state.copyWith(savedNotice: false));
      });
    }
    await _lessons.setVocabSaved(lessonId, word, saved: saving);
  }

  /// «إعادة», after the sound failed.
  Future<void> retryAudio() async {
    emit(state.copyWith(audioFailed: false));
    await sayWord();
  }

  @override
  Future<void> close() async {
    _notice?.cancel();
    _clip.stop();
    await _volumeChanges?.cancel();
    return super.close();
  }
}
