import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:flutter/material.dart';

/// "This email already has an account" with "sign in instead" (S §4.3): an
/// info card, not an error, because nothing the learner typed is wrong.
/// Announced to screen readers when it appears.
class EmailTakenCard extends StatelessWidget {
  const EmailTakenCard({required this.onSignIn, super.key});

  final VoidCallback onSignIn;

  static const _badgeSize = 36.0;
  static const _iconSize = 18.0;
  static const _arrowSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.primary.surface),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: _badgeSize,
                height: _badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                ),
                child: AppIconView(
                  AppIcon.personCheck,
                  size: _iconSize,
                  color: colors.info.text,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'account_email_taken'.tr(),
                      style: texts.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: onSignIn,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, AppSizes.minTapTarget),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: colors.primary.text,
                        textStyle: texts.bodyStrong,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text('account_email_taken_sign_in'.tr()),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: _arrowSize,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
