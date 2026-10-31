import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/motion/hop_once.dart';
import 'package:englizia/core/design_system/widgets/success_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The guide on its circle, which hops once as the check draws itself.
class CompleteHero extends StatelessWidget {
  const CompleteHero({super.key});

  static const _size = 200.0;
  static const _guide = 140.0;
  static const _guideTop = 26.0;
  static const _guideSide = 30.0;
  static const _badge = 48.0;
  static const _check = 26.0;
  static const _badgeInset = 10.0;
  static const _hop = 16.0;
  static const _growFrom = .8;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final circle = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.surface,
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: _size),
    );
    return Center(
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: _size,
          child: Stack(
            children: [
              if (AppMotion.reduceMotion(context))
                circle
              else
                circle
                    .animate()
                    .fadeIn(
                      duration: AppMotion.sheetIn,
                      curve: AppMotion.smoothOut,
                    )
                    .scaleXY(
                      begin: _growFrom,
                      end: 1,
                      curve: AppMotion.smoothOut,
                    ),
              const PositionedDirectional(
                top: _guideTop,
                start: _guideSide,
                child: HopOnce(
                  delay: LessonCompleteEntrance.guide,
                  height: _hop,
                  child: Mascot(
                    expression: MascotExpression.happy,
                    size: _guide,
                    animate: false,
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: _badgeInset,
                end: _badgeInset,
                child: SuccessBadge(
                  size: _badge,
                  checkSize: _check,
                  ringColor: colors.background,
                  growDelay: LessonCompleteEntrance.badge,
                  checkDelay: LessonCompleteEntrance.check,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «أكملت الدرس», the lesson's name, and «بلا أخطاء» when it was.
class CompleteTitle extends StatelessWidget {
  const CompleteTitle({
    required this.title,
    required this.lesson,
    required this.perfect,
    super.key,
  });

  final String title;
  final String? lesson;
  final bool perfect;

  static const _pillHeight = 28.0;
  static const _starSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final lesson = this.lesson;
    return Entrance(
      motion: EntranceMotion.up,
      delay: LessonCompleteEntrance.title,
      duration: AppMotion.closeUp,
      distance: 0,
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: texts.display.copyWith(color: colors.textPrimary),
                ),
              ),
              if (perfect)
                Container(
                  height: _pillHeight,
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.sm,
                    end: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.reward.surface,
                    borderRadius: BorderRadius.circular(_pillHeight / 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: _starSize,
                        color: colors.reward.fill,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'lesson_done_perfect'.tr(),
                        style: texts.captionStrong.copyWith(
                          color: colors.reward.text,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (lesson != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              lesson,
              textAlign: TextAlign.center,
              style: texts.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
