import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/settle.dart';
import 'package:englizia/core/design_system/widgets/app_logo_mark.dart';
import 'package:flutter/material.dart';

/// The daily reminder as it will arrive: app, time, and the panel's text.
/// Settles when the time changes; greys out while notifications are off.
class ReminderPreview extends StatelessWidget {
  const ReminderPreview({
    required this.time,
    required this.title,
    required this.body,
    this.muted = false,
    super.key,
  });

  final String time;
  final String title;
  final String body;
  final bool muted;

  static const _markSize = 18.0;
  static const _chevronSize = 16.0;
  static const _mutedOpacity = .5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final secondary = texts.caption.copyWith(color: colors.textSecondary);
    final duration = AppMotion.resolve(context, AppMotion.medium);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: [
          if (Theme.of(context).brightness == Brightness.light)
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: .07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md + AppSpacing.xxs,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppLogoMark(size: _markSize),
                const SizedBox(width: AppSpacing.sm - AppSpacing.xxs),
                Expanded(
                  child: Text(
                    '${'app_name'.tr()} • $time',
                    style: secondary,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppIconView(
                  AppIcon.chevronDown,
                  size: _chevronSize,
                  color: colors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm - AppSpacing.xxs),
            Text(title, style: texts.captionStrong),
            Text(body, style: secondary),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      label: 'onboarding_reminder_preview'.tr(),
      child: Settle(
        trigger: time,
        child: AnimatedOpacity(
          opacity: muted ? _mutedOpacity : 1,
          duration: duration,
          curve: AppMotion.smoothOut,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: muted ? 0 : 1),
            duration: duration,
            curve: AppMotion.smoothOut,
            // Filtered only while greying: no extra layer at full color.
            builder: (context, saturation, child) => saturation >= 1
                ? child!
                : ColorFiltered(
                    colorFilter: ColorFilter.matrix(_saturation(saturation)),
                    child: child,
                  ),
            child: card,
          ),
        ),
      ),
    );
  }

  /// A color matrix from grey (0) to full color (1).
  static List<double> _saturation(double s) {
    const r = .2126, g = .7152, b = .0722;
    final i = 1 - s;
    return [
      r * i + s, g * i, b * i, 0, 0, //
      r * i, g * i + s, b * i, 0, 0, //
      r * i, g * i, b * i + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}
