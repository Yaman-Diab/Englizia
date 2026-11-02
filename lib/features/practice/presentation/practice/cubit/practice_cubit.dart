import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/repositories/practice_repository.dart';
import 'package:englizia/features/practice/domain/services/review_schedule.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class PracticeState extends Equatable {
  const PracticeState({
    this.load = LoadStatus.loading,
    this.failure,
    this.bank,
    this.due = 0,
  });

  final LoadStatus load;
  final Failure? failure;
  final WordBank? bank;

  /// Words due today.
  final int due;

  /// The tab's badge: words and concepts due today, and nothing else (S §10.1).
  int get badge => due + (bank?.conceptsDue ?? 0);

  PracticeState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    WordBank? bank,
    int? due,
  }) => PracticeState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    bank: bank ?? this.bank,
    due: due ?? this.due,
  );

  @override
  List<Object?> get props => [load, failure, bank, due];
}

/// «تدرّب» (requirements v3.0 §10.1, design "Practice"): the word bank, how firmly
/// its words are kept, and what else there is to practise.
class PracticeCubit extends Cubit<PracticeState> {
  PracticeCubit(this._practice, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const PracticeState());

  final PracticeRepository _practice;
  final DateTime Function() _now;

  void _show(WordBank bank) => emit(
    state.copyWith(
      load: LoadStatus.ready,
      failure: () => null,
      bank: bank,
      due: bank.words.where((word) => isDue(word, _now())).length,
    ),
  );

  Future<void> start() async {
    if (_practice.keptBank case final kept?) {
      _show(kept);
    } else {
      emit(state.copyWith(load: LoadStatus.loading, failure: () => null));
    }
    await refresh();
  }

  /// Back from a review or the list: what changed there shows, and the server's
  /// word follows.
  Future<void> refresh() async {
    if (_practice.keptBank case final kept? when state.bank != null) {
      _show(kept);
    }
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
}
