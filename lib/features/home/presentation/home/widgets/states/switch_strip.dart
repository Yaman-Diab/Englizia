import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// «انتقلت إلى …» after a track switch (header §10, M11): an inverse strip
/// under the top bar. The page shows it for `AppMotion.toastHold` and then
/// passes null.
///
/// It places itself in the stage, whose top is the top bar's (main
/// coordinates): put it in the stage's `Stack` unpositioned, or filling it.
class SwitchStrip extends StatelessWidget {
  const SwitchStrip({required this.title, super.key});

  /// Null hides it.
  final String? title;

  /// Root top 92 in the design = main 64: 8 under the 56 top bar.
  static const top = 64.0;
  static const side = AppSpacing.lg;
  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: top,
          start: side,
          end: side,
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.resolve(context, AppMotion.quick),
          child: title == null
              ? const SizedBox(width: double.infinity)
              : _Strip(key: ValueKey(title), title: title),
        ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.title, super.key});

  final String title;

  static const _radius = 14.0;
  static const _icon = 14.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Inverse: the text colour as the fill, the background as the text.
    final ink = colors.background;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: SwitchStrip.height),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Row(
          children: [
            AppIconView(AppIcon.check, size: _icon, color: ink),
            const SizedBox(width: _gap),
            Expanded(
              child: Text(
                'me_switched'.tr(args: [title]),
                style: context.texts.body.copyWith(fontSize: 14, color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
