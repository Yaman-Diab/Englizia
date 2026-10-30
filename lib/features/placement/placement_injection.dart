import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/features/placement/data/datasources/placement_remote_data_source.dart';
import 'package:englizia/features/placement/data/repositories/placement_repository_impl.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';
import 'package:englizia/features/placement/presentation/intro/cubit/placement_intro_cubit.dart';
import 'package:englizia/features/placement/presentation/test/cubit/placement_test_cubit.dart';
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
      () => PlacementRepositoryImpl(sl(), settings: sl()),
    )
    ..registerFactory(() => PlacementIntroCubit(sl(), sl(), sl(), sl()))
    ..registerFactory(() => PlacementTestCubit(sl(), sl()));
}
