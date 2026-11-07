import 'dart:math' as math;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// How far along a goal is, around whatever sits inside: [share] goes from 0 to 1
/// clockwise from the top. Decorative, as the words beside it say the same.
class GoalRing extends StatelessWidget {
  const GoalRing({
    required this.share,
    required this.color,
    this.child,
    this.size = 48,
    this.stroke = 4.5,
    this.track,
    super.key,
  });

  final double share;
  final Color color;
  final double size;
  final Widget? child;

  /// The ring's width, inside [size].
  final double stroke;

  /// Under the arc; the theme's outline, faded, unless given.
  final Color? track;

  static const _trackAlpha = .45;

  /// The arc's sweep for [share], clockwise from 12 o'clock; none at 0, so
  /// no lone round cap shows.
  static double sweepOf(double share) => 2 * math.pi * share.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(
        share: share,
        color: color,
        stroke: stroke,
        track: track ?? context.scheme.outline.withValues(alpha: _trackAlpha),
      ),
      child: child == null ? null : Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.share,
    required this.color,
    required this.stroke,
    required this.track,
  });

  final double share;
  final Color color;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    final sweep = GoalRing.sweepOf(share);
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.share != share ||
      oldDelegate.color != color ||
      oldDelegate.stroke != stroke ||
      oldDelegate.track != track;
}
