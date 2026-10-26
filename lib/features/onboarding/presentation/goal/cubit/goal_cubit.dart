import 'package:englizia/features/onboarding/presentation/choice_step/choice_step_cubit.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';

typedef GoalState = ChoiceStepState<DailyGoalSettings>;

/// "What is your daily learning goal?": minutes a day, as the panel offers
/// them, with its default preselected (requirements v3.0 §4.2).
class GoalCubit extends ChoiceStepCubit<DailyGoalSettings> {
  GoalCubit(super.settings);

  @override
  DailyGoalSettings partOf(EffectiveSettings settings) => settings.dailyGoal;

  @override
  List<int> valuesOf(DailyGoalSettings settings) => [
    for (final option in settings.options) option.minutes,
  ];

  @override
  int defaultOf(DailyGoalSettings settings) => settings.defaultOption.minutes;
}
