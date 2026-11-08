import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The sea a track is drawn in.
SeaTone seaOf(ProfileTrack? track) => switch (track?.audience) {
  TrackAudience.schoolStudent => SeaTone.emar,
  TrackAudience.child => SeaTone.kids,
  _ => SeaTone.general,
};

/// A soft closed shape through [count] points around an ellipse, each pushed
/// in or out by up to [wobble]; the same [seed] always draws the same shape.
Path islandBlob(
  double cx,
  double cy,
  double rx,
  double ry,
  int seed, {
  double wobble = .1,
  int count = 10,
}) {
  var state = seed;
  double next() {
    state = (state * 9301 + 49297) % 233280;
    return state / 233280;
  }

  final points = [
    for (var i = 0; i < count; i++)
      () {
        final angle = i / count * math.pi * 2;
        final push = 1 + (next() - .5) * 2 * wobble;
        return Offset(
          cx + math.cos(angle) * rx * push,
          cy + math.sin(angle) * ry * push,
        );
      }(),
  ];
  final path = Path()..moveTo(points[0].dx, points[0].dy);
  for (var i = 0; i < count; i++) {
    final p0 = points[(i - 1 + count) % count];
    final p1 = points[i];
    final p2 = points[(i + 1) % count];
    final p3 = points[(i + 2) % count];
    path.cubicTo(
      p1.dx + (p2.dx - p0.dx) / 6,
      p1.dy + (p2.dy - p0.dy) / 6,
      p2.dx - (p3.dx - p1.dx) / 6,
      p2.dy - (p3.dy - p1.dy) / 6,
      p2.dx,
      p2.dy,
    );
  }
  return path..close();
}

/// Draws [draw] in a [width] × [height] box scaled to cover [size], held to
/// the bottom; mirrored when the layout runs left to right, as the designs are
/// drawn right to left.
void _inBox(
  Canvas canvas,
  Size size,
  double width,
  double height, {
  required bool cover,
  required bool mirrored,
  required void Function() draw,
}) {
  final scale = cover
      ? math.max(size.width / width, size.height / height)
      : math.min(size.width / width, size.height / height);
  canvas.save();
  if (mirrored) {
    canvas
      ..translate(size.width, 0)
      ..scale(-1, 1);
  }
  canvas
    ..translate(
      (size.width - width * scale) / 2,
      cover ? size.height - height * scale : (size.height - height * scale) / 2,
    )
    ..scale(scale);
  draw();
  canvas.restore();
}

/// «أنا»'s header: sky and sea, clouds, three lines of waves, and an island
/// with the current unit's medal; the shore meets the page.
class SeaBand extends StatefulWidget {
  const SeaBand({
    required this.tone,
    required this.height,
    this.coverUrl,
    this.drift = false,
    super.key,
  });

  final SeaTone tone;
  final double height;

  /// The current unit's cover, in the medal.
  final String? coverUrl;

  /// The waves drift once: the day's first view.
  final bool drift;

  /// Where the island stands from the start side, in the design's 360 width.
  static double islandX(SeaTone tone) => tone == SeaTone.kids ? 70 : 82;
  static const _medal = 20.0;

  @override
  State<SeaBand> createState() => _SeaBandState();
}

