import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// Which of an [ActionSheet]'s two actions was chosen.
enum SheetAction { primary, secondary }

/// What the sheet is about: [info] for a choice to understand ("your
/// progress stays on this phone"), [warning] for one that loses something.
enum SheetTone { info, warning }

/// How every bottom sheet comes up and goes down.
AnimationStyle sheetAnimation(BuildContext context) =>
    AppMotion.reduceMotion(context)
    ? AnimationStyle.noAnimation
    : const AnimationStyle(
        duration: AppMotion.sheetIn,
        reverseDuration: AppMotion.sheetOut,
        curve: AppMotion.smoothOut,
      );

/// Asks before a step with consequences: an icon, a title, what it means,
/// the recommended [primaryLabel] action and the [secondaryLabel] one. Null
/// when dismissed. A [destructiveSecondary] action is drawn in the error
/// color.
Future<SheetAction?> showActionSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String primaryLabel,
  required String secondaryLabel,
  AppIcon? icon,
  SheetTone tone = SheetTone.info,
  bool destructiveSecondary = false,
  bool outlinedSecondary = false,
}) => showModalBottomSheet<SheetAction>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: sheetAnimation(context),
  builder: (_) => ActionSheet(
    icon: icon,
    title: title,
    body: body,
    primaryLabel: primaryLabel,
    secondaryLabel: secondaryLabel,
    tone: tone,
    destructiveSecondary: destructiveSecondary,
    outlinedSecondary: outlinedSecondary,
  ),
);

class ActionSheet extends StatelessWidget {
  const ActionSheet({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.icon,
    this.tone = SheetTone.info,
    this.destructiveSecondary = false,
    this.outlinedSecondary = false,
    super.key,
  });

  /// In a badge over the title; none is a sheet of text alone.
  final AppIcon? icon;
  final String title;
  final String body;
  final String primaryLabel;
  final String secondaryLabel;
  final SheetTone tone;
  final bool destructiveSecondary;

  /// As big as the primary button, for when both ways are real choices.
  final bool outlinedSecondary;

  static const _badgeSize = 48.0;
  static const _iconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icon = this.icon;
    final ToneColors badge = switch (tone) {
      SheetTone.info => colors.info,
      SheetTone.warning => colors.error,
    };
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
          if (icon != null) ...[
            Center(
              child: Container(
                width: _badgeSize,
                height: _badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badge.surface,
                  shape: BoxShape.circle,
                ),
                child: AppIconView(icon, size: _iconSize, color: badge.text),
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          ],
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.title,
            ),
          ),
          const SizedBox(height: AppSpacing.sm - AppSpacing.xxs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.texts.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: primaryLabel,
            size: AppButtonSize.large,
            onPressed: () => Navigator.of(context).pop(SheetAction.primary),
          ),
          SizedBox(height: outlinedSecondary ? AppSpacing.md : AppSpacing.xs),
          AppButton(
            label: secondaryLabel,
            size: outlinedSecondary
                ? AppButtonSize.large
                : AppButtonSize.regular,
            variant: destructiveSecondary
                ? AppButtonVariant.destructive
                : outlinedSecondary
                ? AppButtonVariant.secondary
                : AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(SheetAction.secondary),
          ),
        ],
      ),
    );
  }
}
