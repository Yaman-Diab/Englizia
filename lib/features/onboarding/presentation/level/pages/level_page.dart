import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/illustrations/app_illustration.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/swap.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/english_level_choice.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/level/cubit/level_cubit.dart';
import 'package:englizia/features/onboarding/presentation/level/cubit/level_state.dart';
import 'package:englizia/features/onboarding/presentation/level/widgets/level_details.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_notice.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_option.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding "how much English do you know?" (requirements v3.0 §4.2, in
/// v0.2 per §27) for tracks entered by placement test. A beginner starts
/// from the track's first level; anyone else takes the test now or later.
/// The test needs a connection; starting without it never does.
class LevelPage extends StatelessWidget {
  const LevelPage({
    required this.path,
    required this.onStartFromBeginning,
    required this.onTakeTest,
    required this.onTestLater,
    required this.onBack,
    super.key,
  });

  /// The branch the learner is on, for the progress bar.
  final OnboardingPath path;
  final VoidCallback onStartFromBeginning;
  final VoidCallback onTakeTest;
  final VoidCallback onTestLater;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final position = onboardingPosition(OnboardingStep.level, path: path);
    return BlocBuilder<LevelCubit, LevelState>(
      builder: (context, state) {
        final cubit = context.read<LevelCubit>();
        final languageCode = context.locale.languageCode;
        final levelName =
            state.firstLevel?.name.of(languageCode) ??
            'onboarding_level_first_level'.tr();
        final some = state.choice == EnglishLevelChoice.some;

        return OnboardingQuestionScaffold(
          question: switch (state.choice) {
            null => 'onboarding_level_question'.tr(),
            EnglishLevelChoice.beginner =>
              'onboarding_level_beginner_reply'.tr(),
            EnglishLevelChoice.some => 'onboarding_level_some_reply'.tr(),
          },
          // The designs' "encouraging" and "confident" moods.
          expression: switch (state.choice) {
            null => MascotExpression.curious,
            EnglishLevelChoice.beginner => MascotExpression.encourage,
            EnglishLevelChoice.some => MascotExpression.confident,
          },
          step: position.current,
          totalSteps: position.total,
          continueLabel: switch (state.choice) {
            null => 'common_continue'.tr(),
            EnglishLevelChoice.beginner => 'onboarding_level_beginner_cta'.tr(),
            EnglishLevelChoice.some => 'onboarding_level_take_test'.tr(),
          },
          onContinue: switch (state.choice) {
            null => null,
            EnglishLevelChoice.beginner => onStartFromBeginning,
            EnglishLevelChoice.some => state.canTakeTest ? onTakeTest : null,
          },
          secondaryLabel: some ? 'onboarding_level_test_later'.tr() : null,
          onSecondary: onTestLater,
          footnote: some
              ? 'onboarding_level_test_later_note'.tr(
                  namedArgs: {'level': levelName},
                )
              : null,
          onBack: onBack,
          options: [
            OnboardingOption(
              art: const AppIllustrationView(AppIllustration.hatching),
              title: 'onboarding_level_beginner'.tr(),
              description: 'onboarding_level_beginner_desc'.tr(),
              selected: state.choice == EnglishLevelChoice.beginner,
              large: true,
              onTap: () => cubit.choose(EnglishLevelChoice.beginner),
            ),
            OnboardingOption(
              art: const AppIllustrationView(AppIllustration.listening),
              title: 'onboarding_level_some'.tr(),
              description: 'onboarding_level_some_desc'.tr(),
              selected: some,
              large: true,
              onTap: () => cubit.choose(EnglishLevelChoice.some),
            ),
          ],
          details: Swap(
            child: KeyedSubtree(
              key: ValueKey((state.choice, state.status, state.online)),
              child: _details(state, levelName, cubit.load),
            ),
          ),
        );
      },
    );
  }

  static Widget _details(
    LevelState state,
    String levelName,
    VoidCallback onRetry,
  ) {
    if (state.choice == null) return const SizedBox(width: double.infinity);
    if (state.status == LoadStatus.loading) {
      return const Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: AppSpacing.lg),
        child: AppStateView.loading(),
      );
    }
    if (state.choice == EnglishLevelChoice.beginner) {
      return BeginnerStartCard(levelName: levelName);
    }
    if (state.testUnavailable) {
      return OnboardingNotice(
        icon: AppIcon.questionCircle,
        text: 'onboarding_level_test_unavailable'.tr(),
      );
    }
    final summary = state.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!state.online) ...[
          OnboardingNotice(
            icon: AppIcon.wifiOff,
            text: 'onboarding_level_offline'.tr(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (summary != null)
          PlacementFacts(summary: summary)
        else
          AppStateView.error(
            message: state.failure!.localizedMessage,
            onRetry: onRetry,
          ),
      ],
    );
  }
}
