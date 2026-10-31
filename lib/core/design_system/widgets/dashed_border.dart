import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

/// A dashed rounded edge around [child], for a place not filled or not offered
/// yet.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    required this.color,
    required this.radius,
    required this.child,
    this.width = 1,
    super.key,
  });

  final Color color;
  final double radius;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedBorderPainter(
      color: color,
      radius: radius,
      width: width,
    ),
    child: child,
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.width,
  });

  final Color color;
  final double radius;
  final double width;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(width / 2),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    for (final PathMetric metric in border.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.width != width;
}
