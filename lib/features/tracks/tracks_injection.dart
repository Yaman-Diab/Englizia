import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/features/tracks/data/datasources/track_remote_data_source.dart';
import 'package:englizia/features/tracks/data/repositories/track_repository_impl.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerTracksDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<TrackRemoteDataSource>(
      () => AppConfig.isMock
          ? TrackFakeDataSource(rootBundle)
          : TrackRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TrackRepository>(() => TrackRepositoryImpl(sl()));
}
