import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:englizia/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerSettingsDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<SettingsRemoteDataSource>(
      () => AppConfig.isMock
          ? SettingsFakeDataSource(rootBundle)
          : SettingsRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(sl()),
    );
}