class _SeaBandState extends State<SeaBand> with SingleTickerProviderStateMixin {
  late final _waves = AnimationController(
    vsync: this,
    duration: AppMotion.meWaves,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.drift &&
        !AppMotion.reduceMotion(context) &&
        !_waves.isAnimating) {
      _waves.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _waves.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mirrored = Directionality.of(context) == TextDirection.ltr;
    final sea = SeaPalette.of(context);
    final colors = context.colors;
    final cover = widget.coverUrl;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scale = math.max(width / 360, 1.0);
          final crop = (width - 360 * scale) / 2;
          final fromRight = SeaBand.islandX(widget.tone) * scale + crop;
          final medalTop =
              (widget.height - 96) * scale + widget.height * (1 - scale);
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _waves,
                  builder: (context, _) => CustomPaint(
                    painter: _BandPainter(
                      tone: widget.tone,
                      height: widget.height,
                      sea: sea,
                      post: colors.border,
                      medal: colors.surface,
                      shore: colors.background,
                      drift: AppMotion.meWavesCurve.transform(_waves.value),
                      mirrored: mirrored,
                    ),
                  ),
                ),
              ),
              if (cover != null)
                PositionedDirectional(
                  top: medalTop - SeaBand._medal * scale,
                  end: fromRight - SeaBand._medal * scale,
                  child: ClipOval(
                    child: SizedBox.square(
                      dimension: SeaBand._medal * 2 * scale,
                      child: cover.startsWith('http')
                          ? Image.network(
                              cover,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            )
                          : SvgPicture.asset(cover, fit: BoxFit.cover),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter({
    required this.tone,
    required this.height,
    required this.sea,
    required this.post,
    required this.medal,
    required this.shore,
    required this.drift,
    required this.mirrored,
  });

  final SeaTone tone;
  final double height;
  final SeaPalette sea;
  final Color post;
  final Color medal;
  final Color shore;
  final double drift;
  final bool mirrored;

  static const _width = 360.0;

  Path _wave(double y) {
    final path = Path()..moveTo(-80, y);
    for (var x = -80.0; x < 440; x += 40) {
      path
        ..relativeQuadraticBezierTo(10, -4, 20, 0)
        ..relativeQuadraticBezierTo(10, 4, 20, 0);
    }
    return path;
  }

  void _cloud(Canvas canvas, double x, double y, double scale) {
    final paint = Paint()..color = sea.fog.withValues(alpha: sea.fog.a * .9);
    canvas
      ..save()
      ..translate(x, y)
      ..scale(scale)
      ..drawCircle(const Offset(10, 0), 9, paint)
      ..drawCircle(const Offset(22, -4), 11, paint)
      ..drawCircle(const Offset(33, 1), 7, paint)
      ..drawRRect(RRect.fromLTRBR(2, 0, 38, 8, const Radius.circular(4)), paint)
      ..restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _inBox(
      canvas,
      size,
      _width,
      height,
      cover: true,
      mirrored: mirrored,
      draw: () {
        final shoreY = height - 8;
        // The design's island stands on the left of its right-to-left page.
        final ix = SeaBand.islandX(tone);
        final iy = height - 46;
        final my = iy - 50;
        final island = sea.islandOf(tone);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, _width, height),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              Offset(0, height),
              [sea.haze, sea.sea(tone), sea.depth(tone)],
              const [0, .5, 1],
            ),
        );
        _cloud(canvas, 262, 50, .9);
        _cloud(canvas, 150, 64, .6);
        final wave = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas
          ..save()
          ..translate(80 * drift, 0);
        for (final (offset, alpha) in const [
          (46.0, 1.0),
          (30.0, .8),
          (14.0, .6),
        ]) {
          wave.color = sea.wave.withValues(alpha: sea.wave.a * alpha);
          canvas.drawPath(_wave(shoreY - offset), wave);
        }
        canvas
          ..restore()
          ..drawPath(
            islandBlob(ix, iy + 2, 68, 21, 7),
            Paint()..color = sea.shallow,
          )
          ..drawPath(
            islandBlob(ix, iy, 56, 16, 9),
            Paint()..color = island.sandEdge,
          )
          ..drawPath(
            islandBlob(ix, iy - 1, 52, 14, 11),
            Paint()..color = island.sand,
          )
          ..drawPath(
            islandBlob(ix + 4, iy - 4, 36, 9, 13),
            Paint()..color = island.grass,
          )
          ..drawPath(
            islandBlob(ix + 20, iy - 5, 12, 4, 17),
            Paint()..color = island.grassDeep,
          )
          ..drawRRect(
            RRect.fromLTRBR(
              ix - 1.5,
              my + 20,
              ix + 1.5,
              iy - 4,
              const Radius.circular(1.5),
            ),
            Paint()..color = post,
          )
          ..drawCircle(Offset(ix, my), 23, Paint()..color = medal);
        final edge = Path()..moveTo(0, shoreY);
        for (var i = 0; i < 4; i++) {
          edge.relativeQuadraticBezierTo(45, i.isEven ? -8 : 8, 90, 0);
        }
        edge
          ..lineTo(_width, height)
          ..lineTo(0, height)
          ..close();
        canvas.drawPath(edge, Paint()..color = shore);
      },
    );
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.drift != drift ||
      old.tone != tone ||
      old.sea != sea ||
      old.shore != shore ||
      old.mirrored != mirrored;
}

/// A track's units as a chain of islands (Me v2): those done in colour, the
/// current one bigger with a medal and a pulsing ring, the rest dashed. It
/// fits any number of units, smaller as there are more.
class IslandChain extends StatefulWidget {
  const IslandChain({
    required this.tone,
    required this.unit,
    required this.units,
    super.key,
  });

  final SeaTone tone;
  final int unit;
  final int units;

  static const height = 72.0;

  @override
  State<IslandChain> createState() => _IslandChainState();
}

class _IslandChainState extends State<IslandChain>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.meIslandPulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _pulse.value = 0;
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: IslandChain.height,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ChainPainter(
            unit: widget.unit,
            units: widget.units,
            sea: SeaPalette.of(context),
            island: SeaPalette.of(context).islandOf(widget.tone),
            surface: colors.surface,
            border: colors.border,
            ring: colors.primary.fill,
            medal: colors.primaryStrong,
            pulse: _pulse.value,
            mirrored: Directionality.of(context) == TextDirection.ltr,
          ),
        ),
      ),
    );
  }
}

