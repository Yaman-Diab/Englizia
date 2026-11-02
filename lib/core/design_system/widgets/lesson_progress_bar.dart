import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// A lesson's or a review's progress: it starts as a dot, so it reads as a bar
/// and not an empty line, and stretches with a small overshoot.
class LessonProgressBar extends StatelessWidget {
  const LessonProgressBar({
    required this.position,
    required this.total,
    this.label,
    super.key,
  });

  final int position;
  final int total;

  /// What it is the progress of; by default the lesson's.
  final String? label;

  static const _height = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final share = total == 0 ? 0.0 : position / total;
    return Semantics(
      label: label ?? 'lesson_progress'.tr(),
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
