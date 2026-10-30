import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// The test's progress, one part per stage in proportion to its questions. A
/// deciding stage slides in from the end, the others shrinking to make room.
class StageBar extends StatelessWidget {
  const StageBar({
    required this.sizes,
    required this.stage,
    required this.progress,
    super.key,
  });

  final List<int> sizes;

  /// The current stage, from 1; those before it are full.
  final int stage;

  /// How full the current stage's part is, 0 to 1.
  final double progress;

  static const _height = 8.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final fixed = sizes.take(2).toList();
    final extra = sizes.skip(2).fold(0, (sum, size) => sum + size);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: extra.toDouble()),
        duration: AppMotion.resolve(context, AppMotion.barGrow),
        curve: AppMotion.out,
        builder: (context, third, _) => LayoutBuilder(
          builder: (context, constraints) {
            final total = fixed.fold(0, (sum, size) => sum + size) + third;
            final gaps =
                _gap * (fixed.length - 1) +
                (extra == 0 ? 0 : _gap * (third / extra));
            final unit = total == 0
                ? 0.0
                : (constraints.maxWidth - gaps) / total;
            return Row(
              children: [
                for (final (i, size) in fixed.indexed) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  _part(context, width: unit * size, number: i + 1),
                ],
                if (third > 0) ...[
                  SizedBox(width: _gap * (third / extra)),
                  _part(context, width: unit * third, number: 3),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _part(
    BuildContext context, {
    required double width,
    required int number,
  }) {
    final colors = context.colors;
    final fill = number < stage
        ? 1.0
        : number == stage
        ? progress
        : 0.0;
    return Container(
      width: width,
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: AnimatedFractionallySizedBox(
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.out,
        alignment: AlignmentDirectional.centerStart,
        widthFactor: fill,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primary.fill,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
        ),
      ),
    );
  }
}