class _ChainPainter extends CustomPainter {
  _ChainPainter({
    required this.unit,
    required this.units,
    required this.sea,
    required this.island,
    required this.surface,
    required this.border,
    required this.ring,
    required this.medal,
    required this.pulse,
    required this.mirrored,
  });

  final int unit;
  final int units;
  final SeaPalette sea;
  final IslandPalette island;
  final Color surface;
  final Color border;
  final Color ring;
  final Color medal;
  final double pulse;
  final bool mirrored;

  static const _width = 300.0;
  static const _pad = 22.0;

  /// A round-capped line drawn as dots [gap] apart, as a dashed `0 gap` line.
  void _dots(Canvas canvas, Path path, double gap, double width, Color color) {
    final paint = Paint()..color = color;
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at <= metric.length; at += gap) {
        final point = metric.getTangentForOffset(at)?.position;
        if (point != null) canvas.drawCircle(point, width / 2, paint);
      }
    }
  }

  void _dashes(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 5.5) {
        canvas.drawPath(metric.extractPath(at, at + 3), paint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (units < 1) return;
    _inBox(
      canvas,
      size,
      _width,
      IslandChain.height,
      cover: false,
      mirrored: mirrored,
      draw: () {
        final step = units == 1 ? 0.0 : (_width - _pad * 2) / (units - 1);
        final z = units == 1 ? 1.0 : math.min(1.0, step / 34);
        final m = math.max(.75, z);
        final amp = 6 * math.max(.5, z).toDouble();
        final points = [
          for (var i = 0; i < units; i++)
            Offset(_width - _pad - i * step, 46 + (i.isOdd ? -amp : amp)),
        ];
        for (var i = 1; i < units; i++) {
          final a = points[i - 1];
          final b = points[i];
          final bridge = Path()
            ..moveTo(a.dx, a.dy)
            ..cubicTo(a.dx - step / 2, a.dy, b.dx + step / 2, b.dy, b.dx, b.dy);
          final done = i < unit;
          _dots(
            canvas,
            bridge,
            done ? math.max(5, 7 * z).toDouble() : math.max(4.5, 6 * z),
            done ? 3 : 2,
            done ? sea.bridge : sea.bridgeTodo,
          );
        }
        for (final (i, point) in points.indexed) {
          final seed = 11 + i * 37;
          final (x, y) = (point.dx, point.dy);
          if (i > unit - 1) {
            final shape = islandBlob(
              x,
              y,
              12 * z,
              6.5 * z,
              seed,
              wobble: .12,
              count: 8,
            );
            canvas.drawPath(
              shape,
              Paint()..color = surface.withValues(alpha: .55),
            );
            _dashes(
              canvas,
              shape,
              Paint()
                ..color = border
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2,
            );
            continue;
          }
          final current = i == unit - 1;
          final k = (current ? (z < 1 ? 1.2 : 1.35) : 1) * z;
          if (current) {
            final grow = 1 + .45 * pulse;
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset(x, y + 1),
                width: 44 * z * grow,
                height: 24 * z * grow,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = ring.withValues(alpha: .9 * (1 - pulse)),
            );
          }
          canvas
            ..drawPath(
              islandBlob(x, y + 1, 15 * k, 8 * k, seed, wobble: .12, count: 8),
              Paint()..color = sea.shallow,
            )
            ..drawPath(
              islandBlob(
                x,
                y,
                12 * k,
                6.5 * k,
                seed + 1,
                wobble: .12,
                count: 8,
              ),
              Paint()..color = island.sand,
            )
            ..drawPath(
              islandBlob(
                x + 1,
                y - 1.5 * k,
                8 * k,
                4 * k,
                seed + 2,
                wobble: .14,
                count: 8,
              ),
              Paint()..color = island.grass,
            );
          if (current) {
            canvas
              ..drawRect(
                Rect.fromLTWH(x - 1, y - 24 * m, 2, 20 * m),
                Paint()..color = border,
              )
              ..drawCircle(
                Offset(x, y - 26 * m),
                7.5 * m,
                Paint()..color = surface,
              )
              ..drawCircle(
                Offset(x, y - 26 * m),
                7.5 * m,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.5
                  ..color = medal,
              );
          }
        }
      },
    );
  }

  @override
  bool shouldRepaint(_ChainPainter old) =>
      old.pulse != pulse ||
      old.unit != unit ||
      old.units != units ||
      old.sea != sea ||
      old.mirrored != mirrored;
}
