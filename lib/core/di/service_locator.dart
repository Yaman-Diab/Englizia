import 'package:dio/dio.dart';
import 'package:englizia/core/audio/asset_sound_player.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/audio/device_volume.dart';
import 'package:englizia/core/audio/just_audio_backend.dart';
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/audio/speech_listener.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/config/app_info.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/links/external_link.dart';
import 'package:englizia/core/mail/mail_app.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/app_headers_interceptor.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/network/dio_factory.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/security/screen_protection.dart';
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
    ..registerSingleton(AppInfo(version: packageInfo.version))
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
    // The app's sounds (ADR 9), off with the «المؤثرات الصوتية» setting.
    ..registerLazySingleton<SoundPlayer>(
      () => AssetSoundPlayer(
        JustAudioBackend(),
        enabled: () => sl<SettingsStorageService>().soundEffects,
      ),
    )
    ..registerLazySingleton<ClipPlayer>(
      () => SilentClipPlayer(
        failsFirstLoad: AppConfig.isMock,
        latency: AppConfig.isMock
            ? const Duration(milliseconds: 500)
            : Duration.zero,
      ),
    )
    ..registerLazySingleton<SpeechListener>(DeviceSpeechListener.new)
    ..registerLazySingleton<MicPermission>(() => const PlatformMicPermission())
    ..registerFactory(() => MicCubit(sl(), sl(), sounds: sl()))
    ..registerLazySingleton<DeviceVolume>(PlatformDeviceVolume.new)
    ..registerLazySingleton<MailApp>(() => const PlatformMailApp())
    // A lesson's video out of screenshots and recordings (ADR 18).
    ..registerLazySingleton<ScreenProtection>(PlatformScreenProtection.new)
    ..registerLazySingleton<ExternalLink>(() => const PlatformExternalLink())
    ..registerFactory(() => SettingsCubit(sl()));
}

String _platformName() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  final other => other.name,
};
