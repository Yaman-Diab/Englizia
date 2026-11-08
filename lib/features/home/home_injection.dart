import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/home/data/datasources/home_remote_data_source.dart';
import 'package:englizia/features/home/data/repositories/home_repository_impl.dart';
import 'package:englizia/features/home/domain/repositories/home_repository.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerHomeDependencies(GetIt sl) {
  if (AppConfig.isMock) {
    // The mock follows the active track wherever it is switched, and counts
    // the lessons completed on this phone as the server would.
    sl.registerLazySingleton<HomeMockControls>(
      () => HomeFakeDataSource(
        rootBundle,
        kids: AppConfig.isKidsMock,
        activeEnrollmentId: () async =>
            switch (await sl<ProfileRepository>().getProfile()) {
              Ok(:final value) => value.active?.enrollmentId,
              Err() => null,
            },
        completedOnPhone: (id) => sl<LessonRepository>().onPhone(id).done,
      ),
    );
  }
  sl
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(
        AppConfig.isMock
            ? sl<HomeMockControls>()
            : HomeRemoteDataSourceImpl(sl()),
        settings: sl(),
      ),
    )
    ..registerFactory(
      () => HomeCubit(
        sl(),
        sl(),
        sl(),
        sl(),
        sl(),
        player: sl(),
        now: AppConfig.isMock ? () => sl<HomeMockControls>().now() : null,
      ),
    );
}
