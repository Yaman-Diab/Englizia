import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/settle.dart';
import 'package:flutter/material.dart';

/// What the chosen goal amounts to: about how many lessons a day, and the
/// minutes in a week. Settles when the goal changes.
class GoalPreview extends StatelessWidget {
  const GoalPreview({
    required this.minutes,
    required this.lessonMinutes,
    super.key,
  });

  final int minutes;

  /// The average lesson length from the settings; without it only the
  /// weekly total is shown.
  final int? lessonMinutes;

  static const _daysPerWeek = 7;

  /// "≈ one and a half lessons a day", to the nearest half lesson (never
  /// less than half); null when the lesson length is unknown.
  static String? lessonsLine(int minutes, int? lessonMinutes) {
    if (lessonMinutes == null) return null;
    final halves = (minutes * 2 / lessonMinutes).round().clamp(1, 1 << 20);
    final whole = halves ~/ 2;
    if (whole == 0) return 'onboarding_goal_lessons_half'.tr();
    return halves.isOdd
        ? 'onboarding_goal_lessons_and_half'.plural(whole)
        : 'onboarding_goal_lessons'.plural(whole);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lessons = lessonsLine(minutes, lessonMinutes);
    return Settle(
      trigger: minutes,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lessons != null)
                  Text(lessons, style: context.texts.captionStrong),
                Text(
                  'onboarding_goal_weekly'.plural(minutes * _daysPerWeek),
                  style: context.texts.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
