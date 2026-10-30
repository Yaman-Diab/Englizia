import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:flutter/material.dart';

/// What the ladder needs at a moment of the reveal. Everything is a function of
/// the time since it started, so one clock drives the whole scene.
final class LadderMoment {
  const LadderMoment({
    required this.elapsed,
    required this.guidePosition,
    required this.showSparks,
  });

  /// Time since the reveal started. Long past the end when all has settled.
  final Duration elapsed;

  /// Where the guide stands, in steps from the first; a fraction is mid-hop.
  final double guidePosition;
  final bool showSparks;
}

/// The track's levels as a staircase the guide climbs up to the learner's
/// level. Decorative: the text under it says the same, so screen readers skip
/// it. Steps rise toward the end of the reading direction.
class LevelLadder extends StatelessWidget {
  const LevelLadder({
    required this.codes,
    required this.level,
    required this.moment,
    required this.expression,
    this.waiting = false,
    super.key,
  });

  final List<String> codes;

  /// The current level; steps up to it are filled.
  final int level;
  final LadderMoment moment;
  final MascotExpression expression;

  /// The result isn't known: the steps stand empty, and nothing is climbed.
  final bool waiting;

  static const height = 160.0;
  static const _labelHeight = 24.0;
  static const _topStep = 120.0;
  static const _guide = 72.0;

  /// The guide's feet sink a little into the step.
  static const _guideSink = 5.0;
  static const _hopHeight = 26.0;
  static const _trailAboveStep = 6.0;
  static const _trailArc = 30.0;

