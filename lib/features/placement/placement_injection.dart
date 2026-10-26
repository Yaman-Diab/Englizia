import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/repositories/placement_repository_impl.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerPlacementDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<PlacementRemoteDataSource>(
      () => AppConfig.isMock
          ? PlacementFakeDataSource(rootBundle)
          : PlacementRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<PlacementRepository>(
      () => PlacementRepositoryImpl(sl()),
    );
}
