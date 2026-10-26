import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';

/// The effective settings the app reads; contract in docs/api/settings.md.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/settings.md).
final class EffectiveSettingsModel {
  const EffectiveSettingsModel(this.entity);

  factory EffectiveSettingsModel.fromJson(Map<String, Object?> json) {
    final notifications = json.readMap('notifications');
    final motivation = json.readMap('motivation');
    return EffectiveSettingsModel(
      EffectiveSettings(
        reminder: _reminder(notifications),
        dailyGoal: _dailyGoal(motivation),
        challenge: _challenge(motivation),
      ),
    );
  }

  final EffectiveSettings entity;

  static ReminderSettings _reminder(Map<String, Object?>? notifications) {
    final reminder = notifications?.readMap('dailyReminder');
    final presets = [
      for (final item in notifications?.readList('reminderTimes') ?? const [])
        ?_preset(item),
    ];
    final title = reminder?.readText('title');
    final body = reminder?.readText('body');
    if (presets.isEmpty || title == null || body == null) {
      throw const FormatException('Reminder settings are incomplete');
    }
    return ReminderSettings(
      presets: presets,
      defaultSlot:
          _slot(notifications?.readString('defaultReminderSlot')) ??
          presets.last.slot,
      title: title,
      body: body,
    );
  }

  static DailyGoalSettings _dailyGoal(Map<String, Object?>? motivation) {
    final options = [
      for (final item in motivation?.readList('dailyGoalOptions') ?? const [])
        ?_option(item),
    ]..sort((a, b) => a.minutes.compareTo(b.minutes));
    final defaultMinutes = motivation?.readInt('defaultDailyGoal');
    if (options.isEmpty || defaultMinutes == null) {
      throw const FormatException('Daily goal settings are incomplete');
    }
    final lesson = motivation?.readInt('averageLessonMinutes');
    return DailyGoalSettings(
      options: options,
      defaultMinutes: defaultMinutes,
      lessonMinutes: lesson != null && lesson > 0 ? lesson : null,
    );
  }

  static ChallengeSettings _challenge(Map<String, Object?>? motivation) {
    final options = [
      for (final item in motivation?.readList('challengeOptions') ?? const [])
        ?_challengeOption(item),
    ]..sort((a, b) => a.days.compareTo(b.days));
    final defaultDays = motivation?.readInt('defaultChallenge');
    final question = motivation?.readText('challengeQuestion');
    if (options.isEmpty || defaultDays == null || question == null) {
      throw const FormatException('Challenge settings are incomplete');
    }
    return ChallengeSettings(
      options: options,
      defaultDays: defaultDays,
      question: question,
    );
  }

  /// An option without days or label is skipped, not fatal.
  static ChallengeOption? _challengeOption(Object? item) {
    if (item is! Map) return null;
    final json = item.cast<String, Object?>();
    final days = json.readInt('days');
    final label = json.readText('label');
    if (days == null || days <= 0 || label == null) return null;
    return ChallengeOption(days: days, label: label);
  }

  /// An option without minutes or label is skipped, not fatal.
  static DailyGoalOption? _option(Object? item) {
    if (item is! Map) return null;
    final json = item.cast<String, Object?>();
    final minutes = json.readInt('minutes');
    final label = json.readText('label');
    if (minutes == null || minutes <= 0 || label == null) return null;
    return DailyGoalOption(minutes: minutes, label: label);
  }

  /// An unknown slot or a malformed time is skipped, not fatal.
  static ReminderPreset? _preset(Object? item) {
    if (item is! Map) return null;
    final json = item.cast<String, Object?>();
    final slot = _slot(json.readString('slot'));
    final time = _time(json.readString('time'));
    if (slot == null || time == null) return null;
    return ReminderPreset(slot: slot, time: time);
  }

  static ReminderSlot? _slot(String? value) => switch (value) {
    'morning' => ReminderSlot.morning,
    'noon' => ReminderSlot.noon,
    'evening' => ReminderSlot.evening,
    _ => null,
  };

  /// "HH:mm" on a 24-hour clock.
  static ReminderTime? _time(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return ReminderTime(hour, minute);
  }
}
