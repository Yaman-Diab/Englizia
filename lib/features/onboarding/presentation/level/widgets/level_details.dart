import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';

/// "You'll start from Pre-A1": where a learner who skips the test begins.
class BeginnerStartCard extends StatelessWidget {
  const BeginnerStartCard({required this.levelName, super.key});

  final String levelName;

  static const _badgeSize = 36.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.success.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppIconView(
                AppIcon.seedling,
                size: _iconSize,
                color: colors.success.text,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'onboarding_level_start_from'.tr(
                      namedArgs: {'level': levelName},
                    ),
                    style: context.texts.bodyStrong,
                  ),
                  Text(
                    'onboarding_level_start_from_desc'.tr(),
                    style: context.texts.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the placement test takes, side by side: duration, stages, and the
/// "I don't know" answer. Duration and stages come from the server.
class PlacementFacts extends StatelessWidget {
  const PlacementFacts({required this.summary, super.key});

  final PlacementSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Isolated left-to-right so "12–15" never flips inside Arabic text.
    final range =
        '${Unicode.LRI}${summary.minMinutes}–${summary.maxMinutes}${Unicode.PDI}';
    final stages = summary.mayAddStage
        ? 'onboarding_level_stages_optional'.plural(summary.stages)
        : 'onboarding_level_stages'.plural(summary.stages);
    final facts = [
      (
        AppIcon.clock,
        'onboarding_level_minutes'.plural(
          summary.maxMinutes,
          namedArgs: {'range': range},
        ),
      ),
      (AppIcon.steps, stages),
      (AppIcon.questionCircle, 'onboarding_level_dont_know'.tr()),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (icon, label)) in facts.indexed) ...[
                if (i > 0) VerticalDivider(width: 1, color: colors.border),
                Expanded(
                  child: _Fact(icon: icon, label: label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final AppIcon icon;
  final String label;

  static const _iconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm - AppSpacing.xxs,
      ),
      child: Column(
        children: [
          AppIconView(icon, size: _iconSize, color: colors.primary.fill),
          const SizedBox(height: AppSpacing.sm - AppSpacing.xxs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.texts.caption.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// An informational line in a soft band, e.g. "the test needs a
/// connection". Announced to screen readers when it appears.
class LevelNotice extends StatelessWidget {
  const LevelNotice({required this.icon, required this.text, super.key});

  final AppIcon icon;
  final String text;

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final info = context.colors.info;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: info.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xxs,
          ),
          child: Row(
            children: [
              AppIconView(icon, size: _iconSize, color: info.text),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: context.texts.captionStrong.copyWith(color: info.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
