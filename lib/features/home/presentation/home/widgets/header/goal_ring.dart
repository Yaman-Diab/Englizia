import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/goal_ring.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/read_order.dart';
import 'package:flutter/material.dart';

/// Today's ring over the header, with the guide in it, shrinking to the top
/// bar as the header folds (design "Home Archipelago").
///
/// It fills the stage's main area (y 0 at the top bar's top) and places the
/// 96 box itself at [StageMetrics.ringTop], scaled by
/// [StageMetrics.ringScale] about its top end corner. The arc runs clockwise
/// from 12 o'clock in both directions. Kids have no ring: their 80 guide
/// stands in the box. On a v0.1 server there is no ring either: the 80 guide
/// waves in the header's ring column and fades with the greeting.
///
/// Reads from [overrides]: `ringFraction`, `minutes` and `ringSuccess` as
/// values; `ringArcIn`, `ringGuideIn` (1 at rest), `guideJump`, `guideHop`
/// and `ringSparks` (0 at rest) as linear progress, 0 to 1, of their motion,
/// to which the ring applies the design's curve and keyframes. `ringSparks`
/// spans the whole burst, [sparksDuration].
class GoalRingOverlay extends StatelessWidget {
  const GoalRingOverlay({
    required this.metrics,
    required this.fraction,
    required this.success,
    required this.minutes,
    required this.goal,
    required this.minutesInside,
    required this.guide,
    required this.expression,
    required this.waving,
    required this.overrides,
    required this.kids,
    required this.v01,
    required this.onGuideTap,
    super.key,
  });

  final StageMetrics metrics;

  /// Today's minutes over the goal, 0 to 1.
  final double fraction;

  /// The goal is reached: the arc turns the success colour.
  final bool success;
  final int minutes;
  final int goal;

  /// The guide has left the ring with the header open: the minutes show in
  /// its centre ([ringShowsMinutes]).
  final bool minutesInside;
  final GuidePlacement guide;
  final MascotExpression expression;

  /// The guide was tapped; it also waves while nothing is done today.
  final bool waving;
  final HeaderOverrides overrides;
  final bool kids;
  final bool v01;
  final VoidCallback onGuideTap;

  static const box = StageMetrics.ringBox;
  static const guideSize = 64.0;
  static const kidGuideSize = 80.0;

  /// The ring guide's inset in the box; the kids' 80 one's.
  static const guideInset = 16.0;
  static const kidGuideInset = (side: 8.0, top: 4.0);

  /// v0.1: the 80 guide's gap above it, in the header's ring column.
  static const v01GuideTop = 8.0;

  /// The goal's six sparks, each [AppMotion.homeSparks] long, each
  /// [AppMotion.homeSparkStep] after the one before.
  static const sparkCount = 6;
  static Duration get sparksDuration =>
      AppMotion.homeSparks + AppMotion.homeSparkStep * (sparkCount - 1);

  /// The ring guide's face for today: happy at the goal, encouraging on the
  /// way, welcoming before the first minute; kids' is always welcoming.
  static MascotExpression expressionFor(double fraction, {bool kids = false}) {
    if (kids) return MascotExpression.welcome;
    if (fraction >= 1) return MascotExpression.happy;
    if (fraction > 0) return MascotExpression.encourage;
    return MascotExpression.welcome;
  }

  /// The arc drawn: the fraction (or its override) as far as M1 has drawn it.
  double get shownFraction {
    final f = (overrides.ringFraction ?? fraction).clamp(0.0, 1.0);
    final arcIn = overrides.ringArcIn.clamp(0.0, 1.0);
    return f * AppMotion.homeRingIn.transform(arcIn);
  }

