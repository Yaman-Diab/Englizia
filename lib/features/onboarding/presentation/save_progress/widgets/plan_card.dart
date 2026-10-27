import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';

/// "Your plan": the answers that shape the learner's start, line by line
/// (design "Save Progress"). A parent sees the child and their track.
class PlanCard extends StatelessWidget {
  const PlanCard({required this.path, super.key});

  final OnboardingPath path;

  static const _tileSize = 32.0;
  static const _tileRadius = 10.0;
  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = _rows(context);
    return Semantics(
      container: true,
      label: 'onboarding_save_plan'.tr(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'onboarding_save_plan'.tr(),
                style: context.texts.captionStrong.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              for (final (i, (icon, color, text)) in rows.indexed) ...[
                const SizedBox(height: AppSpacing.md),
                Entrance(
                  motion: EntranceMotion.up,
                  delay: QuestionEntrance.answer(i + 1),
                  child: Row(
                    children: [
                      Container(
                        width: _tileSize,
                        height: _tileSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(_tileRadius),
                        ),
                        child: AppIconView(icon, size: _iconSize, color: color),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(text, style: context.texts.body)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<(AppIcon, Color, String)> _rows(BuildContext context) {
    final colors = context.colors;
    final primary = colors.primary.fill;
    final languageCode = context.locale.languageCode;
    if (path.audience == TrackAudience.child) {
      return [
        if (path.childName case final name?)
          (
            AppIcon.child,
            primary,
            switch (path.childAge) {
              final age? => 'onboarding_save_child'.plural(
                age,
                namedArgs: {'name': name},
              ),
              null => name,
            },
          ),
        if (path.trackTitle case final title?)
          (AppIcon.route, primary, title.of(languageCode)),
      ];
    }
    return [
      if (path.dailyGoalMinutes case final minutes?)
        (AppIcon.target, primary, 'onboarding_save_goal'.plural(minutes)),
      if (path.challengeDays case final days?)
        (
          AppIcon.flame,
          colors.streak.text,
          'onboarding_save_challenge'.plural(days),
        ),
      if (path.grade case final grade?)
        (AppIcon.route, primary, grade.name.of(languageCode))
      else if (path.placementTest)
        (AppIcon.steps, primary, 'onboarding_save_test'.tr())
      else if (path.startLevel case final level?)
        (
          AppIcon.seedling,
          colors.success.text,
          'onboarding_save_start'.tr(
            namedArgs: {'level': level.name.of(languageCode)},
          ),
        ),
    ];
  }
}
