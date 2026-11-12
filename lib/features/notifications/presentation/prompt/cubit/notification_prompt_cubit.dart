import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:englizia/features/notifications/data/services/push_token_sync.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The prompt's three choices: the panel's morning and evening, or one of
/// the learner's own.
enum PromptChoice { morning, evening, other }

final class NotificationPromptState extends Equatable {
  const NotificationPromptState({
    this.load = LoadStatus.loading,
    this.morning,
    this.evening,
    this.choice = PromptChoice.evening,
    this.custom,
    this.asking = false,
    this.finished = false,
  });

  final LoadStatus load;

  /// The panel's times for the two set choices.
  final ReminderTime? morning;
  final ReminderTime? evening;
  final PromptChoice choice;

  /// The time picked under «وقت آخر».
  final ReminderTime? custom;

  /// Saving, then the phone's own question.
  final bool asking;

  /// Answered either way: the prompt closes.
  final bool finished;

  ReminderTime? get time => switch (choice) {
    PromptChoice.morning => morning,
    PromptChoice.evening => evening,
    PromptChoice.other => custom,
  };

  bool get canEnable => time != null && !asking && !finished;

  NotificationPromptState copyWith({
    LoadStatus? load,
    ReminderTime? Function()? morning,
    ReminderTime? Function()? evening,
    PromptChoice? choice,
    ReminderTime? Function()? custom,
    bool? asking,
    bool? finished,
  }) => NotificationPromptState(
    load: load ?? this.load,
    morning: morning != null ? morning() : this.morning,
    evening: evening != null ? evening() : this.evening,
    choice: choice ?? this.choice,
    custom: custom != null ? custom() : this.custom,
    asking: asking ?? this.asking,
    finished: finished ?? this.finished,
  );

  @override
  List<Object?> get props => [
    load,
    morning,
    evening,
    choice,
    custom,
    asking,
    finished,
  ];
}

/// «نذكّرك بدرسك؟» (design "Notifications" 06–08): once, after the first
/// lesson. «فعّل التذكيرات» saves the time and notifications on, then asks
/// the phone; «ليس الآن» counts, and twice puts the card on «أنا» (09). The
/// time the learner chose in onboarding is chosen already.
class NotificationPromptCubit extends Cubit<NotificationPromptState> {
  NotificationPromptCubit(
    this._settings,
    this._profiles,
    this._permission,
    this._storage,
    this._tokens,
    this._sound,
  ) : super(const NotificationPromptState());

  final SettingsRepository _settings;
  final ProfileRepository _profiles;
  final NotificationPermission _permission;
  final SettingsStorageService _storage;
  final PushTokenSync _tokens;
  final SoundPlayer _sound;

  /// A child's prompt reads its question out; the recording isn't made yet,
  /// so it stays silent (AppSound.guideRemind).
  void speak() => unawaited(_sound.play(AppSound.guideRemind));

  Future<void> start() async {
    await _storage.setNotificationPromptShown();
    final (settings, preferences) = await (
      _settings.getSettings(),
      _profiles.getPreferences(),
    ).wait;
    if (isClosed) return;
    final reminder = switch (settings) {
      Ok(:final value) => value.reminder,
      Err() => null,
    };
    ReminderTime? at(ReminderSlot slot) {
      for (final preset in reminder?.presets ?? const <ReminderPreset>[]) {
        if (preset.slot == slot) return preset.time;
      }
      return null;
    }

    final morning = at(ReminderSlot.morning);
    final evening = at(ReminderSlot.evening);
    final chosen = switch (preferences) {
      Ok(value: final p) when p.reminderHour != null => ReminderTime(
        p.reminderHour!,
        p.reminderMinute,
      ),
      _ => null,
    };
    emit(
      state.copyWith(
        load: reminder == null ? LoadStatus.failure : LoadStatus.ready,
        morning: () => morning,
        evening: () => evening,
        choice: switch (chosen) {
          null => PromptChoice.evening,
          _ when chosen == morning => PromptChoice.morning,
          _ when chosen == evening => PromptChoice.evening,
          _ => PromptChoice.other,
        },
        custom: () => chosen == morning || chosen == evening ? null : chosen,
      ),
    );
  }

  void choose(PromptChoice choice) => emit(state.copyWith(choice: choice));

  void setCustom(ReminderTime time) =>
      emit(state.copyWith(custom: () => time, choice: PromptChoice.other));

  /// Saves the time with notifications on, then asks the phone (Android 13
  /// and iOS ask; older Android allows at once). True when allowed.
  Future<bool> enable() async {
    final time = state.time;
    if (time == null || !state.canEnable) return false;
    emit(state.copyWith(asking: true));
    if (await _profiles.getPreferences() case Ok(:final value)) {
      await _profiles.savePreferences(
        value.copyWith(
          notifications: true,
          reminderHour: time.hour,
          reminderMinute: time.minute,
        ),
      );
    }
    final access = await _permission.request();
    if (isClosed) return false;
    final granted = access == NotificationAccess.granted;
    if (granted) await _tokens.sync();
    emit(state.copyWith(asking: false, finished: true));
    return granted;
  }

  /// «ليس الآن», at the top or the bottom alike.
  Future<void> skip() async {
    if (state.finished) return;
    await _storage.setNotificationPromptSkips(
      _storage.notificationPromptSkips + 1,
    );
    if (!isClosed) emit(state.copyWith(finished: true));
  }
}
