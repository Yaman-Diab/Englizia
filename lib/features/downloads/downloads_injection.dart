import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/media/media_vault.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/downloads/data/datasources/download_remote_data_source.dart';
import 'package:englizia/features/downloads/data/repositories/download_repository_impl.dart';
import 'package:englizia/features/downloads/domain/repositories/download_repository.dart';
import 'package:englizia/features/downloads/presentation/downloads/cubit/downloads_cubit.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerDownloadsDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<DownloadRemoteDataSource>(
      () => AppConfig.isMock
          ? DownloadFakeDataSource(rootBundle)
          : DownloadRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<DownloadRepository>(
      () => DownloadRepositoryImpl(
        sl(),
        client: sl(),
        vault: sl(),
        settings: sl(),
        connectivity: sl(),
        storage: sl(),
        canKeep: sl<MediaVault>() is! NoMediaVault,
        // The panel's limits, read with the rest of the effective settings.
        limits: () async =>
            switch (await sl<SettingsRepository>().getSettings()) {
              Ok(:final value) => value.downloads,
              Err() => null,
            },
      ),
    )
    // One for the whole app: a download goes on while screens change.
    ..registerLazySingleton(() => DownloadsCubit(sl()));

  // The downloads are the account's: they go with it, and so does their key.
  sl<AppSessionController>().onClearing(() async {
    await sl<DownloadRepository>().removeAll();
    await sl<MediaVault>().clear();
  });
}
