import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/icons/brand_mark.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/account_button.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/cubit/save_progress_cubit.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/widgets/guest_sheet.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/widgets/legal_line.dart';
import 'package:englizia/features/onboarding/presentation/save_progress/widgets/plan_card.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_notice.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How the learner chose to create the account.
enum AccountProvider { apple, google, email }

/// Onboarding's last step, "save your progress" (requirements v3.0 §4.2–
/// 4.3, design "Save Progress"): the plan built from the answers, then an
/// account with Google, Apple (iOS) or email, or «لاحقًا» to carry on as a
/// guest of this phone (ADR 10) after a sheet says what that means. Every
/// way needs a connection.
class SaveProgressPage extends StatelessWidget {
  const SaveProgressPage({
    required this.path,
    required this.onCreateAccount,
    required this.onTerms,
    required this.onPrivacy,
    required this.onGuestCreated,
    required this.onBack,
    super.key,
  });

  /// The branch and every answer, for the plan and the account.
  final OnboardingPath path;
  final ValueChanged<AccountProvider> onCreateAccount;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  final VoidCallback onBack;

  /// The guest account exists; its session is not started yet.
  final ValueChanged<AuthTokens> onGuestCreated;

  Future<void> _later(BuildContext context) async {
    final cubit = context.read<SaveProgressCubit>();
    final languageCode = context.locale.languageCode;
    final asGuest = await showGuestSheet(context);
    if (asGuest != true) return;
    await cubit.continueAsGuest(
      answers: path,
      languageCode: languageCode,
      utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = onboardingPosition(
      OnboardingStep.saveProgress,
      path: path,
    );
    final parent = path.audience == TrackAudience.child;
    final childName = path.childName;
    return BlocConsumer<SaveProgressCubit, SaveProgressState>(
      listenWhen: (before, now) =>
          now.failure != null && before.failure != now.failure ||
          now.guestSession != null && before.guestSession == null,
      listener: (context, state) => state.guestSession != null
          ? onGuestCreated(state.guestSession!)
          : showFailureSnackBar(
              context,
              state.failure!,
              onRetry: () => context.read<SaveProgressCubit>().continueAsGuest(
                answers: path,
                languageCode: context.locale.languageCode,
                utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
              ),
            ),
      builder: (context, state) {
        final enabled = state.online && !state.busy;
        VoidCallback? create(AccountProvider provider) =>
            enabled ? () => onCreateAccount(provider) : null;
        return OnboardingQuestionScaffold(
          question: parent && childName != null
              ? 'onboarding_save_question_parent'.tr(
                  namedArgs: {'name': childName},
                )
              : 'onboarding_save_question'.tr(),
          expression: MascotExpression.happy,
          step: position.current,
          totalSteps: position.total,
          complete: true,
          onBack: onBack,
          options: [PlanCard(path: path)],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (parent) ...[
                _ParentNote(),
                const SizedBox(height: AppSpacing.md),
              ],
              if (!state.online) ...[
                OnboardingNotice(
                  icon: AppIcon.wifiOff,
                  text: 'onboarding_save_offline'.tr(),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                AccountButton(
                  label: 'onboarding_save_apple'.tr(),
                  mark: const BrandMarkView(BrandMark.apple),
                  onPressed: create(AccountProvider.apple),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AccountButton(
                label: 'onboarding_save_google'.tr(),
                mark: const BrandMarkView(BrandMark.google),
                onPressed: create(AccountProvider.google),
              ),
              const SizedBox(height: AppSpacing.md),
              AccountButton(
                label: 'onboarding_save_email'.tr(),
                mark: AppIconView(
                  AppIcon.mail,
                  color: context.colors.textSecondary,
                ),
                onPressed: create(AccountProvider.email),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'onboarding_save_later'.tr(),
                variant: AppButtonVariant.text,
                isLoading: state.creatingGuest,
                onPressed: enabled ? () => _later(context) : null,
              ),
              LegalLine(onTerms: onTerms, onPrivacy: onPrivacy),
            ],
          ),
        );
      },
    );
  }
}

/// A parent creates the account in their own name.
class _ParentNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = context.colors.info.text;
    return Row(
      children: [
        AppIconView(AppIcon.person, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'onboarding_save_parent_note'.tr(),
            style: context.texts.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
