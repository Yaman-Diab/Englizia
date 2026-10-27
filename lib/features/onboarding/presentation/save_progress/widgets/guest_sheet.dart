import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// Before carrying on as a guest: the progress stays on this phone only.
/// True when the learner chooses to continue as a guest; false or null
/// when they go back to create an account.
Future<bool?> showGuestSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const GuestSheet(),
    );

class GuestSheet extends StatelessWidget {
  const GuestSheet({super.key});

  static const _badgeSize = 48.0;
  static const _iconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final info = colors.info;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: _badgeSize,
              height: _badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: info.surface,
                shape: BoxShape.circle,
              ),
              child: AppIconView(
                AppIcon.phone,
                size: _iconSize,
                color: info.text,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          Text(
            'onboarding_save_guest_title'.tr(),
            textAlign: TextAlign.center,
            style: context.texts.title,
          ),
          const SizedBox(height: AppSpacing.sm - AppSpacing.xxs),
          Text(
            'onboarding_save_guest_body'.tr(),
            textAlign: TextAlign.center,
            style: context.texts.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'onboarding_save_guest_create'.tr(),
            size: AppButtonSize.large,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'onboarding_save_guest_continue'.tr(),
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
