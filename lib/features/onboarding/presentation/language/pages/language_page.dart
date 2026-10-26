import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_option.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:flutter/material.dart';

/// Onboarding step 1 (requirements v3.0 §4.2): the interface language.
/// The current language is preselected, and picking one switches the whole
/// app at once (English flips it to LTR), so the choice is its own preview.
/// The language is saved by the localization layer, not here.
class LanguagePage extends StatelessWidget {
  const LanguagePage({
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;
    final position = onboardingPosition(OnboardingStep.language);

    return OnboardingQuestionScaffold(
      question: 'onboarding_language_question'.tr(),
      step: position.current,
      totalSteps: position.total,
      helper: 'onboarding_language_helper'.tr(),
      continueLabel: 'common_continue'.tr(),
      onContinue: onContinue,
      onBack: onBack,
      options: [
        OnboardingOption(
          mark: 'onboarding_language_ar_mark'.tr(),
          title: 'settings_language_ar'.tr(),
          description: 'onboarding_language_ar_desc'.tr(),
          selected: locale == AppLocales.arabic,
          onTap: () => context.setLocale(AppLocales.arabic),
        ),
        OnboardingOption(
          mark: 'onboarding_language_en_mark'.tr(),
          title: 'settings_language_en'.tr(),
          description: 'onboarding_language_en_desc'.tr(),
          selected: locale == AppLocales.english,
          onTap: () => context.setLocale(AppLocales.english),
        ),
      ],
    );
  }
}
