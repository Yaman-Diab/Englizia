import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A step that picks one number the control panel offers (minutes a day,
/// days of a challenge): the options of [S], and the chosen value.
final class ChoiceStepState<S> extends Equatable {
  const ChoiceStepState({
    this.status = LoadStatus.loading,
    this.settings,
    this.selected,
    this.failure,
  });

  final LoadStatus status;
  final S? settings;

  /// The chosen value; the panel's default is preselected on load.
  final int? selected;
  final Failure? failure;

  bool get canContinue => status == LoadStatus.ready && selected != null;

  /// Nullable fields take a function so they can be cleared: `failure: () => null`.
  ChoiceStepState<S> copyWith({
    LoadStatus? status,
    S? Function()? settings,
    int? Function()? selected,
    Failure? Function()? failure,
  }) => ChoiceStepState<S>(
    status: status ?? this.status,
    settings: settings != null ? settings() : this.settings,
    selected: selected != null ? selected() : this.selected,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [status, settings, selected, failure];
}

/// Loads the step's part of the effective settings and preselects the
/// default. A step says which part it reads, its values and its default.
abstract class ChoiceStepCubit<S> extends Cubit<ChoiceStepState<S>> {
  ChoiceStepCubit(this._settings) : super(ChoiceStepState<S>());

  final SettingsRepository _settings;

  S partOf(EffectiveSettings settings);
  List<int> valuesOf(S settings);
  int defaultOf(S settings);

  /// Loads the options. [chosen] (coming back to this step) is kept when
  /// it is still on offer, as is a choice made before a reload.
  Future<void> load({int? chosen}) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    final result = await _settings.getSettings();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final part = partOf(value);
        final keep = chosen ?? state.selected;
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            settings: () => part,
            selected: () =>
                valuesOf(part).contains(keep) ? keep : defaultOf(part),
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: LoadStatus.failure, failure: () => failure),
        );
    }
  }

  void select(int value) => emit(state.copyWith(selected: () => value));
}
