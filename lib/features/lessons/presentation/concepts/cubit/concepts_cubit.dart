import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/concept.dart';
import 'package:englizia/features/lessons/domain/repositories/concept_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class ConceptsState extends Equatable {
  const ConceptsState({
    this.load = LoadStatus.loading,
    this.failure,
    this.bank,
    this.laterOpen = false,
    this.leaving = const [],
  });

  final LoadStatus load;
  final Failure? failure;
  final ConceptBank? bank;

  /// «لاحقًا» opened.
  final bool laterOpen;

  /// Mastered in the session just ended: still shown, on their way out.
  final List<Concept> leaving;

  ConceptsState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    ConceptBank? bank,
    bool? laterOpen,
    List<Concept>? leaving,
  }) => ConceptsState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    bank: bank ?? this.bank,
    laterOpen: laterOpen ?? this.laterOpen,
    leaving: leaving ?? this.leaving,
  );

  @override
  List<Object?> get props => [load, failure, bank, laterOpen, leaving];
}

/// «مفاهيم للتقوية» (requirements v3.0 §11.2, design "Mistake Bank"): today's
/// concepts by priority, those coming later, and those mastered.
class ConceptsCubit extends Cubit<ConceptsState> {
  ConceptsCubit(this._concepts) : super(const ConceptsState());

  final ConceptRepository _concepts;

  Future<void> start() async {
    if (_concepts.keptBank case final kept?) {
      emit(state.copyWith(load: LoadStatus.ready, bank: kept));
    }
    final result = await _concepts.getBank();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            failure: () => null,
            bank: value,
          ),
        );
      case Err(:final failure):
        if (state.bank == null) {
          emit(
            state.copyWith(load: LoadStatus.failure, failure: () => failure),
          );
        }
    }
  }

  /// Back from a session: what was mastered leaves the list in view.
  Future<void> returned({Set<String> mastered = const {}}) async {
    final before = state.bank?.due ?? const <Concept>[];
    await start();
    if (isClosed) return;
    emit(
      state.copyWith(
        leaving: [
          for (final concept in before)
            if (mastered.contains(concept.id)) concept,
        ],
      ),
    );
  }

  /// The leaving rows are gone.
  void left() => emit(state.copyWith(leaving: const []));

  void toggleLater() => emit(state.copyWith(laterOpen: !state.laterOpen));
}
