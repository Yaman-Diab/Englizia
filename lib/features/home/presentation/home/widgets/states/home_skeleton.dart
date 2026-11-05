import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/color_mix.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// The first load's shape (header §8.4): the greeting lines, the ring, the
/// level bar and an island with its stones and bubble cut out, with a sheen
/// passing over it. It fills the stage between the top bar and the tab bar;
/// ASSUMPTION(design): D40, in kids mode too (the bar is the route's shell).
///
/// Flutter has no "busy" flag, so the label, a live region, says it loads.
class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final _sheen = AnimationController(
    vsync: this,
    duration: AppMotion.homeShimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _sheen.stop();
    } else if (!_sheen.isAnimating) {
      unawaited(_sheen.repeat());
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // SK: the border tone, faint on the background, as the markup mixes it
    // (the board says on the surface: header §16.4).
    final tone = mixOklab(context.scheme.outline, colors.background, .20);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'home_loading'.tr(),
      child: ClipRect(
        child: ColoredBox(
          color: colors.background,
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Shapes(tone: tone),
                _Sheen(
                  progress: _sheen,
                  still: AppMotion.reduceMotion(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's and the map's placeholders where the design draws them
/// (RTL physical: right = start, so English mirrors them).
class _Shapes extends StatelessWidget {
  const _Shapes({required this.tone});

  final Color tone;

  static const _edge = 20.0;
  static const _ring = 96.0;
  static const _ringBorder = 8.0;
  static const _ringGap = 16.0;
  static const _mapTop = 162.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The greeting column is what the ring and its gap leave: at 320dp
        // the status line (190) keeps to it instead of touching the ring.
        final column = math.max(
          0.0,
          constraints.maxWidth - _edge * 2 - _ring - _ringGap,
        );
        Widget line(double top, double width, double height, double radius) =>
            PositionedDirectional(
              start: _edge,
              top: top,
              width: math.min(width, column),
              height: height,
              child: _Fill(color: tone, radius: radius),
            );
        return Stack(
          children: [
            line(6, 150, 22, 8),
            line(38, 96, 12, 6),
            line(66, 190, 16, 8),
            PositionedDirectional(
              end: _edge,
              top: 0,
              width: _ring,
              height: _ring,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tone, width: _ringBorder),
                ),
              ),
            ),
            PositionedDirectional(
              start: _edge,
              end: _edge,
              top: 124,
              height: 14,
              child: _Fill(color: tone, radius: 7),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              top: _mapTop,
              bottom: 0,
              child: _MapShapes(tone: tone),
            ),
          ],
        );
      },
    );
  }
}

/// The sea (the skeleton tone, lighter), one island, and three stones and
/// the bubble cut out of it in the background colour.
class _MapShapes extends StatelessWidget {
  const _MapShapes({required this.tone});

  final Color tone;

  static const _islandInset = 14.0;
  static const _islandTop = 22.0;
  static const _islandHeight = 400.0;
  static const _stone = 48.0;

  @override
  Widget build(BuildContext context) {
    final background = context.colors.background;
    return ColoredBox(
      color: mixOklch(tone, background, .60),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = math.max(0.0, constraints.maxWidth - _islandInset * 2);
          const h = _islandHeight;
          // CSS `46% 54% 50% 50% / 30% 32% 36% 34%` (top-left, top-right,
          // bottom-right, bottom-left); in RTL the right corners are start.
          final island = BorderRadiusDirectional.only(
            topStart: Radius.elliptical(.54 * w, .32 * h),
            topEnd: Radius.elliptical(.46 * w, .30 * h),
            bottomStart: Radius.elliptical(.50 * w, .36 * h),
            bottomEnd: Radius.elliptical(.50 * w, .34 * h),
          );
          Widget stone({double? start, double? end, required double top}) =>
              PositionedDirectional(
                start: start,
                end: end,
                top: top,
                width: _stone,
                height: _stone,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                  ),
                ),
              );
          return Stack(
            children: [
              PositionedDirectional(
                start: _islandInset,
                end: _islandInset,
                top: _islandTop,
                height: h,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: tone, borderRadius: island),
                ),
              ),
              stone(start: 62, top: 62),
              stone(start: 146, top: 70),
              stone(end: 56, top: 62),
              PositionedDirectional(
                start: 20,
                end: 46,
                top: 146,
                height: 168,
                child: _Fill(color: background, radius: 24),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// A band 60% of the width with a soft light across it, sweeping from −120%
/// to 220% of its own width: the design's left to right in RTL, so right to
/// left in English (D1). Under reduce motion it rests at 40%, as drawn.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.progress, required this.still});

  final Animation<double> progress;
  final bool still;

  static const _share = .6;
  static const _from = -1.2;
  static const _to = 2.2;
  static const _rest = .4;
  static const _light = .55;

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surface;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            width: constraints.maxWidth * _share,
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, child) {
                final x = still
                    ? _rest
                    : _from +
                          (_to - _from) *
                              AppMotion.inOut.transform(progress.value);
                return FractionalTranslation(
                  translation: Offset(rtl ? x : -x, 0),
                  child: child,
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Transparent ends of the same colour, so the edges fade
                  // without a grey fringe.
                  gradient: LinearGradient(
                    colors: [
                      surface.withValues(alpha: 0),
                      surface.withValues(alpha: _light),
                      surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
