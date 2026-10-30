import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/brand_mark.dart';
import 'package:englizia/core/design_system/widgets/account_button.dart';
import 'package:englizia/features/account/domain/entities/social_provider.dart';
import 'package:flutter/material.dart';

/// Apple (iOS only) and Google as equal ways in, the last one used badged,
/// then "or" before the email form.
class SocialSignIn extends StatelessWidget {
  const SocialSignIn({
    required this.apple,
    required this.lastProvider,
    required this.onProvider,
    super.key,
  });

  /// Whether to offer Apple: on iOS only (requirements §27).
  final bool apple;
  final SocialProvider? lastProvider;

  /// Null while signing in another way.
  final ValueChanged<SocialProvider>? onProvider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget button(SocialProvider provider) => AccountButton(
      label: switch (provider) {
        SocialProvider.google => 'sign_in_google'.tr(),
        SocialProvider.apple => 'sign_in_apple'.tr(),
      },
      mark: switch (provider) {
        SocialProvider.google => const BrandMarkView(BrandMark.google),
        SocialProvider.apple => const BrandMarkView(BrandMark.apple),
      },
      badge: provider == lastProvider ? 'sign_in_last_used'.tr() : null,
      onPressed: switch (onProvider) {
        final onProvider? => () => onProvider(provider),
        null => null,
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Apple first, as on "save progress".
        if (apple) ...[
          button(SocialProvider.apple),
          const SizedBox(height: AppSpacing.md),
        ],
        button(SocialProvider.google),
        const SizedBox(height: AppSpacing.lg),
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(child: Divider(color: colors.border)),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Text(
                  'sign_in_or'.tr(),
                  style: context.texts.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Expanded(child: Divider(color: colors.border)),
            ],
          ),
        ),
      ],
    );
  }
}
