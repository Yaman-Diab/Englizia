import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/notifications/domain/entities/reminder_settings.dart';
import 'package:equatable/equatable.dart';

final class ReminderState extends Equatable {
  const ReminderState({
    this.status = LoadStatus.loading,
    this.settings,
    this.failure,
    this.slot,
    this.custom,
    this.useCustom = false,
    this.denied = false,
    this.asking = false,
  });

  final LoadStatus status;
  final ReminderSettings? settings;
  final Failure? failure;

  /// The chosen preset; ignored while [useCustom].
  final ReminderSlot? slot;

  /// A time picked under "another time", kept when a preset is chosen again.
  final ReminderTime? custom;
  final bool useCustom;

  /// The learner refused notifications: the step offers the phone settings
  /// and going on without a reminder.
  final bool denied;

  /// The system prompt is up.
  final bool asking;

  /// The reminder time as chosen, or null before the settings arrive.
  ReminderTime? get time {
    if (useCustom) return custom;
    for (final preset in settings?.presets ?? const <ReminderPreset>[]) {
      if (preset.slot == slot) return preset.time;
    }
    return null;
  }

  bool get canEnable => time != null && !asking;

  /// Nullable fields take a function so they can be cleared: `failure: () => null`.
  ReminderState copyWith({
    LoadStatus? status,
    ReminderSettings? Function()? settings,
    Failure? Function()? failure,
    ReminderSlot? Function()? slot,
    ReminderTime? Function()? custom,
    bool? useCustom,
    bool? denied,
    bool? asking,
  }) => ReminderState(
    status: status ?? this.status,
    settings: settings != null ? settings() : this.settings,
    failure: failure != null ? failure() : this.failure,
    slot: slot != null ? slot() : this.slot,
    custom: custom != null ? custom() : this.custom,
    useCustom: useCustom ?? this.useCustom,
    denied: denied ?? this.denied,
    asking: asking ?? this.asking,
  );

  @override
  List<Object?> get props => [
    status,
    settings,
    failure,
    slot,
    custom,
    useCustom,
    denied,
    asking,
  ];
}
