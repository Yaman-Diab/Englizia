import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/notifications/domain/entities/reminder_settings.dart';

abstract interface class ReminderSettingsRepository {
  /// The reminder times and the daily reminder's text, as configured.
  Future<Result<ReminderSettings>> getReminderSettings();
}
