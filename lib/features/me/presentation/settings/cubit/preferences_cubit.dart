import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class PreferencesState extends Equatable {
  const PreferencesState({
    this.load = LoadStatus.loading,
    this.failure,
    this.preferences,
    this.goals,
    this.defaultReminder,
    this.access,
    this.videoQuality = VideoQuality.auto,
    this.saving = false,
    this.refused = false,
  });

  final LoadStatus load;
  final Failure? failure;
  final Preferences? preferences;

  /// The panel's daily goals, as onboarding offered them.
  final DailyGoalSettings? goals;

  /// The panel's suggested reminder, where the time sheet starts with none.
  final ReminderTime? defaultReminder;

  /// Whether the phone lets the app notify; null until asked.
  final NotificationAccess? access;
  final VideoQuality videoQuality;

  /// A password or a deletion on its way.
  final bool saving;

  /// The phone said no when asked: only its settings can allow them now.
  final bool refused;

  /// The phone keeps notifications off though they were wanted: the switch
  /// can't be on. Never asked yet, it still can be.
  bool get phoneBlocks =>
      access == NotificationAccess.denied &&
      (refused || (preferences?.notifications ?? false));

  bool get notificationsOn =>
      !phoneBlocks && (preferences?.notifications ?? false);

  PreferencesState copyWith({
    LoadStatus? load,
    Failure? Function()? failure,
    Preferences? preferences,
    DailyGoalSettings? goals,
    ReminderTime? defaultReminder,
    NotificationAccess? access,
    VideoQuality? videoQuality,
    bool? saving,
    bool? refused,
  }) => PreferencesState(
    load: load ?? this.load,
    failure: failure != null ? failure() : this.failure,
    preferences: preferences ?? this.preferences,
    goals: goals ?? this.goals,
    defaultReminder: defaultReminder ?? this.defaultReminder,
    access: access ?? this.access,
    videoQuality: videoQuality ?? this.videoQuality,
    saving: saving ?? this.saving,
    refused: refused ?? this.refused,
  );

  @override
  List<Object?> get props => [
    load,
    failure,
    preferences,
    goals,
    defaultReminder,
    access,
    videoQuality,
    saving,
    refused,
  ];
}

/// The settings that follow the account (S §19.2, design "Settings"): the
/// daily goal, the reminder's time and notifications, all or none; and the
/// video's quality, kept on this phone. A change shows at once and is saved
/// with no button; one the server refuses is put back. Also the password and
/// deleting the account.
class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit(
    this._profiles,
    this._settings,
    this._lessons,
    this._permission,
  ) : super(const PreferencesState());

  final ProfileRepository _profiles;
  final SettingsRepository _settings;
  final LessonRepository _lessons;
  final NotificationPermission _permission;

  Future<void> start() async {
    emit(state.copyWith(videoQuality: _lessons.videoQuality));
    final (preferences, settings, access) = await (
      _profiles.getPreferences(),
      _settings.getSettings(),
      _permission.status(),
    ).wait;
    if (isClosed) return;
    switch (preferences) {
      case Ok(:final value):
        emit(
          state.copyWith(
            load: LoadStatus.ready,
            failure: () => null,
            preferences: value,
            goals: switch (settings) {
              Ok(:final value) => value.dailyGoal,
              Err() => null,
            },
            defaultReminder: switch (settings) {
              Ok(:final value) => _suggested(value.reminder),
              Err() => null,
            },
            access: access,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(load: LoadStatus.failure, failure: () => failure));
    }
  }

  static ReminderTime? _suggested(ReminderSettings reminder) {
    for (final preset in reminder.presets) {
      if (preset.slot == reminder.defaultSlot) return preset.time;
    }
    return reminder.presets.firstOrNull?.time;
  }

  /// Back from the phone's settings, the permission may have changed.
  Future<void> recheck() async {
    final access = await _permission.status();
    if (!isClosed) emit(state.copyWith(access: access));
  }

  Future<bool> openPhoneSettings() => _permission.openSettings();

  Future<Failure?> setGoal(int minutes) =>
      _save((preferences) => preferences.copyWith(dailyGoalMinutes: minutes));

  Future<Failure?> setReminder(int hour, int minute) => _save(
    (preferences) =>
        preferences.copyWith(reminderHour: hour, reminderMinute: minute),
  );

  /// On asks the phone first; if it says no, the switch stays off.
  Future<Failure?> setNotifications({required bool on}) async {
    if (on) {
      final access = await _permission.request();
      if (isClosed) return null;
      final denied = access == NotificationAccess.denied;
      emit(state.copyWith(access: access, refused: denied));
      if (denied) return null;
    }
    return _save((preferences) => preferences.copyWith(notifications: on));
  }

  Future<Failure?> _save(Preferences Function(Preferences) change) async {
    final before = state.preferences;
    if (before == null) return null;
    final after = change(before);
    if (after == before) return null;
    emit(state.copyWith(preferences: after));
    final result = await _profiles.savePreferences(after);
    if (isClosed) return null;
    if (result case Err(:final failure)) {
      emit(state.copyWith(preferences: before));
      return failure;
    }
    return null;
  }

  Future<void> setVideoQuality(VideoQuality quality) async {
    emit(state.copyWith(videoQuality: quality));
    await _lessons.setVideoQuality(quality);
  }

  Future<Failure?> changePassword(String current, String next) =>
      _busy(() => _profiles.changePassword(current: current, next: next));

  Future<Failure?> deleteAccount({String? password}) =>
      _busy(() => _profiles.deleteAccount(password: password));

  Future<Failure?> _busy(Future<Result<void>> Function() call) async {
    if (state.saving) return null;
    emit(state.copyWith(saving: true));
    final result = await call();
    if (isClosed) return null;
    emit(state.copyWith(saving: false));
    return switch (result) {
      Ok() => null,
      Err(:final failure) => failure,
    };
  }
}
