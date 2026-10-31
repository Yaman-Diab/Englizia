import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/motion/rolling_number.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:englizia/core/design_system/widgets/goal_ring.dart';
import 'package:englizia/core/design_system/widgets/streak_flame.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:flutter/material.dart';

/// The one card of the screen: today's minutes and the days in a row. Reaching
/// the goal is the strongest moment here: the ring closes on a check, the flame
/// swells and the day turns over.
class TodayCard extends StatelessWidget {
  const TodayCard({
    required this.goal,
    required this.streak,
    required this.lead,
    super.key,
  });

  final DailyGoal goal;
  final StreakDays streak;

  /// How long until the server's numbers may start.
  final Duration lead;

  static const _ringCheck = 20.0;
  static const _flame = 32.0;
  static const _metFlame = 16.0;
  static const _dividerHeight = 48.0;
  static const _checkFrom = .4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final met = goal.met;
    final just = goal.justMet;
    final ringColor = met ? colors.success.fill : colors.primary.fill;
    final target = goal.target <= 0 ? 1 : goal.target;
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    TimedValue(
                      delay: lead + LessonCompleteEntrance.ringAfterData,
                      duration: AppMotion.verySlow,
                      builder: (_, value) => GoalRing(
                        share:
                            (goal.before + (goal.now - goal.before) * value) /
                            target,
                        color: ringColor,
                        child: met
                            ? TimedValue(
                                delay: just
                                    ? lead +
                                          LessonCompleteEntrance.goalAfterData
                                    : Duration.zero,
                                duration: AppMotion.closeUp,
                                curve: AppMotion.bounce,
                                builder: (_, shown) => Opacity(
                                  opacity: shown.clamp(0, 1),
                                  child: Transform.scale(
                                    scale:
                                        _checkFrom + (1 - _checkFrom) * shown,
                                    child: AppIconView(
                                      AppIcon.check,
                                      size: _ringCheck,
                                      color: colors.success.fill,
                                    ),
                                  ),
                                ),
                              )
                            : Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '${goal.now}/${goal.target}',
                                  style: texts.captionStrong.copyWith(
                                    color: colors.textPrimary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                  textScaler: TextScaler.noScaling,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'lesson_done_today'.tr(),
                            style: texts.captionStrong.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            met
                                ? 'lesson_done_goal_done'.tr()
                                : 'lesson_done_goal_target'.tr(
                                    namedArgs: {'target': '${goal.target}'},
                                  ),
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: _dividerHeight,
                margin: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                color: colors.border,
              ),
              Expanded(
                child: Row(
                  children: [
                    StreakFlame(
                      size: _flame,
                      celebrateAfter: just
                          ? lead + LessonCompleteEntrance.flameAfterData
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RollingNumber(
                                from: streak.before,
                                to: streak.now,
                                delay:
                                    lead + LessonCompleteEntrance.rollAfterData,
                                style: texts.bodyStrong.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  'lesson_done_days'.plural(streak.now),
                                  style: texts.bodyStrong.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'lesson_done_in_a_row'.tr(),
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (just)
            Entrance(
              motion: EntranceMotion.up,
              delay: lead + LessonCompleteEntrance.metAfterData,
              duration: AppMotion.fast,
              distance: AppMotion.distanceMicro,
              child: Container(
                margin: const EdgeInsetsDirectional.only(top: AppSpacing.md),
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const StreakFlame(size: _metFlame, inner: false),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'lesson_done_goal_reached'.tr(),
                      style: texts.captionStrong.copyWith(
                        color: colors.streak.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
