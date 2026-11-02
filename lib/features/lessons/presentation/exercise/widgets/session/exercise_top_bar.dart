import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// Leaving, the lesson's progress, and the hint. With no hint the button is
/// gone but keeps its space, so the bar doesn't change width.
class ExerciseTopBar extends StatelessWidget {
  const ExerciseTopBar({
    required this.position,
    required this.total,
    required this.hasHint,
    required this.hintOpen,
    required this.hintUsed,
    required this.onExit,
    required this.onHint,
    super.key,
  });

  final int position;
  final int total;
  final bool hasHint;
  final bool hintOpen;
  final bool hintUsed;
  final VoidCallback onExit;
  final VoidCallback onHint;

  static const _endInset = 20.0;
  static const _hintCircle = 40.0;
  static const _hintIcon = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: _endInset,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            tooltip: 'lesson_exit'.tr(),
            color: colors.textSecondary,
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: LessonProgressBar(position: position, total: total),
          ),
          const SizedBox(width: AppSpacing.sm),
          Visibility(
            visible: hasHint,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: IconButton(
              onPressed: hasHint ? onHint : null,
              tooltip: hintOpen
                  ? 'lesson_hint_hide'.tr()
                  : 'lesson_hint_show'.tr(),
              style: IconButton.styleFrom(
                padding: EdgeInsetsDirectional.zero,
                fixedSize: const Size.square(AppSizes.minTapTarget),
              ),
              icon: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.quick),
                width: _hintCircle,
                height: _hintCircle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hintUsed ? colors.info.surface : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hintUsed ? Colors.transparent : colors.info.fill,
                    width: 1.5,
                  ),
                ),
                child: AppIconView(
                  AppIcon.lightbulb,
                  size: _hintIcon,
                  color: colors.info.fill,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The lesson's progress: it starts as a dot, so it reads as a bar and not an
/// empty line, and stretches with a small overshoot.
class LessonProgressBar extends StatelessWidget {
  const LessonProgressBar({
    required this.position,
    required this.total,
    super.key,
  });

  final int position;
  final int total;

  static const _height = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final share = total == 0 ? 0.0 : position / total;
    return Semantics(
      label: 'lesson_progress'.tr(),
      value: '$position / $total',
      child: ExcludeSemantics(
        child: Container(
          height: _height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.slow),
                curve: AppMotion.bounce,
                width: _height + (constraints.maxWidth - _height) * share,
                height: _height,
                decoration: BoxDecoration(
                  color: colors.primary.fill,
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
