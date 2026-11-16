import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/session/device_platform.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/notifications/data/datasources/push_token_remote_data_source.dart';
import 'package:englizia/features/notifications/data/repositories/push_token_repository_impl.dart';
import 'package:englizia/features/notifications/data/services/push_token_sync.dart';
import 'package:englizia/features/notifications/domain/repositories/push_token_repository.dart';
import 'package:englizia/features/notifications/presentation/banner/cubit/in_app_notifications_cubit.dart';
import 'package:englizia/features/notifications/presentation/off_card/cubit/notifications_card_cubit.dart';
import 'package:englizia/features/notifications/presentation/prompt/cubit/notification_prompt_cubit.dart';
import 'package:get_it/get_it.dart';

void registerNotificationsDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<PushTokenRemoteDataSource>(
      () => AppConfig.isMock
          ? PushTokenFakeDataSource()
          : PushTokenRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<PushTokenRepository>(
      () => PushTokenRepositoryImpl(
        sl(),
        devicePlatform: devicePlatform(),
        deviceId: () => sl<SettingsStorageService>().deviceId,
      ),
    )
    ..registerLazySingleton(() => PushTokenSync(sl(), sl(), sl(), sl(), sl()))
    // App-scoped: `App` creates one and provides it above the router.
    ..registerFactory(() => InAppNotificationsCubit(sl()))
    ..registerFactory(
      () => NotificationPromptCubit(sl(), sl(), sl(), sl(), sl(), sl()),
    )
    ..registerFactory(() => NotificationsCardCubit(sl(), sl(), sl()));
}