  double _stepHeight(int index) => _topStep * (index + 1) / codes.length;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final stepWidth = width / codes.length;
          final position = moment.guidePosition;
          final from = position.floor().clamp(0, codes.length - 1);
          final to = position.ceil().clamp(0, codes.length - 1);
          final hop = position - from;
          final start = (from + hop) * stepWidth + stepWidth / 2 - _guide / 2;
          final rise =
              _stepHeight(from) + (_stepHeight(to) - _stepHeight(from)) * hop;
          final arc = math.sin(hop * math.pi) * _hopHeight;
          return SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < codes.length; i++)
                        Expanded(child: _step(context, i)),
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: _labelHeight,
                  height: 2,
                  child: ColoredBox(color: colors.border),
                ),
                if (!waiting) ...[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TrailPainter(
                        tops: [
                          for (var i = 0; i < codes.length; i++)
                            height -
                                _labelHeight -
                                _stepHeight(i) -
                                _trailAboveStep,
                        ],
                        hops: level,
                        elapsed: moment.elapsed,
                        arc: _trailArc,
                        rightToLeft:
                            Directionality.of(context) == TextDirection.rtl,
                        color: colors.primary.fill,
                      ),
                    ),
                  ),
                  if (moment.showSparks)
                    ..._sparks(
                      context,
                      stepWidth: stepWidth,
                      elapsed: moment.elapsed,
                    ),
                ],
                PositionedDirectional(
                  start: start,
                  bottom: _labelHeight + rise - _guideSink + arc,
                  width: _guide,
                  height: _guide,
                  child: Opacity(
                    opacity: _progress(
                      moment.elapsed,
                      PlacementResultEntrance.guide,
                      PlacementResultEntrance.guideFade,
                    ),
                    child: Mascot(
                      expression: expression,
                      sparkles: false,
                      size: _guide,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _step(BuildContext context, int index) {
    final colors = context.colors;
    final texts = context.texts;
    final on = !waiting && index <= level;
    final current = !waiting && index == level;
    final rise = AppMotion.smoothOut.transform(
      _progress(
        moment.elapsed,
        PlacementResultEntrance.stepStagger * index,
        PlacementResultEntrance.stepRise,
      ),
    );
    return Opacity(
      opacity: rise,
      child: Transform.translate(
        offset: Offset(0, AppMotion.distanceBase * (1 - rise)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: _stepHeight(index),
              margin: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: on ? colors.primary.fill : colors.surface,
                borderRadius: const BorderRadiusDirectional.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
                border: Border.all(
                  color: on ? colors.primary.fill : colors.border,
                  width: 1.5,
                ),
              ),
            ),
            SizedBox(
              height: _labelHeight,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    codes[index],
                    textDirection: TextDirection.ltr,
                    style: current
                        ? texts.captionStrong.copyWith(
                            color: colors.primary.text,
                          )
                        : texts.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Two sparks where the guide lands, a little after one another.
  List<Widget> _sparks(
    BuildContext context, {
    required double stepWidth,
    required Duration elapsed,
  }) {
    const big = 14.0;
    const small = 10.0;
    final land = PlacementResultEntrance(level).land;
    final middle = (level + .5) * stepWidth;
    final base = _labelHeight + _stepHeight(level);
    Widget spark(double size, double start, double bottom, Duration delay) {
      final t = _progress(elapsed, delay, PlacementResultEntrance.sparkPop);
      // Up past its size, then settling back.
      final scale = t < .6 ? t / .6 * 1.3 : 1.3 - (t - .6) / .4 * .3;
      return PositionedDirectional(
        start: start,
        bottom: bottom,
        child: Opacity(
          opacity: (t / .6).clamp(0, 1),
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              size: Size.square(size),
              painter: _SparkPainter(context.colors.reward.fill),
            ),
          ),
        ),
      );
    }

    return [
      spark(big, middle - 26 - big, base + 50, land),
      spark(
        small,
        middle + 44 - small,
        base + 62,
        land + PlacementResultEntrance.sparkStagger,
      ),
    ];
  }

  /// How far along a [duration] that started at [delay] is, 0 to 1.
  static double _progress(Duration elapsed, Duration delay, Duration duration) {
    final passed = (elapsed - delay).inMicroseconds;
    return (passed / duration.inMicroseconds).clamp(0, 1).toDouble();
  }
}

/// The dotted arcs the guide left behind, each fading in as it lands.
class _TrailPainter extends CustomPainter {
  const _TrailPainter({
    required this.tops,
    required this.hops,
    required this.elapsed,
    required this.arc,
    required this.rightToLeft,
    required this.color,
  });

  final List<double> tops;
  final int hops;
  final Duration elapsed;
  final double arc;
  final bool rightToLeft;
  final Color color;

  static const _dot = 3.0;
  static const _gap = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stepWidth = size.width / tops.length;
    double x(int step) {
      final start = (step + .5) * stepWidth;
      return rightToLeft ? size.width - start : start;
    }

    for (var i = 0; i < hops; i++) {
      final opacity = LevelLadder._progress(
        elapsed,
        PlacementResultEntrance.climb +
            PlacementResultEntrance.hop * i +
            PlacementResultEntrance.trailDelay,
        PlacementResultEntrance.trailFade,
      );
      if (opacity == 0) continue;
      final path = Path()
        ..moveTo(x(i), tops[i])
        ..quadraticBezierTo(
          (x(i) + x(i + 1)) / 2,
          math.min(tops[i], tops[i + 1]) - arc,
          x(i + 1),
          tops[i + 1],
        );
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = _dot
        ..strokeCap = StrokeCap.round;
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += _gap) {
          final point = metric.getTangentForOffset(d)?.position;
          if (point != null) {
            canvas.drawPoints(PointMode.points, [point], paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed ||
      oldDelegate.hops != hops ||
      oldDelegate.color != color ||
      oldDelegate.rightToLeft != rightToLeft;
}

/// A four-pointed spark.
class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 2;
    final w = size.width;
    final path = Path()
      ..moveTo(c, 0)
      ..quadraticBezierTo(c, c, w, c)
      ..quadraticBezierTo(c, c, c, w)
      ..quadraticBezierTo(c, c, 0, c)
      ..quadraticBezierTo(c, c, c, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => oldDelegate.color != color;
}
