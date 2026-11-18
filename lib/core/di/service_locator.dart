import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/audio/asset_sound_player.dart';
import 'package:englizia/core/audio/clip_player.dart';
import 'package:englizia/core/audio/device_volume.dart';
import 'package:englizia/core/audio/just_audio_backend.dart';
import 'package:englizia/core/audio/just_audio_clip_player.dart';
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/audio/mock_clips.dart';
import 'package:englizia/core/audio/sound_player.dart';
import 'package:englizia/core/audio/speech_listener.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/config/app_info.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/links/app_store.dart';
import 'package:englizia/core/links/external_link.dart';
import 'package:englizia/core/links/share_sheet.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/mail/mail_app.dart';
import 'package:englizia/core/media/device_storage.dart';
import 'package:englizia/core/media/kept_media.dart';
import 'package:englizia/core/media/media_vault.dart';
import 'package:englizia/core/media/vault_cipher.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/app_headers_interceptor.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/network/dio_factory.dart';
import 'package:englizia/core/network/media_client.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/network/update_required.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/notifications/push_channel.dart';
import 'package:englizia/core/security/screen_protection.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/device_platform.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/storage/secure_token_storage.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

/// Shared kernel registrations. Features register themselves in their own
/// `<feature>_injection.dart`, wired from `app/di.dart`.
///
/// `sl<>()` is used only here, in `app/`, and in `BlocProvider.create`.
Future<void> setupCoreDependencies(GetIt sl) async {
  final prefs = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();
  final vault = await _openVault();
  KeptMedia.vault = vault;

  sl
    ..registerSingleton(
      AppInfo(
        version: packageInfo.version,
        packageName: packageInfo.packageName,
      ),
    )
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
    ..registerLazySingleton(UpdateRequiredSignal.new)
    ..registerLazySingleton<Dio>(
      () => DioFactory.createMainDio(
        baseUrl: AppConfig.baseUrl,
        headers: sl<AppHeadersInterceptor>(),
        tokens: sl(),
        refresher: sl(),
        onSessionExpired: sl<AppSessionController>().expire,
        updateRequired: sl(),
      ),
    )
    ..registerLazySingleton(() => ApiClient(sl()))
    ..registerLazySingleton<ConnectivityService>(PlusConnectivityService.new)
    ..registerLazySingleton<NotificationPermission>(
      () => const PlatformNotificationPermission(),
    )
    // The server's notifications (ADR 21); the dev page's in mock mode.
    ..registerLazySingleton<PushChannel>(
      () => AppConfig.isMock ? MockPushChannel() : FirebasePushChannel(),
    )
    // The app's sounds (ADR 9), off with the «المؤثرات الصوتية» setting.
    ..registerLazySingleton<SoundPlayer>(
      () => AssetSoundPlayer(
        JustAudioBackend(),
        enabled: () => sl<SettingsStorageService>().soundEffects,
      ),
    )
    // Clips from the server; in mock mode, the mock's own spoken files.
    ..registerLazySingleton<ClipPlayer>(
      () => JustAudioClipPlayer(
        sounds: sl(),
        bundled: AppConfig.isMock ? MockClips.assetFor : null,
        kept: vault.playable,
        failsFirstLoad: AppConfig.isMock,
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
    ..registerLazySingleton<ShareSheet>(() => const PlatformShareSheet())
    ..registerSingleton<MediaVault>(vault)
    ..registerLazySingleton<MediaClient>(
      () => AppConfig.isMock ? const FakeMediaClient() : DioMediaClient(),
    )
    ..registerLazySingleton<DeviceStorage>(() => const PlatformDeviceStorage())
    ..registerLazySingleton(
      () => AppStore(
        sl(),
        packageName: packageInfo.packageName,
        platform: devicePlatform(),
      ),
    )
    ..registerFactory(() => SettingsCubit(sl()));
}

String _platformName() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  final other => other.name,
};

/// The downloaded lessons' vault, in the app's own support folder: not the
/// cache, which the system empties, and nowhere another app can read
/// (ADR 22). A phone that gives no folder keeps nothing.
Future<MediaVault> _openVault() async {
  try {
    final support = await getApplicationSupportDirectory();
    return FileMediaVault(
      root: Directory('${support.path}/media'),
      cipher: VaultCipher(const SecureVaultKeyStore()),
    );
  } on MissingPluginException {
    // No such plugin where the app's tests run.
    return const NoMediaVault();
  } on Object catch (error, stackTrace) {
    AppLogger.error(error, stackTrace, 'No folder for downloads');
    return const NoMediaVault();
  }
}
