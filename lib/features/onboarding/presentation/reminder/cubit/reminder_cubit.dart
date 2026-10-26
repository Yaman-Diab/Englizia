import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/presentation/reminder/cubit/reminder_state.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "When should we remind you of your lesson?" (requirements v3.0 §4.2):
/// a configured time or one of the learner's own, then the system
/// permission, asked only once the learner has seen what it is for.
class ReminderCubit extends Cubit<ReminderState> {
  ReminderCubit(this._settings, this._permission)
    : super(const ReminderState());

  final SettingsRepository _settings;
  final NotificationPermission _permission;

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

  /// Asks for the permission. True when notifications may be shown; on a
  /// refusal the step switches to its "notifications are off" state.
  Future<bool> enable() async {
    if (!state.canEnable) return false;
    emit(state.copyWith(asking: true));
    final access = await _permission.request();
    if (isClosed) return false;
    final granted = access == NotificationAccess.granted;
    emit(state.copyWith(asking: false, denied: !granted));
    return granted;
  }

  /// Back from the phone settings: the learner may have allowed them there.
  Future<void> refresh() async {
    if (!state.denied) return;
    final access = await _permission.status();
    if (isClosed || access != NotificationAccess.granted) return;
    emit(state.copyWith(denied: false));
  }

  Future<void> openSettings() => _permission.openSettings();
}
