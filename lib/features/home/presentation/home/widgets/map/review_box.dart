import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:flutter/material.dart';

/// «راجع اليوم» floating in the sea (bubble §5): what is due and about how
/// long, the whole box one button. Its height follows its content (≈ 68,
/// D9); its float is the motion's.
class ReviewBox extends StatelessWidget {
  const ReviewBox({required this.review, required this.onPressed, super.key});

  final HomeReview review;

  /// ASSUMPTION(design): opens the word review (D20, bubble A5).
  final VoidCallback onPressed;

  static const width = 198.0;
  static const _padStart = 10.0;
  static const _padEnd = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final scheme = context.scheme;
    final line = reviewLine(review);
    return Semantics(
      button: true,
      label: 'home_review_semantics'.tr(args: [line]),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: PressScale(
            scale: AppMotion.scaleSmall,
            child: Container(
              width: width,
              padding: const EdgeInsetsDirectional.fromSTEB(
                _padStart,
                9,
                _padEnd,
                10,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.info.surface,
                        ),
                        alignment: Alignment.center,
                        child: AppIconView(
                          AppIcon.reviewCycle,
                          color: colors.info.fill,
                          size: AppSizes.iconSm,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        // ASSUMPTION(design): two lines where the words run
                        // longer (English); the board has Arabic only.
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final title = 'home_review_title'.tr();
                            return Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: texts.sizedFor(
                                context,
                                texts.bodyStrong,
                                text: title,
                                width: constraints.maxWidth,
                                size: 14,
                                line: 20,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outline, width: 1.5),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'home_review_action'.tr(),
                          style: texts
                              .sized(
                                texts.button,
                                size: 12,
                                line: 12,
                                running: false,
                              )
                              .copyWith(color: colors.primary.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    line,
                    style: texts
                        .sizedFor(
                          context,
                          texts.caption,
                          text: line,
                          width: width - _padStart - _padEnd,
                          size: 12,
                          line: 16,
                        )
                        .copyWith(color: colors.textSecondary),
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
