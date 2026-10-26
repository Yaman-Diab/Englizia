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
/// server's effective settings (server doc §17.8). Nothing here is fixed in
/// the app.
final class ReminderSettings extends Equatable {
  const ReminderSettings({
    required this.presets,
    required this.defaultSlot,
    required this.title,
    required this.body,
  });

  /// In display order.
  final List<ReminderPreset> presets;
  final ReminderSlot defaultSlot;

  /// The daily reminder's text as the panel words it; [body] may contain
  /// `{minutes}`.
  final LocalizedText title;
  final LocalizedText body;

  ReminderPreset get defaultPreset => presets.firstWhere(
    (p) => p.slot == defaultSlot,
    orElse: () => presets.last,
  );

  /// [body] in [languageCode] with the learner's daily goal filled in.
  String bodyIn(String languageCode, {required int goalMinutes}) =>
      body.of(languageCode).replaceAll('{minutes}', '$goalMinutes');

  @override
  List<Object?> get props => [presets, defaultSlot, title, body];
}

/// One choice of the daily goal, worded by the panel ("مريح").
final class DailyGoalOption extends Equatable {
  const DailyGoalOption({required this.minutes, required this.label});

  final int minutes;
  final LocalizedText label;

  @override
  List<Object?> get props => [minutes, label];
}

/// The daily goal choices and their default (server doc §17.7).
final class DailyGoalSettings extends Equatable {
  const DailyGoalSettings({
    required this.options,
    required this.defaultMinutes,
    this.lessonMinutes,
  });

  /// In display order, lowest first.
  final List<DailyGoalOption> options;
  final int defaultMinutes;

  /// How long an average lesson takes, to say what a goal amounts to in
  /// lessons. Null when the server does not say: the preview then shows the
  /// weekly total only.
  final int? lessonMinutes;

  /// The option to preselect: the default, or the first when the server's
  /// default is not among its options.
  DailyGoalOption get defaultOption => options.firstWhere(
    (o) => o.minutes == defaultMinutes,
    orElse: () => options.first,
  );

  @override
  List<Object?> get props => [options, defaultMinutes, lessonMinutes];
}

/// The parts of the effective settings (after inheritance) the app reads
/// before a track is chosen.
final class EffectiveSettings extends Equatable {
  const EffectiveSettings({required this.reminder, required this.dailyGoal});

  final ReminderSettings reminder;
  final DailyGoalSettings dailyGoal;

  @override
  List<Object?> get props => [reminder, dailyGoal];
}
