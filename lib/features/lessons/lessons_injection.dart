import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/video/silent_audio_engine.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/core/video/video_player_engine.dart';
import 'package:englizia/features/lessons/data/answers_sync.dart';
import 'package:englizia/features/lessons/data/datasources/concept_remote_data_source.dart';
import 'package:englizia/features/lessons/data/datasources/explain_remote_data_source.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/datasources/teacher_question_remote_data_source.dart';
import 'package:englizia/features/lessons/data/repositories/concept_repository_impl.dart';
import 'package:englizia/features/lessons/data/repositories/explain_repository_impl.dart';
import 'package:englizia/features/lessons/data/repositories/lesson_repository_impl.dart';
import 'package:englizia/features/lessons/data/repositories/teacher_question_repository_impl.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/repositories/concept_repository.dart';
import 'package:englizia/features/lessons/domain/repositories/explain_repository.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/lessons/domain/repositories/teacher_question_repository.dart';
import 'package:englizia/features/lessons/presentation/complete/cubit/lesson_complete_cubit.dart';
import 'package:englizia/features/lessons/presentation/concepts/cubit/concept_session_cubit.dart';
import 'package:englizia/features/lessons/presentation/concepts/cubit/concepts_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/explain/cubit/explain_cubit.dart';
import 'package:englizia/features/lessons/presentation/grammar/cubit/grammar_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/grammar/cubit/teacher_questions_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_text_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_video_cubit.dart';
import 'package:englizia/features/lessons/presentation/shadowing/cubit/shadowing_cubit.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/cubit/vocab_lesson_cubit.dart';
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
    ..registerLazySingleton<TeacherQuestionRemoteDataSource>(
      () => AppConfig.isMock
          ? TeacherQuestionFakeDataSource(rootBundle)
          : TeacherQuestionRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TeacherQuestionRepository>(
      () => TeacherQuestionRepositoryImpl(sl()),
    )
    ..registerFactory<VideoEngine>(VideoPlayerEngine.new)
    ..registerFactoryParam<GrammarLessonCubit, String, void>(
      (lessonId, _) => GrammarLessonCubit(sl(), sl(), sl(), lessonId: lessonId),
    )
    ..registerFactoryParam<TeacherQuestionsCubit, String, void>(
      (lessonId, _) => TeacherQuestionsCubit(sl(), lessonId: lessonId),
    )
    ..registerFactoryParam<InteractiveTextCubit, String, void>(
      (lessonId, _) => InteractiveTextCubit(
        sl(),
        // The mock's sound is silent, but its time passes (D-050).
        AppConfig.isMock ? SilentAudioEngine() : sl<VideoEngine>(),
        lessonId: lessonId,
      ),
    )
    ..registerFactoryParam<InteractiveVideoCubit, String, void>(
      (lessonId, _) => InteractiveVideoCubit(sl(), sl(), lessonId: lessonId),
    )
    ..registerFactoryParam<VocabLessonCubit, String, void>(
      (lessonId, _) => VocabLessonCubit(sl(), sl(), sl(), lessonId: lessonId),
    )
    ..registerFactoryParam<ShadowingCubit, String, void>(
      (lessonId, _) => ShadowingCubit(
        sl(),
        // The mock's sound is silent, but its time passes (D-050).
        AppConfig.isMock ? SilentAudioEngine() : sl<VideoEngine>(),
        lessonId: lessonId,
      ),
    )
    ..registerLazySingleton<ConceptRemoteDataSource>(
      () => AppConfig.isMock
          ? ConceptFakeDataSource(rootBundle)
          : ConceptRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<ConceptRepository>(
      () => ConceptRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton<ExplainRemoteDataSource>(
      () => AppConfig.isMock
          ? ExplainFakeDataSource(rootBundle)
          : ExplainRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<ExplainRepository>(
      () => ExplainRepositoryImpl(sl()),
    )
    ..registerFactoryParam<ExplainCubit, ExplainRequest, void>(
      (request, _) => ExplainCubit(sl(), sl(), request: request),
    )
    ..registerFactory(() => ConceptsCubit(sl()))
    ..registerFactory(() => ConceptSessionCubit(sl(), sl()))
    ..registerLazySingleton(() => AnswersSync(sl(), sl(), sl()))
    ..registerFactoryParam<ExerciseCubit, String, void>(
      (lessonId, _) =>
          ExerciseCubit(sl(), sl(), sl(), sl(), lessonId: lessonId),
    )
    ..registerFactoryParam<LessonCompleteCubit, LessonSummary, void>(
      (summary, _) => LessonCompleteCubit(sl(), sl(), sl(), summary: summary),
    );
  sl<AppSessionController>().onLeaving(
    () => sl<LessonRepository>().sendSaved(),
  );
}
