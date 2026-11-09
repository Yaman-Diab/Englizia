import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/xp_amount.dart';
import 'package:englizia/features/lessons/presentation/complete/cubit/lesson_complete_cubit.dart';
import 'package:flutter/material.dart';

/// One row of numbers with lines between them, not cards: the points, right at
/// the first attempt, and the time.
class CompleteStats extends StatelessWidget {
  const CompleteStats({required this.state, required this.xpDelay, super.key});

  final LessonCompleteState state;

  /// When the points may start counting, once they have arrived.
  final Duration xpDelay;

  static const _waitIcon = 24.0;
  static const _valueHeight = 30.0;

  int get _minutes {
    final minutes = (state.seconds / 60).round();
    return minutes < 1 ? 1 : minutes;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final value = texts.title.copyWith(color: colors.textPrimary);
    final stats = <_Stat>[
      if (state.showsXp)
        state.waitingForServer
            ? _Stat(
                value: AppIconView(
                  AppIcon.clock,
                  size: _waitIcon,
                  color: colors.info.fill,
                ),
                label: 'lesson_done_counted_later'.tr(),
                labelColor: colors.info.text,
              )
            : _Stat(
                value: XpAmount(
                  ticks: true,
                  xp: state.result?.xp ?? 0,
                  style: texts.title,
                  delay: xpDelay,
                ),
                label: 'lesson_done_points'.tr(),
                labelColor: colors.textSecondary,
              ),
      if (state.counted > 0)
        _Stat(
          value: Text(
            'lesson_done_first_value'.tr(
              namedArgs: {
                'right': '${state.rightFirstTime}',
                'total': '${state.counted}',
              },
            ),
            style: value,
          ),
          label: 'lesson_done_first'.tr(),
          labelColor: colors.textSecondary,
        ),
      _Stat(
        value: Text(
          'lesson_done_minutes'.tr(namedArgs: {'minutes': '$_minutes'}),
          style: value,
        ),
        label: 'lesson_done_time'.tr(),
        labelColor: colors.textSecondary,
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, stat) in stats.indexed)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : BorderDirectional(
                          start: BorderSide(color: context.scheme.outline),
                        ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: _valueHeight,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: stat.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        stat.label,
                        textAlign: TextAlign.center,
                        style: texts.caption.copyWith(color: stat.labelColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _Stat {
  const _Stat({
    required this.value,
    required this.label,
    required this.labelColor,
  });

  final Widget value;
  final String label;
  final Color labelColor;
}

/// What the server adds between the numbers and the unit: the words saved, what
/// still waits to be judged, and what to review.
class CompleteExtras extends StatelessWidget {
  const CompleteExtras({required this.state, required this.onWords, super.key});

  final LessonCompleteState state;
  final VoidCallback onWords;

  static const _rowHeight = 52.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final words = state.result?.wordsSaved ?? 0;
    final concepts = state.result?.concepts ?? const <String>[];
    final divider = BorderSide(color: colors.border);
    final review = !state.perfect && concepts.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (words > 0) ...[
          const SizedBox(height: AppSpacing.xl),
          Container(
            constraints: const BoxConstraints(minHeight: _rowHeight),
            decoration: BoxDecoration(
              border: Border(top: divider, bottom: divider),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: _iconSize,
                  color: colors.reward.fill,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'lesson_done_words'.plural(words),
                    style: texts.body.copyWith(color: colors.textPrimary),
                  ),
                ),
                TextButton.icon(
                  onPressed: onWords,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: AppSizes.iconSm,
                  ),
                  label: Text('lesson_done_show_words'.tr()),
                ),
              ],
            ),
          ),
        ],
        if (state.pending > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconView(
                AppIcon.clock,
                size: _iconSize,
                color: colors.info.fill,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'lesson_done_pending'.plural(state.pending),
                  style: texts.caption.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ],
        if (review) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'lesson_done_review'.tr(),
            style: texts.bodyStrong.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final concept in concepts)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.info.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      concept,
                      style: texts.captionStrong.copyWith(
                        color: colors.info.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'lesson_done_review_when'.tr(),
            style: texts.caption.copyWith(color: colors.textSecondary),
          ),
        ],
        // Keeps the width while there is nothing yet, for the place to open.
        const SizedBox(width: double.infinity),
      ],
    );
  }
}