  @override
  Widget build(BuildContext context) {
    final here = guide is GuideInRing;
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [if (v01) _v01Guide(here) else _ring(context, here)],
      ),
    );
  }

  Widget _v01Guide(bool here) => PositionedDirectional(
    end: metrics.ringLeft,
    top:
        StageMetrics.topBar +
        metrics.topSlot -
        metrics.collapse +
        metrics.pull +
        v01GuideTop,
    width: kidGuideSize,
    height: kidGuideSize,
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: metrics.greetingOpacity,
          child: _GuidePresence(
            here: here,
            child: const Mascot(
              size: kidGuideSize,
              waving: true,
              sparkles: false,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _ring(BuildContext context, bool here) {
    final f = shownFraction;
    final shownMinutes = math.min(overrides.minutes ?? minutes, 99);
    final wave = waving || (overrides.ringFraction ?? fraction) <= 0;
    final sparks = overrides.ringSparks;
    final Widget guideWidget;
    if (kids) {
      guideWidget = PositionedDirectional(
        top: kidGuideInset.top,
        end: kidGuideInset.side,
        width: kidGuideSize,
        height: kidGuideSize,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: _GuidePresence(
              here: here,
              child: _GuideMotion(
                overrides: overrides,
                child: Mascot(
                  expression: expression,
                  size: kidGuideSize,
                  waving: wave,
                  sparkles: false,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      guideWidget = PositionedDirectional(
        top: guideInset,
        start: guideInset,
        width: guideSize,
        height: guideSize,
        child: _GuidePresence(
          here: here,
          child: IgnorePointer(
            ignoring: !here,
            child: Semantics(
              button: here,
              sortKey: here ? HomeReadOrder.guide : null,
              label: here ? 'mascot_name'.tr() : null,
              onTap: here ? onGuideTap : null,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onGuideTap,
                child: _GuideMotion(
                  overrides: overrides,
                  child: Mascot(
                    expression: expression,
                    size: guideSize,
                    waving: wave,
                    sparkles: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return PositionedDirectional(
      end: metrics.ringLeft,
      top: metrics.ringTop,
      width: box,
      height: box,
      child: Transform.scale(
        scale: metrics.ringScale,
        alignment: AlignmentDirectional.topEnd,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!kids) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: _RingArt(
                      fraction: f,
                      success: overrides.ringSuccess ?? success,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: minutesInside ? 1 : 0,
                        duration: AppMotion.quick,
                        curve: AppMotion.out,
                        child: Text(
                          '$shownMinutes/$goal',
                          textDirection: TextDirection.ltr,
                          style: context.texts
                              .sized(
                                context.texts.title,
                                size: 22,
                                line: 22,
                                running: false,
                              )
                              .copyWith(
                                color: context.colors.textPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (sparks != null && sparks > 0 && sparks < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: RingSparksPainter(
                          t: sparks,
                          color: context.colors.reward.fill,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            guideWidget,
          ],
        ),
      ),
    );
  }
}

/// The guide shows while it is in the ring, fading as it comes and goes.
class _GuidePresence extends StatelessWidget {
  const _GuidePresence({required this.here, required this.child});

  final bool here;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: here ? 1 : 0,
    duration: AppMotion.quick,
    curve: Curves.ease,
    child: child,
  );
}

/// The ring guide's arrival (M1), its jump at the goal and its hop back from
/// a card.
class _GuideMotion extends StatelessWidget {
  const _GuideMotion({required this.overrides, required this.child});

  final HeaderOverrides overrides;
  final Widget child;

  /// M1: the guide rises [AppMotion.homeGuideInRise] from half its size,
  /// over-reaching to 1.05 at 60%.
  static const _inPeak = .6;
  static const _inLift = -8.0;
  static const _inFrom = .5;
  static const _inOver = 1.05;

  /// A jump or a hop peaks 40% in.
  static const _peak = .4;
  static const _hopHeight = 8.0;

  static double bump(double t) {
    if (t <= 0 || t >= 1) return 0;
    final k = AppMotion.out.transform(t);
    return k < _peak ? k / _peak : 1 - (k - _peak) / (1 - _peak);
  }

  @override
  Widget build(BuildContext context) {
    final arrive = AppMotion.out.transform(
      overrides.ringGuideIn.clamp(0.0, 1.0),
    );
    double dy;
    double scale;
    double opacity;
    if (arrive < _inPeak) {
      final k = arrive / _inPeak;
      dy = lerpDouble(AppMotion.homeGuideInRise, _inLift, k)!;
      scale = lerpDouble(_inFrom, _inOver, k)!;
      opacity = k;
    } else {
      final k = (arrive - _inPeak) / (1 - _inPeak);
      dy = lerpDouble(_inLift, 0, k)!;
      scale = lerpDouble(_inOver, 1, k)!;
      opacity = 1;
    }
    dy -= AppMotion.homeGuideJumpHeight * bump(overrides.guideJump);
    dy -= _hopHeight * bump(overrides.guideHop);
    // The same wrappers at rest, so the guide keeps its wave and blink.
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }
}

/// The ring's drawing in the 96 box: the core ring, stroke 8 (radius 44),
/// round the 72 disk with a 4 gap of background between them. Its colour
/// changes over [AppMotion.homeRingColor].
class _RingArt extends StatelessWidget {
  const _RingArt({required this.fraction, required this.success});

  final double fraction;
  final bool success;

  static const _stroke = 8.0;
  static const _disk = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end: success ? colors.success.fill : colors.primary.fill,
      ),
      duration: AppMotion.resolve(context, AppMotion.homeRingColor),
      curve: AppMotion.out,
      builder: (context, arc, _) => GoalRing(
        share: fraction,
        color: arc ?? colors.primary.fill,
        size: StageMetrics.ringBox,
        stroke: _stroke,
        child: SizedBox.square(
          dimension: _disk,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.surface,
            ),
          ),
        ),
      ),
    );
  }
}

/// The goal's six sparks around the ring: each starts
/// [AppMotion.homeSparkStep] after the one before and runs
/// [AppMotion.homeSparks], from radius 44 at .4 scale, through 55 at full size
/// 40% in, to 66 at .6, fading in then out.
class RingSparksPainter extends CustomPainter {
  const RingSparksPainter({required this.t, required this.color});

  /// The whole burst's progress, 0 to 1 over
  /// [GoalRingOverlay.sparksDuration].
  final double t;
  final Color color;

  static const _r0 = 44.0;
  static const _r1 = 55.0;
  static const _r2 = 66.0;
  static const _peak = .4;
  static const _dot = 4.0;

  /// Spark [j]'s radius, scale and opacity at the burst's [t].
  static ({double radius, double scale, double opacity}) sparkAt(
    int j,
    double t,
  ) {
    final total = GoalRingOverlay.sparksDuration.inMicroseconds;
    final start = AppMotion.homeSparkStep.inMicroseconds * j;
    final local = ((t * total - start) / AppMotion.homeSparks.inMicroseconds)
        .clamp(0.0, 1.0);
    final k = AppMotion.out.transform(local);
    if (local <= 0) return (radius: _r0, scale: .4, opacity: 0);
    if (k < _peak) {
      final u = k / _peak;
      return (
        radius: lerpDouble(_r0, _r1, u)!,
        scale: lerpDouble(.4, 1, u)!,
        opacity: u,
      );
    }
    final u = (k - _peak) / (1 - _peak);
    return (
      radius: lerpDouble(_r1, _r2, u)!,
      scale: lerpDouble(1, .6, u)!,
      opacity: 1 - u,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / StageMetrics.ringBox;
    final centre = size.center(Offset.zero);
    for (var j = 0; j < GoalRingOverlay.sparkCount; j++) {
      final spark = sparkAt(j, t);
      if (spark.opacity <= 0) continue;
      final a = j / GoalRingOverlay.sparkCount * 2 * math.pi - math.pi / 2;
      canvas.drawCircle(
        centre + Offset(math.cos(a), math.sin(a)) * (spark.radius * scale),
        _dot * spark.scale * scale,
        Paint()..color = color.withValues(alpha: spark.opacity * color.a),
      );
    }
  }

  @override
  bool shouldRepaint(RingSparksPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
