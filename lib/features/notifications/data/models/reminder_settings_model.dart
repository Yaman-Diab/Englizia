import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/notifications/domain/entities/reminder_settings.dart';

/// The reminder parts of the effective settings; contract in
/// docs/api/settings.md.
// ASSUMPTION(api): field names proposed, not confirmed (docs/api/settings.md).
final class ReminderSettingsModel {
  const ReminderSettingsModel(this.entity);

  factory ReminderSettingsModel.fromJson(Map<String, Object?> json) {
    final notifications = json.readMap('notifications');
    final reminder = notifications?.readMap('dailyReminder');
    final presets = [
      for (final item in notifications?.readList('reminderTimes') ?? const [])
        ?_preset(item),
    ];
    final title = reminder?.readText('title');
    final body = reminder?.readText('body');
    final goal = json.readMap('motivation')?.readInt('defaultDailyGoal');
    if (presets.isEmpty || title == null || body == null || goal == null) {
      throw const FormatException('Reminder settings are incomplete');
    }
    return ReminderSettingsModel(
      ReminderSettings(
        presets: presets,
        defaultSlot:
            _slot(notifications?.readString('defaultReminderSlot')) ??
            presets.last.slot,
        title: title,
        body: body,
        dailyGoalMinutes: goal,
      ),
    );
  }

  final ReminderSettings entity;

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
