import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// "By continuing you agree to the Terms and the Privacy Policy", with both
/// as links (S §4.3: the two pages exist from v0.1 because this screen
/// links to them).
class LegalLine extends StatelessWidget {
  const LegalLine({required this.onTerms, required this.onPrivacy, super.key});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final plain = context.texts.caption.copyWith(color: colors.textSecondary);
    Widget link(String label, VoidCallback onTap) => TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xxs,
        ),
        minimumSize: const Size(0, AppSizes.minTapTarget),
        foregroundColor: colors.selection,
        textStyle: context.texts.captionStrong,
      ),
      child: Text(label),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('onboarding_save_terms_prefix'.tr(), style: plain),
        link('onboarding_save_terms'.tr(), onTerms),
        Text('onboarding_save_and'.tr(), style: plain),
        link('onboarding_save_privacy'.tr(), onPrivacy),
      ],
    );
  }
}
