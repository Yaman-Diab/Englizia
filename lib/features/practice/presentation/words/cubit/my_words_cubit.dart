import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/repositories/practice_repository.dart';
import 'package:englizia/features/practice/domain/services/review_schedule.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «الكل»، «للمراجعة اليوم»، «تتعلّمها» and «ثابتة» (S §10.4).
enum WordFilter { all, due, learning, firm }

final class MyWordsState extends Equatable {
  const MyWordsState({
    this.words = const [],
    this.filter = WordFilter.all,
    this.query = '',
    this.searching = false,
  });

  final List<BankWord> words;
  final WordFilter filter;
  final String query;
  final bool searching;

  MyWordsState copyWith({
    List<BankWord>? words,
    WordFilter? filter,
    String? query,
    bool? searching,
  }) => MyWordsState(
    words: words ?? this.words,
    filter: filter ?? this.filter,
    query: query ?? this.query,
    searching: searching ?? this.searching,
  );

  @override
  List<Object?> get props => [words, filter, query, searching];
}

/// «كلماتي» (requirements v3.0 §10.4, design "Practice"): every word, found by
/// its English or Arabic, and taken out of the bank when no longer wanted.
class MyWordsCubit extends Cubit<MyWordsState> {
  MyWordsCubit(this._practice, ClipPlayer player, {DateTime Function()? now})
    : _clip = ClipPlayback(player),
      _now = now ?? DateTime.now,
      super(const MyWordsState());

  final PracticeRepository _practice;
  final ClipPlayback _clip;
  final DateTime Function() _now;

  void start() =>
      emit(state.copyWith(words: _practice.keptBank?.words ?? const []));

  /// What the filter and the search leave, in the bank's order.
  List<BankWord> get shown {
    final query = state.query.trim().toLowerCase();
    final now = _now();
    return [
      for (final word in state.words)
        if (switch (state.filter) {
              WordFilter.all => true,
              WordFilter.due => isDue(word, now),
              WordFilter.learning => isLearning(word),
              WordFilter.firm => !isLearning(word),
            } &&
            (query.isEmpty ||
                word.word.toLowerCase().contains(query) ||
                word.arabic.contains(query)))
          word,
    ];
  }

  void setFilter(WordFilter filter) => emit(state.copyWith(filter: filter));

  void search(String query) => emit(state.copyWith(query: query));

  void openSearch() => emit(state.copyWith(searching: true));

  void closeSearch() => emit(state.copyWith(searching: false, query: ''));

  Future<void> say(String? url) async {
    if (url == null) return;
    await _clip.start(url, onEnd: () {});
  }

  Future<void> remove(BankWord word) async {
    emit(state.copyWith(words: [...state.words.where((w) => w.id != word.id)]));
    await _practice.remove(word);
  }

  @override
  Future<void> close() {
    _clip.stop();
    return super.close();
  }
}
