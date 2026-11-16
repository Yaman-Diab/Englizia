import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/presentation/reminder/cubit/reminder_state.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "When should we remind you of your lesson?" (requirements v3.0 §4.2): a
/// configured time or one of the learner's own. The phone's permission is
/// asked later, after the first lesson (design "Notifications" 06), where
/// this time is chosen already.
class ReminderCubit extends Cubit<ReminderState> {
  ReminderCubit(this._settings) : super(const ReminderState());

  final SettingsRepository _settings;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading, failure: () => null));
    final result = await _settings.getSettings();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            settings: () => value.reminder,
            defaultGoalMinutes: () => value.dailyGoal.defaultMinutes,
            slot: () => state.slot ?? value.reminder.defaultPreset.slot,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: LoadStatus.failure, failure: () => failure),
        );
    }
  }

  void choose(ReminderSlot slot) =>
      emit(state.copyWith(slot: () => slot, useCustom: false));

  void setCustom(ReminderTime time) =>
      emit(state.copyWith(custom: () => time, useCustom: true));
}
