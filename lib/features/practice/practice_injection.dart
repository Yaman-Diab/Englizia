import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:englizia/features/practice/data/repositories/practice_repository_impl.dart';
import 'package:englizia/features/practice/domain/repositories/practice_repository.dart';
import 'package:englizia/features/practice/presentation/kids/cubit/kid_words_cubit.dart';
import 'package:englizia/features/practice/presentation/practice/cubit/practice_cubit.dart';
import 'package:englizia/features/practice/presentation/review/cubit/review_cubit.dart';
import 'package:englizia/features/practice/presentation/words/cubit/my_words_cubit.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerPracticeDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<PracticeRemoteDataSource>(
      () => AppConfig.isMock
          ? PracticeFakeDataSource(rootBundle, kids: AppConfig.isKidsMock)
          : PracticeRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<PracticeRepository>(
      () => PracticeRepositoryImpl(sl(), sl()),
    )
    ..registerFactory(() => PracticeCubit(sl()))
    ..registerFactory(() => ReviewCubit(sl(), sl()))
    ..registerFactory(() => MyWordsCubit(sl(), sl()))
    ..registerFactory(() => KidWordsCubit(sl(), sl()));
}
