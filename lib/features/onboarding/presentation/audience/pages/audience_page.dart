import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_cubit.dart';
import 'package:englizia/features/onboarding/presentation/audience/cubit/audience_state.dart';
import 'package:englizia/features/onboarding/presentation/widgets/loaded_answers.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_option.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding "who will learn?" (requirements v3.0 §4.2). A choice whose
/// audience has no published track is «قريبًا», so the control panel turns
/// each option on or off through the tracks' "suggested for" setting.
class AudiencePage extends StatelessWidget {
  const AudiencePage({
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  final ValueChanged<OnboardingPath> onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudienceCubit, AudienceState>(
      builder: (context, state) {
        final cubit = context.read<AudienceCubit>();
        final position = onboardingPosition(
          OnboardingStep.audience,
          path: state.path ?? OnboardingPath.assumed,
        );
        return OnboardingQuestionScaffold(
          question: 'onboarding_audience_question'.tr(),
          expression: MascotExpression.curious,
          step: position.current,
          totalSteps: position.total,
          continueLabel: 'common_continue'.tr(),
          onContinue: state.canContinue ? () => onContinue(state.path!) : null,
          onBack: onBack,
          options: loadedAnswers(
            status: state.status,
            failure: state.failure,
            onRetry: cubit.load,
            ready: () => [
              for (final audience in TrackAudience.values)
                _AudienceOption(
                  audience: audience,
                  selected: state.selected == audience,
                  available: state.available.contains(audience),
                  onTap: () => cubit.select(audience),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AudienceOption extends StatelessWidget {
  const _AudienceOption({
    required this.audience,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final TrackAudience audience;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, description) = switch (audience) {
      TrackAudience.self => (
        'onboarding_audience_self_title'.tr(),
        'onboarding_audience_self_desc'.tr(),
      ),
      TrackAudience.child => (
        'onboarding_audience_child_title'.tr(),
        'onboarding_audience_child_desc'.tr(),
      ),
      TrackAudience.schoolStudent => (
        'onboarding_audience_school_title'.tr(),
        'onboarding_audience_school_desc'.tr(),
      ),
    };
    // ASSUMPTION(design): the guide dressed per audience replaces the
    // designs' human faces, pending the owner's approval (docs/STATUS.md).
    final (expression, prop) = switch (audience) {
      TrackAudience.self => (MascotExpression.understand, MascotProp.glasses),
      TrackAudience.child => (MascotExpression.welcome, MascotProp.beanie),
      TrackAudience.schoolStudent => (
        MascotExpression.encourage,
        MascotProp.gradCap,
      ),
    };
    return OnboardingOption(
      art: Mascot(
        expression: expression,
        prop: prop,
        framing: MascotFraming.head,
        size: 56,
        animate: false,
      ),
      title: title,
      description: description,
      selected: selected,
      soonLabel: available ? null : 'common_soon'.tr(),
      onTap: onTap,
    );
  }
}
