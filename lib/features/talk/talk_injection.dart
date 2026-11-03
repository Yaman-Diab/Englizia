import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/features/talk/data/datasources/talk_remote_data_source.dart';
import 'package:englizia/features/talk/data/repositories/talk_repository_impl.dart';
import 'package:englizia/features/talk/domain/repositories/talk_repository.dart';
import 'package:englizia/features/talk/presentation/conversation/cubit/conversation_cubit.dart';
import 'package:englizia/features/talk/presentation/talk/cubit/talk_cubit.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

void registerTalkDependencies(GetIt sl) {
  sl
    ..registerLazySingleton<TalkRemoteDataSource>(
      () => AppConfig.isMock
          ? TalkFakeDataSource(rootBundle)
          : TalkRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<TalkRepository>(
      () => TalkRepositoryImpl(sl(), sl()),
    )
    ..registerFactory(() => TalkCubit(sl(), sl()))
    ..registerFactoryParam<ConversationCubit, String, void>(
      (scenarioId, _) => ConversationCubit(sl(), sl(), scenarioId: scenarioId),
    );
}
