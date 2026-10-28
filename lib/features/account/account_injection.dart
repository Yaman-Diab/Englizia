import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/account/presentation/account/cubit/account_cubit.dart';
import 'package:englizia/features/account/presentation/forgot_password/cubit/forgot_password_cubit.dart';
import 'package:englizia/features/account/presentation/sign_in/cubit/sign_in_cubit.dart';
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
    ..registerFactoryParam<SignUpCubit, bool, void>(
      (upgradesGuest, _) => SignUpCubit(sl(), upgradesGuest: upgradesGuest),
    )
    ..registerFactory(() => AccountCubit(sl(), sl()))
    ..registerFactoryParam<ForgotPasswordCubit, String, void>(
      (email, _) => ForgotPasswordCubit(sl(), email: email),
    )
    ..registerFactoryParam<SignInCubit, String, void>(
      (email, _) => SignInCubit(sl(), email: email),
    )
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        sl(),
        tokens: sl(),
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
