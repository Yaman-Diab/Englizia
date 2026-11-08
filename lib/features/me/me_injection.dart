import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';
import 'package:englizia/features/me/data/repositories/profile_repository_impl.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerMeDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => AppConfig.isMock
          ? ProfileFakeDataSource(rootBundle, kids: AppConfig.isKidsMock)
          : ProfileRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(sl(), settings: sl()),
    )
    ..registerFactory(
      () => MeCubit(
        sl(),
        sl(),
        isGuest: () => sl<AppSessionController>().status == SessionStatus.guest,
      ),
    );
}
