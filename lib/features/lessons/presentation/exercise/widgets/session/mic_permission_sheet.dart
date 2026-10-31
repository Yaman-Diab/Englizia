import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// Why the microphone, before the system asks (S §7.5). True on «متابعة»; the
/// scrim closes it without asking.
Future<bool> showMicPermissionSheet(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: sheetAnimation(context),
      builder: (_) => const _MicPermissionSheet(),
    ) ??
    false;

class _MicPermissionSheet extends StatelessWidget {
  const _MicPermissionSheet();

  static const _circle = 72.0;
  static const _iconSize = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
              width: _circle,
              height: _circle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                size: _iconSize,
                color: colors.primary.fill,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
          Semantics(
            header: true,
            child: Text(
              'lesson_mic_why_title'.tr(),
              textAlign: TextAlign.center,
              style: context.texts.title,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: AppSizes.iconSm,
                color: colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'lesson_mic_why_privacy'.tr(),
                  style: context.texts.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'lesson_mic_why_continue'.tr(),
            size: AppButtonSize.large,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
