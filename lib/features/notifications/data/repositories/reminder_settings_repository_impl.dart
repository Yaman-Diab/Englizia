import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/notifications/data/datasources/reminder_settings_remote_data_source.dart';
import 'package:englizia/features/notifications/domain/entities/reminder_settings.dart';
import 'package:englizia/features/notifications/domain/repositories/reminder_settings_repository.dart';

final class ReminderSettingsRepositoryImpl
    implements ReminderSettingsRepository {
  const ReminderSettingsRepositoryImpl(this._remote);

  final ReminderSettingsRemoteDataSource _remote;

  @override
  Future<Result<ReminderSettings>> getReminderSettings() =>
      guard(() async => (await _remote.getReminderSettings()).entity);
}
