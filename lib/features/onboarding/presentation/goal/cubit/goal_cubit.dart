import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/presentation/goal/cubit/goal_state.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "What is your daily learning goal?": the options and the default come
/// from the settings, and the default is preselected (requirements v3.0
/// §4.2).
class GoalCubit extends Cubit<GoalState> {
  GoalCubit(this._settings) : super(const GoalState());

  final SettingsRepository _settings;

  /// Loads the options. [chosen] (coming back to this step) is kept when
  /// it is still on offer.
  Future<void> load({int? chosen}) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    final result = await _settings.getSettings();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final goal = value.dailyGoal;
        final keep = chosen ?? state.selected;
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            settings: () => goal,
            selected: () => goal.options.any((o) => o.minutes == keep)
                ? keep
                : goal.defaultOption.minutes,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: LoadStatus.failure, failure: () => failure),
        );
    }
  }

  void select(int minutes) => emit(state.copyWith(selected: () => minutes));
}
