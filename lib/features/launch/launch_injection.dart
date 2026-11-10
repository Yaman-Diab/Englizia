import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/launch/presentation/update_reminder/update_reminder.dart';
import 'package:get_it/get_it.dart';

void registerLaunchDependencies(GetIt sl) {
  sl
    ..registerLazySingleton(() => UpdateReminder(sl()))
    ..registerFactory(
      () => SplashCubit(
        session: sl(),
        settings: sl(),
        connectivity: sl(),
        app: sl(),
        store: sl(),
      ),
    );
}
