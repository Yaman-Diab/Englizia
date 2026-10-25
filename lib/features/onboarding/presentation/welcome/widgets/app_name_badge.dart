import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// The pill at the top of the welcome screen: logo mark and app name.
// ASSUMPTION(design): the mark is a letter in a circle until the final logo
// is approved (requirements v3.0 §26); the designs use a placeholder "A".
class AppNameBadge extends StatelessWidget {
  const AppNameBadge({super.key});

  static const _markSize = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final hairline = colors.textPrimary.withValues(alpha: .06);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: hairline),
        boxShadow: [
          if (isLight)
            BoxShadow(
              color: hairline,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xs + AppSpacing.xxs,
          AppSpacing.xs + AppSpacing.xxs,
          AppSpacing.md + AppSpacing.xxs,
          AppSpacing.xs + AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: _markSize,
                height: _markSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryStrong,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  'app_logo_mark'.tr(),
                  style: texts.bodyStrong.copyWith(
                    color: colors.onPrimaryStrong,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            Text('app_name'.tr(), style: texts.bodyStrong),
          ],
        ),
      ),
    );
  }
}
