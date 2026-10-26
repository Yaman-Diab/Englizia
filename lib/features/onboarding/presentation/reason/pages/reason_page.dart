import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/features/onboarding/domain/entities/learning_reason.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/reason/cubit/reason_cubit.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_option.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding "why are you learning English?" (requirements v3.0 §4.2):
/// several reasons may be chosen, and the guide replies to the latest one.
/// Shown to everyone except the child path.
class ReasonPage extends StatelessWidget {
  const ReasonPage({
    required this.path,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  /// The branch the learner is on, for the progress bar.
  final OnboardingPath path;
  final ValueChanged<List<LearningReason>> onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final position = onboardingPosition(OnboardingStep.reason, path: path);
    return BlocBuilder<ReasonCubit, ReasonState>(
      builder: (context, state) {
        final cubit = context.read<ReasonCubit>();
        return OnboardingQuestionScaffold(
          question: switch (state.latest) {
            null => 'onboarding_reason_question'.tr(),
            final reason => _reply(reason),
          },
          subtitle: 'onboarding_reason_subtitle'.tr(),
          expression: state.picks.isEmpty
              ? MascotExpression.curious
              : MascotExpression.happy,
          step: position.current,
          totalSteps: position.total,
          continueLabel: 'common_continue'.tr(),
          onContinue: state.canContinue ? () => onContinue(state.picks) : null,
          onBack: onBack,
          options: [
            for (final reason in LearningReason.values)
              OnboardingOption(
                icon: _icon(reason),
                iconTone: _tone(reason),
                title: _title(reason),
                selected: state.picks.contains(reason),
                multiple: true,
                onTap: () => cubit.toggle(reason),
              ),
          ],
        );
      },
    );
  }

  static AppIcon _icon(LearningReason reason) => switch (reason) {
    LearningReason.communication => AppIcon.chat,
    LearningReason.fun => AppIcon.sparkle,
    LearningReason.education => AppIcon.graduationCap,
    LearningReason.travel => AppIcon.plane,
    LearningReason.career => AppIcon.briefcase,
    LearningReason.exams => AppIcon.examSheet,
  };

  static TileTone _tone(LearningReason reason) => switch (reason) {
    LearningReason.communication => TileTone.blue,
    LearningReason.fun => TileTone.amber,
    LearningReason.education => TileTone.green,
    LearningReason.travel => TileTone.sky,
    LearningReason.career => TileTone.orange,
    LearningReason.exams => TileTone.navy,
  };

  static String _title(LearningReason reason) => switch (reason) {
    LearningReason.communication => 'onboarding_reason_communication'.tr(),
    LearningReason.fun => 'onboarding_reason_fun'.tr(),
    LearningReason.education => 'onboarding_reason_education'.tr(),
    LearningReason.travel => 'onboarding_reason_travel'.tr(),
    LearningReason.career => 'onboarding_reason_career'.tr(),
    LearningReason.exams => 'onboarding_reason_exams'.tr(),
  };

  static String _reply(LearningReason reason) => switch (reason) {
    LearningReason.communication =>
      'onboarding_reason_communication_reply'.tr(),
    LearningReason.fun => 'onboarding_reason_fun_reply'.tr(),
    LearningReason.education => 'onboarding_reason_education_reply'.tr(),
    LearningReason.travel => 'onboarding_reason_travel_reply'.tr(),
    LearningReason.career => 'onboarding_reason_career_reply'.tr(),
    LearningReason.exams => 'onboarding_reason_exams_reply'.tr(),
  };
}
