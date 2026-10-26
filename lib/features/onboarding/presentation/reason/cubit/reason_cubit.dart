import 'package:englizia/features/onboarding/domain/entities/learning_reason.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class ReasonState extends Equatable {
  const ReasonState({this.picks = const []});

  /// Chosen reasons in the order they were picked; the guide replies to the
  /// latest one still chosen.
  final List<LearningReason> picks;

  LearningReason? get latest => picks.isEmpty ? null : picks.last;

  bool get canContinue => picks.isNotEmpty;

  ReasonState copyWith({List<LearningReason>? picks}) =>
      ReasonState(picks: picks ?? this.picks);

  @override
  List<Object?> get props => [picks];
}

/// "Why are you learning English?": any number of reasons, at least one.
class ReasonCubit extends Cubit<ReasonState> {
  ReasonCubit() : super(const ReasonState());

  void toggle(LearningReason reason) => emit(
    state.copyWith(
      picks: state.picks.contains(reason)
          ? [...state.picks.where((r) => r != reason)]
          : [...state.picks, reason],
    ),
  );
}
