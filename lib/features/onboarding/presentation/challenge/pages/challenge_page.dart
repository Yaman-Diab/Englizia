import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/challenge/cubit/challenge_cubit.dart';
import 'package:englizia/features/onboarding/presentation/challenge/widgets/streak_calendar.dart';
import 'package:englizia/features/onboarding/presentation/widgets/loaded_answers.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_option.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding "how many days will you challenge yourself?" (requirements
/// v3.0 §4.2, in v1.0 per §27, built ahead of plan; design "Streak
/// Challenge"). The lengths, their wording, the default and the guide's
/// question come from the settings; a calendar shows the chosen number in
/// the streak color. Not on the child path.
class ChallengePage extends StatelessWidget {
  const ChallengePage({
    required this.path,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  /// The branch the learner is on, for the progress bar.
  final OnboardingPath path;

  /// The chosen challenge in days.
  final ValueChanged<int> onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final position = onboardingPosition(OnboardingStep.challenge, path: path);
    final languageCode = context.locale.languageCode;
    return BlocBuilder<ChallengeCubit, ChallengeState>(
      builder: (context, state) {
        final cubit = context.read<ChallengeCubit>();
        final settings = state.settings;
        final selected = state.selected;
        return OnboardingQuestionScaffold(
          question:
              settings?.question.of(languageCode) ??
              'onboarding_challenge_question'.tr(),
          expression: MascotExpression.curious,
          step: position.current,
          totalSteps: position.total,
          lead: selected == null ? null : StreakCalendar(days: selected),
          options: loadedAnswers(
            status: state.status,
            failure: state.failure,
            onRetry: () => cubit.load(),
            ready: () => [
              for (final option in settings!.options)
                OnboardingOption(
                  inline: true,
                  title: 'onboarding_challenge_days'.plural(option.days),
                  description: option.label.of(languageCode),
                  selected: option.days == selected,
                  onTap: () => cubit.select(option.days),
                ),
            ],
          ),
          helper: 'onboarding_challenge_helper'.tr(),
          helperIcon: Icons.info_outline_rounded,
          helperIsInfo: true,
          continueLabel: 'onboarding_challenge_cta'.tr(),
          onContinue: state.canContinue ? () => onContinue(selected!) : null,
          onBack: onBack,
        );
      },
    );
  }
}
