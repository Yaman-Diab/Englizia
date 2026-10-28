import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// "Hello!" to tap and hear, in the kids' letters. While it is said it
/// lights up in the reader's karaoke color, as words do in lessons.
class HelloWord extends StatelessWidget {
  const HelloWord({required this.highlighted, required this.onTap, super.key});

  final bool highlighted;
  final VoidCallback onTap;

  static const _height = 96.0;
  static const _iconSize = 28.0;
  static const _wordRadius = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'kid_welcome_hello_word'.tr(),
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconView(
                    AppIcon.volume,
                    size: _iconSize,
                    color: colors.info.fill,
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.quick),
                    curve: AppMotion.out,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.md + AppSpacing.xxs,
                      AppSpacing.xxs,
                      AppSpacing.md + AppSpacing.xxs,
                      AppSpacing.sm - AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: highlighted
                          ? colors.reader.karaokeBackground
                          : colors.reader.karaokeBackground.withValues(
                              alpha: 0,
                            ),
                      borderRadius: BorderRadius.circular(_wordRadius),
                    ),
                    child: Text(
                      'kid_welcome_word'.tr(),
                      textDirection: TextDirection.ltr,
                      style: context.texts.kidsWord.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
