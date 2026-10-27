import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_cubit.dart';
import 'package:englizia/features/onboarding/presentation/challenge/cubit/challenge_cubit.dart';
import 'package:englizia/features/onboarding/presentation/child_profile/cubit/child_profile_cubit.dart';
import 'package:englizia/features/onboarding/presentation/goal/cubit/goal_cubit.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_cubit.dart';
import 'package:englizia/features/onboarding/presentation/level/cubit/level_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reason/cubit/reason_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reminder/cubit/reminder_cubit.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/cubit/save_progress_cubit.dart';
import 'package:get_it/get_it.dart';

void registerOnboardingDependencies(GetIt sl) {
  sl
    ..registerFactory(() => AudienceCubit(sl()))
    ..registerFactory(() => GradeCubit(sl()))
    ..registerFactory(ChildProfileCubit.new)
    ..registerFactory(ReasonCubit.new)
    ..registerFactory(() => LevelCubit(sl(), sl(), sl()))
    ..registerFactory(() => GoalCubit(sl()))
    ..registerFactory(() => ChallengeCubit(sl()))
    ..registerFactory(() => ReminderCubit(sl(), sl()))
    ..registerFactory(() => SaveProgressCubit(sl(), sl(), sl()));
}
