import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/features/notifications/data/datasources/reminder_settings_remote_data_source.dart';
import 'package:englizia/features/notifications/data/repositories/reminder_settings_repository_impl.dart';
import 'package:englizia/features/notifications/domain/repositories/reminder_settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerNotificationsDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<ReminderSettingsRemoteDataSource>(
      () => AppConfig.isMock
          ? ReminderSettingsFakeDataSource(rootBundle)
          : ReminderSettingsRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<ReminderSettingsRepository>(
      () => ReminderSettingsRepositoryImpl(sl()),
    );
}
