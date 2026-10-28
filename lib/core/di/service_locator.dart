import 'package:dio/dio.dart';
import 'package:englizia/core/audio/device_volume.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/app_headers_interceptor.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/network/dio_factory.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/storage/secure_token_storage.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

/// Shared kernel registrations. Features register themselves in their own
/// `<feature>_injection.dart`, wired from `app/di.dart`.
///
/// `sl<>()` is used only here, in `app/`, and in `BlocProvider.create`.
Future<void> setupCoreDependencies(GetIt sl) async {
  final prefs = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();

  sl
    ..registerLazySingleton(() => SettingsStorageService(prefs))
    ..registerLazySingleton<TokenStorage>(SecureTokenStorage.new)
    ..registerLazySingleton(CurrentLanguage.new)
    ..registerLazySingleton(
      () => AppSessionController(tokens: sl(), settings: sl()),
    )
    ..registerLazySingleton(
      () => AppHeadersInterceptor(
        languageCode: () => sl<CurrentLanguage>().code,
        appVersion: packageInfo.version,
        platform: _platformName(),
      ),
    )
    ..registerLazySingleton<TokenRefresher>(
      () => TokenRefreshService(
        DioFactory.createRefreshDio(
          baseUrl: AppConfig.baseUrl,
          headers: sl<AppHeadersInterceptor>(),
        ),
      ),
    )
    ..registerLazySingleton<Dio>(
      () => DioFactory.createMainDio(
        baseUrl: AppConfig.baseUrl,
        headers: sl<AppHeadersInterceptor>(),
        tokens: sl(),
        refresher: sl(),
        onSessionExpired: sl<AppSessionController>().expire,
      ),
    )
    ..registerLazySingleton(() => ApiClient(sl()))
    ..registerLazySingleton<ConnectivityService>(PlusConnectivityService.new)
    ..registerLazySingleton<NotificationPermission>(
      () => const PlatformNotificationPermission(),
    )
    // Silent until sounds are turned on (ADR 9).
    ..registerLazySingleton<SoundPlayer>(() => const SilentSoundPlayer())
    ..registerLazySingleton<DeviceVolume>(() => const UnknownDeviceVolume())
    ..registerFactory(() => SettingsCubit(sl()));
}

String _platformName() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  final other => other.name,
};
