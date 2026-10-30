import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A success mark: a circle that grows in after [growDelay], then a check that
/// draws itself after [checkDelay]. Decorative, as a title beside it says what
/// happened; under reduce motion, all of it is simply there.
class SuccessBadge extends StatelessWidget {
  const SuccessBadge({
    required this.size,
    required this.checkSize,
    required this.ringColor,
    required this.growDelay,
    required this.checkDelay,
    super.key,
  });

  final double size;
  final double checkSize;

  /// The ring that separates it from what it sits on.
  final Color ringColor;
  final Duration growDelay;
  final Duration checkDelay;

  static const _ring = 4.0;
  static const _growFrom = .6;
  static const _checkDraw = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduce = AppMotion.reduceMotion(context);
    final mark = colors.onPrimaryStrong;
    final badge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.success.fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor,
          width: _ring,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: reduce
          ? _check(1, mark)
          : SizedBox.square(dimension: checkSize).animate().custom(
              delay: checkDelay,
              duration: _checkDraw,
              curve: AppMotion.inOut,
              builder: (_, value, _) => _check(value, mark),
            ),
    );
    return ExcludeSemantics(
      child: reduce
          ? badge
          : badge
                .animate()
                .fadeIn(
                  delay: growDelay,
                  duration: AppMotion.fast,
                  curve: AppMotion.out,
                )
                .scaleXY(begin: _growFrom, end: 1, curve: AppMotion.bounce),
    );
  }

  Widget _check(double progress, Color color) => CustomPaint(
    size: Size.square(checkSize),
    painter: _CheckPainter(progress: progress, color: color),
  );
}

/// The check of the app's icons (`AppIcon.check`), drawn up to [progress].
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _viewBox = 24.0;
  static const _stroke = 2.8;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.scale(size.width / _viewBox);
    final check = Path()
      ..moveTo(5, 12.5)
      ..lineTo(9.5, 17)
      ..lineTo(19, 7.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final metric = check.computeMetrics().single;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
