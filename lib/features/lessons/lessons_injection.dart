import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/repositories/lesson_repository_impl.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerLessonDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<LessonRemoteDataSource>(
      () => AppConfig.isMock
          ? LessonFakeDataSource(rootBundle)
          : LessonRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<LessonRepository>(
      () => LessonRepositoryImpl(sl(), settings: sl()),
    )
    ..registerFactoryParam<ExerciseCubit, String, void>(
      (lessonId, _) => ExerciseCubit(sl(), sl(), sl(), lessonId: lessonId),
    );
}
