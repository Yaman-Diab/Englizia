import 'dart:async';

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/repositories/practice_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class KidWordsState extends Equatable {
  const KidWordsState({
    this.load = LoadStatus.loading,
    this.failure,
    this.bank,
    this.unit,
    this.speaking = false,
    this.said,
    this.sayings = 0,
  });

  final LoadStatus load;
  final Failure? failure;
  final WordBank? bank;

  /// The unit filtered by; null for all.
  final String? unit;

  /// The guide says something: it talks, and its bubble is ringed.
  final bool speaking;

  /// The word last pressed, and how many times one was: it hops each time.
  final String? said;
  final int sayings;

  List<BankWord> get shown => [
    for (final word in bank?.words ?? const <BankWord>[])
      if (unit == null || word.unitId == unit) word,
  ];

  KidWordsState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    WordBank? bank,
    String? Function()? unit,
    bool? speaking,
    String? said,
    int? sayings,
  }) => KidWordsState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    bank: bank ?? this.bank,
    unit: unit != null ? unit() : this.unit,
    speaking: speaking ?? this.speaking,
    said: said ?? this.said,
    sayings: sayings ?? this.sayings,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    bank,
    unit,
    speaking,
    said,
    sayings,
  ];
}

/// Kids' «كلماتي» (requirements v3.0 §13.4, design "Kid Media"): the words of
/// the lessons done, as pictures that say themselves, filtered by their unit's
/// picture. The guide says what the screen is, or that it is still empty.
class KidWordsCubit extends Cubit<KidWordsState> {
  KidWordsCubit(this._practice, ClipPlayer player)
    : _clip = ClipPlayback(player),
      super(const KidWordsState());

  final PracticeRepository _practice;
  final ClipPlayback _clip;
  var _greeted = false;

  Future<void> start() async {
    if (_practice.keptBank case final kept?) _show(kept);
    final result = await _practice.getBank();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _show(value);
      case Err(:final failure):
        if (state.bank == null) {
          emit(
            state.copyWith(load: LoadStatus.failure, failure: () => failure),
          );
        }
    }
  }

  void _show(WordBank bank) {
    emit(
      state.copyWith(load: LoadStatus.ready, failure: () => null, bank: bank),
    );
    if (!_greeted) {
      _greeted = true;
      unawaited(sayInstruction());
    }
  }

  /// «هذه كلماتك.», or that there are none yet.
  Future<void> sayInstruction() async {
    final voice = state.bank?.kidsVoice;
    final url = (state.bank?.words.isEmpty ?? true)
        ? voice?.empty
        : voice?.words;
    if (url == null) return;
    emit(state.copyWith(speaking: true));
    void done() {
      if (!isClosed) emit(state.copyWith(speaking: false));
    }

    final outcome = await _clip.start(url, onEnd: done);
    if (outcome is ClipUnavailable) done();
  }

  void filter(String? unit) => emit(state.copyWith(unit: () => unit));

  /// A word, pressed: it says itself.
  Future<void> say(BankWord word) async {
    emit(state.copyWith(said: word.id, sayings: state.sayings + 1));
    final url = word.audioUrl;
    if (url == null) return;
    await _clip.start(url, onEnd: () {});
  }

  @override
  Future<void> close() {
    _clip.stop();
    return super.close();
  }
}
