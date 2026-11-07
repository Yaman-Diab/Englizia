import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/read_order.dart';
import 'package:flutter/material.dart';

/// The level's title and units bar over its shore (design "Home
/// Archipelago", map §6, header §6): 40 high with an 8 scalloped edge that
/// hangs over the sea; it sticks under the top bar once the day header has
/// folded. The bar is the screen reader's progress bar: «2 من 8 وحدات».
/// Large text grows the title only as far as the 40 holds it
/// ([maxTextScale]); the title then ends in «…», and the screen reader still
/// has all of it.
class LevelHeader extends StatelessWidget {
  const LevelHeader({required this.home, required this.progress, super.key});

  final HomeSnapshot home;

  /// How far the day header has folded, 0 to 1. The header looks the same at
  /// any fold; the stage moves it.
  final double progress;

  /// The header's own height, and its shore under it.
  static const height = 40.0;
  static const shore = 8.0;

  static const _top = 5.0;
  static const _side = 20.0;
  static const _gap = 8.0;
  static const _barGap = 4.0;
  static const _bar = 4.0;
  static const _barRadius = Radius.circular(2);

  /// The title's line, which the row's height follows.
  static const _line = 22.0;
  static const _kidLine = 24.0;

  /// What the 40 leaves the title's row, under the top and over the bar.
  static const _rowRoom = height - _top - _barGap - _bar;

  /// The largest text scale whose title line fits the row. ASSUMPTION(design):
  /// the header keeps the design's 40 under large text (the map hangs from
  /// it), so its title grows only this far, where the day header grows.
  static double maxTextScale({required bool kids}) =>
      _rowRoom / (kids ? _kidLine : _line);

  /// The fill never shrinks below this share, so an empty bar still shows.
  static const _leastShare = .02;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final total = home.units.length;
    final done = home.unitsDone;
    final count = 'home_units_count'.plural(
      total,
      namedArgs: {'done': '$done'},
    );
    final complete = total > 0 && done >= total;
    final share = total == 0
        ? _leastShare
        : math.max(_leastShare, math.min(1.0, done / total));
    final title = home.kids
        ? texts.title.copyWith(fontSize: 17, height: _kidLine / 17)
        : texts.title.copyWith(fontSize: 15, height: _line / 15);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      sortKey: HomeReadOrder.level,
      child: SizedBox(
        height: height + shore,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: colors.background,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: _top,
                    start: _side,
                    end: _side,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Never taller than its room: the two texts' baselines
                      // can ask a fraction more than the title's line.
                      Flexible(
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: maxTextScale(kids: home.kids),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    levelTitle(home),
                                    style: title.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: _gap),
                              ExcludeSemantics(
                                child: Text(
                                  count,
                                  style: texts.caption.copyWith(
                                    fontSize: 13,
                                    height: 20 / 13,
                                    color: colors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: _barGap),
                      Semantics(
                        role: SemanticsRole.progressBar,
                        label: count,
                        value: '$done',
                        minValue: '0',
                        maxValue: '$total',
                        child: _Bar(
                          share: share,
                          fill: complete
                              ? colors.success.fill
                              : colors.primary.fill,
                          track: colors.primary.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ExcludeSemantics(
              child: CustomPaint(
                size: const Size.fromHeight(shore),
                painter: ShorePainter(
                  color: colors.background,
                  mirrored: Directionality.of(context) == TextDirection.ltr,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.share, required this.fill, required this.track});

  final double share;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.all(LevelHeader._barRadius),
    child: SizedBox(
      height: LevelHeader._bar,
      child: ColoredBox(
        color: track,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: share),
          duration: AppMotion.resolve(context, AppMotion.homeBarGrow),
          curve: AppMotion.out,
          builder: (context, value, _) => FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: const BorderRadius.all(LevelHeader._barRadius),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The level header's scalloped shore: scallops of period 120 between y 2
/// and 7 of an 8 band, stretched across the width (map §6). The design draws
/// it for right-to-left; [mirrored] flips it for English (D1).
class ShorePainter extends CustomPainter {
  const ShorePainter({required this.color, required this.mirrored});

  final Color color;
  final bool mirrored;

  static const _designWidth = 360.0;

  /// The design's path in its 360 × 8 box.
  static Path designPath() => Path()
    ..moveTo(0, 0)
    ..lineTo(360, 0)
    ..lineTo(360, 2)
    ..cubicTo(330, 2, 320, 7, 300, 7)
    ..cubicTo(280, 7, 270, 2, 240, 2)
    ..cubicTo(210, 2, 210, 7, 180, 7)
    ..cubicTo(150, 7, 150, 2, 120, 2)
    ..cubicTo(90, 2, 90, 7, 60, 7)
    ..cubicTo(30, 7, 30, 2, 0, 2)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _designWidth;
    canvas.save();
    if (mirrored) {
      canvas
        ..translate(size.width, 0)
        ..scale(-sx, size.height / LevelHeader.shore);
    } else {
      canvas.scale(sx, size.height / LevelHeader.shore);
    }
    canvas
      ..drawPath(designPath(), Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(ShorePainter old) =>
      old.color != color || old.mirrored != mirrored;
}
