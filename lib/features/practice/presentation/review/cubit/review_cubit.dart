import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/repositories/practice_repository.dart';
import 'package:englizia/features/practice/domain/services/review_schedule.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The line an answer leaves for a moment: «تراها بعد 7 أيام» or «تراها غدًا».
final class ReviewFlash extends Equatable {
  const ReviewFlash({required this.known, required this.days});

  final bool known;
  final int days;

  @override
  List<Object?> get props => [known, days];
}

final class ReviewState extends Equatable {
  const ReviewState({
    this.words = const [],
    this.index = 0,
    this.flipped = false,
    this.flash,
    this.answers = const [],
  });

  final List<BankWord> words;
  final int index;
  final bool flipped;
  final ReviewFlash? flash;

  /// «عرفتها» or not, for each card answered.
  final List<bool> answers;

  BankWord? get word => index < words.length ? words[index] : null;

  bool get done => words.isNotEmpty && index >= words.length;

  int get known => answers.where((answer) => answer).length;

  ReviewState copyWith({
    List<BankWord>? words,
    int? index,
    bool? flipped,
    ReviewFlash? Function()? flash,
    List<bool>? answers,
  }) => ReviewState(
    words: words ?? this.words,
    index: index ?? this.index,
    flipped: flipped ?? this.flipped,
    flash: flash != null ? flash() : this.flash,
    answers: answers ?? this.answers,
  );

  @override
  List<Object?> get props => [words, index, flipped, flash, answers];
}

/// A review (requirements v3.0 §10.3, design "Practice"): each card turned, then
/// known or not, with no right or wrong colours. It runs without a connection;
/// each answer is kept at once.
class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit(this._practice, ClipPlayer player, {DateTime Function()? now})
    : _clip = ClipPlayback(player),
      _now = now ?? DateTime.now,
      super(const ReviewState());

  final PracticeRepository _practice;
  final ClipPlayback _clip;
  final DateTime Function() _now;

  void start() {
    final bank = _practice.keptBank;
    if (bank == null) return;
    emit(ReviewState(words: sessionWords(bank, _now())));
  }

  /// The card turns once; pressing it again does nothing.
  void flip() {
    if (state.flipped || state.flash != null || state.word == null) return;
    emit(state.copyWith(flipped: true));
  }

  Future<void> answer({required bool known}) async {
    final word = state.word;
    if (word == null || !state.flipped || state.flash != null) return;
    _clip.stop();
    emit(
      state.copyWith(
        flash: () => ReviewFlash(
          known: known,
          days: boxDays[(known ? word.box + 1 : 1).clamp(1, boxCount) - 1],
        ),
        answers: [...state.answers, known],
      ),
    );
    await _practice.answer(word, known: known);
  }

  /// After the line: the next card, or the end.
  void next() {
    if (state.flash == null) return;
    emit(
      state.copyWith(index: state.index + 1, flipped: false, flash: () => null),
    );
  }

  Future<void> sayWord() => _say(state.word?.audioUrl);

  Future<void> saySentence() => _say(state.word?.sentenceAudioUrl);

  /// A line of the guide, as kids' «العب بكلماتي» says them.
  Future<void> sayLine(String? url) => _say(url);

  Future<void> _say(String? url) async {
    if (url == null) return;
    await _clip.start(url, onEnd: () {});
  }

  @override
  Future<void> close() {
    _clip.stop();
    unawaited(_practice.sendPending());
    return super.close();
  }
}
