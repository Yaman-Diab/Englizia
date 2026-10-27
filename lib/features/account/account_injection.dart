import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/account/presentation/sign_up/cubit/sign_up_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerAccountDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<AccountRemoteDataSource>(
      () => AppConfig.isMock
          ? AccountFakeDataSource(rootBundle)
          : AccountRemoteDataSourceImpl(sl()),
    )
    ..registerFactory(() => SignUpCubit(sl(), sl()))
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        sl(),
        installationId: sl<SettingsStorageService>().installationId,
        devicePlatform: _devicePlatform(),
      ),
    );
}

// ASSUMPTION(api): `DevicePlatform` has no `ios` yet (docs/api/README.md,
// request 1), so an iPhone sends null, which the contract allows.
String? _devicePlatform() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  _ => null,
};
