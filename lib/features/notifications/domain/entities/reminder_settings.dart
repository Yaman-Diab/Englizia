import 'package:englizia/core/l10n/localized_text.dart';
import 'package:equatable/equatable.dart';

/// A time of day on the learner's phone, on a 24-hour clock.
final class ReminderTime extends Equatable {
  const ReminderTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24, 'hour is 0-23'),
      assert(minute >= 0 && minute < 60, 'minute is 0-59');

  final int hour;
  final int minute;

  @override
  List<Object?> get props => [hour, minute];
}

/// The preset times the control panel offers (server doc §17.8).
enum ReminderSlot { morning, noon, evening }

final class ReminderPreset extends Equatable {
  const ReminderPreset({required this.slot, required this.time});

  final ReminderSlot slot;
  final ReminderTime time;

  @override
  List<Object?> get props => [slot, time];
}

/// What the reminder step offers and how the daily reminder reads, from the
/// server's effective settings (server doc §17.7–17.8). Nothing here is
/// fixed in the app.
final class ReminderSettings extends Equatable {
  const ReminderSettings({
    required this.presets,
    required this.defaultSlot,
    required this.title,
    required this.body,
    required this.dailyGoalMinutes,
  });

  /// In display order.
  final List<ReminderPreset> presets;
  final ReminderSlot defaultSlot;

  /// The daily reminder's text as the panel words it; [body] may contain
  /// `{minutes}`.
  final LocalizedText title;
  final LocalizedText body;

  /// The goal the reminder speaks of: the default daily goal until the
  /// learner picks one.
  final int dailyGoalMinutes;

  ReminderPreset get defaultPreset => presets.firstWhere(
    (p) => p.slot == defaultSlot,
    orElse: () => presets.last,
  );

  /// [body] in [languageCode] with the goal filled in.
  String bodyIn(String languageCode) =>
      body.of(languageCode).replaceAll('{minutes}', '$dailyGoalMinutes');

  @override
  List<Object?> get props => [
    presets,
    defaultSlot,
    title,
    body,
    dailyGoalMinutes,
  ];
}
