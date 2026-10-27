import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerAccountDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<AccountRemoteDataSource>(
      () => AppConfig.isMock
          ? AccountFakeDataSource(rootBundle)
          : AccountRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        sl(),
        installationId: sl<SettingsStorageService>().installationId,
      ),
    );
}
