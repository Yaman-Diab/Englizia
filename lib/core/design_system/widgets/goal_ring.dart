import 'dart:math' as math;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// How far along a goal is, around whatever sits inside: [share] goes from 0 to 1
/// clockwise from the top. Decorative, as the words beside it say the same.
class GoalRing extends StatelessWidget {
  const GoalRing({
    required this.share,
    required this.color,
    required this.child,
    this.size = 48,
    super.key,
  });

  final double share;
  final Color color;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(
        share: share,
        color: color,
        track: context.scheme.outline,
      ),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.share,
    required this.color,
    required this.track,
  });

  final double share;
  final Color color;
  final Color track;

  static const _stroke = 4.5;
  static const _trackAlpha = .45;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(_stroke / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = track.withValues(alpha: _trackAlpha),
    );
    if (share <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * share.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.share != share ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
