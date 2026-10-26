import 'package:englizia/features/onboarding/presentation/choice_step/choice_step_cubit.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';

typedef ChallengeState = ChoiceStepState<ChallengeSettings>;

/// "How many days will you challenge yourself?": the challenge lengths the
/// panel offers, with its default preselected (requirements v3.0 §4.2).
class ChallengeCubit extends ChoiceStepCubit<ChallengeSettings> {
  ChallengeCubit(super.settings);

  @override
  ChallengeSettings partOf(EffectiveSettings settings) => settings.challenge;

  @override
  List<int> valuesOf(ChallengeSettings settings) => [
    for (final option in settings.options) option.days,
  ];

  @override
  int defaultOf(ChallengeSettings settings) => settings.defaultOption.days;
}
