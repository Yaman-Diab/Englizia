import 'dart:math' as math;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// Fills once over a clip's [length] around its play button. Not decoration: it
/// tells how much is left, so it runs under reduce motion too. Give it a key
/// that changes with each play, so it starts over.
class ClipProgressRing extends StatelessWidget {
  const ClipProgressRing({required this.length, required this.size, super.key});

  final Duration length;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.info.fill;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: length,
        builder: (_, value, _) => CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(value: value, color: color),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  static const _stroke = 3.0;
  static const _trackAlpha = .22;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        paint..color = color.withValues(alpha: _trackAlpha),
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        paint..color = color,
      );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
