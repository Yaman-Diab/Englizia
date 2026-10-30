import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/onboarding/presentation/preparing/cubit/preparing_cubit.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';

/// One step of "preparing": a mark (waiting, turning, done, failed), what
/// the step does or did, and under it what it found (the first unit, the
/// test's length) or why it failed. Read out when it changes.
class PreparingStepRow extends StatelessWidget {
  const PreparingStepRow({required this.step, required this.state, super.key});

  final PreparingStep step;

  /// For the names and numbers the step's text needs.
  final PreparingState state;

  static const markSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final language = context.locale.languageCode;
    final status = step.status;
    final text = _text(language);
    final details = _details(context, language);
    final color = switch (status) {
      PreparingStepStatus.failed => colors.error.text,
      PreparingStepStatus.pending => colors.textSecondary,
      _ => colors.textPrimary,
    };
    final duration = AppMotion.resolve(context, AppMotion.fast);

    return Semantics(
      liveRegion: status != PreparingStepStatus.pending,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: AppMotion.smoothOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(
                    begin: AppMotion.scaleMark,
                    end: 1.0,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: SizedBox.square(
                key: ValueKey(status),
                dimension: markSize,
                child: _Mark(status: status),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: duration,
                  style: texts.body.copyWith(color: color),
                  child: Text(text),
                ),
                if (details != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  DefaultTextStyle.merge(
                    style: texts.caption.copyWith(color: colors.textSecondary),
                    child: details,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _text(String language) {
    final done = step.status == PreparingStepStatus.done;
    final failed = step.status == PreparingStepStatus.failed;
    final level = state.level?.name.of(language);
    if (failed && state.failure is StorageFailure) {
      return 'preparing_save_failed'.tr();
    }
    return switch (step.kind) {
      PreparingStepKind.level when failed => 'preparing_level_failed'.tr(),
      PreparingStepKind.level when done && level != null =>
        'preparing_level_done'.tr(namedArgs: {'level': _isolated(level)}),
      PreparingStepKind.level when done => 'preparing_level_chosen'.tr(),
      PreparingStepKind.level => 'preparing_level_running'.tr(),
      PreparingStepKind.grade when failed => 'preparing_level_failed'.tr(),
      PreparingStepKind.grade when done && level != null =>
        'preparing_grade_done'.tr(namedArgs: {'grade': level}),
      PreparingStepKind.grade => 'preparing_grade_running'.tr(),
      PreparingStepKind.plan when failed => 'preparing_level_failed'.tr(),
      PreparingStepKind.plan when done => 'preparing_plan_done'.tr(),
      PreparingStepKind.plan => 'preparing_plan_running'.tr(),
      PreparingStepKind.unit when failed => 'preparing_unit_failed'.tr(),
      PreparingStepKind.unit when done => 'preparing_unit_done'.tr(),
      PreparingStepKind.unit => 'preparing_unit_running'.tr(),
      PreparingStepKind.test when failed => 'preparing_test_failed'.tr(),
      PreparingStepKind.test when done => 'preparing_test_done'.tr(),
      PreparingStepKind.test => 'preparing_test_running'.tr(),
      PreparingStepKind.goal when failed => 'preparing_goal_failed'.tr(),
      PreparingStepKind.goal when done && state.goalMinutes != null =>
        'preparing_goal_done'.plural(state.goalMinutes!),
      PreparingStepKind.goal => 'preparing_goal_running'.tr(),
    };
  }

  Widget? _details(BuildContext context, String language) {
    if (step.status == PreparingStepStatus.failed) {
      return switch (state.failure) {
        final failure? => Text(failure.localizedMessage),
        null => null,
      };
    }
    if (step.status != PreparingStepStatus.done) return null;
    switch (step.kind) {
      case PreparingStepKind.unit:
        final unit = state.unit;
        if (unit == null) return null;
        final topic = unit.topic?.of(language);
        final line = [
          if (unit.title.isNotEmpty) _isolated(unit.title),
          if (topic != null && topic.isNotEmpty) topic,
        ].join(' ');
        return line.isEmpty ? null : Text(line);
      case PreparingStepKind.test:
        final test = state.test;
        if (test == null) return null;
        return Text(
          'onboarding_level_minutes'.plural(
            test.maxMinutes,
            namedArgs: {
              'range': _isolated('${test.minMinutes}–${test.maxMinutes}'),
            },
          ),
        );
      default:
        return null;
    }
  }

  /// The course's titles, Latin names and numbers never flip inside Arabic
  /// text.
  static String _isolated(String text) => '${Unicode.LRI}$text${Unicode.PDI}';
}

class _Mark extends StatelessWidget {
  const _Mark({required this.status});

  final PreparingStepStatus status;

  static const _iconSize = 16.0;
  static const _ringWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget filled(Color color, AppIcon icon) => DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: AppIconView(icon, size: _iconSize, color: colors.background),
      ),
    );
    return switch (status) {
      PreparingStepStatus.done => filled(colors.success.fill, AppIcon.check),
      PreparingStepStatus.failed => filled(colors.error.fill, AppIcon.cross),
      PreparingStepStatus.running => AppSpinner(
        size: PreparingStepRow.markSize,
        color: colors.primary.fill,
      ),
      PreparingStepStatus.pending => Padding(
        padding: const EdgeInsetsDirectional.all(_ringWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.scheme.outline,
              width: _ringWidth,
            ),
          ),
        ),
      ),
    };
  }
}
