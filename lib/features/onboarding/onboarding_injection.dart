import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_cubit.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_cubit.dart';
import 'package:get_it/get_it.dart';

void registerOnboardingDependencies(GetIt sl) {
  sl
    ..registerFactory(() => AudienceCubit(sl()))
    ..registerFactory(() => GradeCubit(sl()));
}
