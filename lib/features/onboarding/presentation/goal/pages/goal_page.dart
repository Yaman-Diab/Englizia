import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/goal/cubit/goal_cubit.dart';
import 'package:englizia/features/onboarding/presentation/goal/widgets/goal_preview.dart';
import 'package:englizia/features/onboarding/presentation/widgets/loaded_answers.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_option.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding "what is your daily learning goal?" (requirements v3.0 §4.2,
/// in v1.0 per §27, built ahead of plan). The options, their wording and
/// the default come from the settings; the guide's mood and the preview
/// follow the chosen goal. Not on the child path (their goal is one value
/// set in the control panel).
class GoalPage extends StatelessWidget {
  const GoalPage({
    required this.path,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  /// The branch the learner is on, for the progress bar.
  final OnboardingPath path;

  /// The chosen goal in minutes.
  final ValueChanged<int> onContinue;
  final VoidCallback onBack;

  /// From the gentlest choice to the most thrilled; the options, however
  /// many the panel offers, are spread along it in order.
  static const _moods = [
    MascotExpression.calm,
    MascotExpression.confident,
    MascotExpression.excited,
    MascotExpression.ecstatic,
  ];

  static MascotExpression _moodOf(int index, int count) =>
      _moods[(index * _moods.length) ~/ count];

  @override
  Widget build(BuildContext context) {
    final position = onboardingPosition(OnboardingStep.goal, path: path);
    final languageCode = context.locale.languageCode;
    return BlocBuilder<GoalCubit, GoalState>(
      builder: (context, state) {
        final cubit = context.read<GoalCubit>();
        final settings = state.settings;
        final selected = state.selected;
        final index = settings?.options.indexWhere(
          (o) => o.minutes == selected,
        );
        return OnboardingQuestionScaffold(
          question: 'onboarding_goal_question'.tr(),
          expression: index == null || index < 0 || settings == null
              ? MascotExpression.curious
              : _moodOf(index, settings.options.length),
          step: position.current,
          totalSteps: position.total,
          continueLabel: 'onboarding_goal_cta'.tr(),
          onContinue: state.canContinue ? () => onContinue(selected!) : null,
          onBack: onBack,
          helper: 'onboarding_goal_helper'.tr(),
          helperIcon: Icons.info_outline_rounded,
          helperIsInfo: true,
          options: loadedAnswers(
            status: state.status,
            failure: state.failure,
            onRetry: () => cubit.load(),
            ready: () => [
              for (final option in settings!.options)
                OnboardingOption(
                  inline: true,
                  title: 'onboarding_goal_per_day'.plural(option.minutes),
                  description: option.label.of(languageCode),
                  selected: option.minutes == selected,
                  onTap: () => cubit.select(option.minutes),
                ),
            ],
          ),
          details: settings == null || selected == null
              ? null
              : GoalPreview(
                  minutes: selected,
                  lessonMinutes: settings.lessonMinutes,
                ),
        );
      },
    );
  }
}
