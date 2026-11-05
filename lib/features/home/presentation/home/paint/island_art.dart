import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/sea/island_blob.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/path_commands.dart';
import 'package:englizia/features/home/presentation/home/paint/island_colors.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// What the current island's last stone is drawn as (D8).
enum LastStone { lighthouse, gate, none }

/// The last stone of [unit]: a gate for the level check, a lighthouse for a
/// unit review, otherwise a plain stone; kids never get either.
///
/// ASSUMPTION(design): the design gates its first unit; units come from the
/// server, so the last lesson's kind decides (D8).
LastStone lastStoneOf(HomeUnit unit, {required bool kids}) {
  if (kids || unit.lessons.isEmpty) return LastStone.none;
  final last = unit.lessons.last;
  if (last.levelCheck) return LastStone.gate;
  if (last.kind == LessonKind.unitReview) return LastStone.lighthouse;
  return LastStone.none;
}

/// An island's drawing (map §4, design `isleArt()`): its shallows, sand and
/// grass as seeded blobs, faded by saturation, with tufts; the current one
/// with its trail and last stone, a compact one with its medallion post and,
/// when done, its flag. Each drawing is recorded once as a picture and kept
/// by its inputs; only a waving flag repaints. Decorative: hidden from
/// screen readers. Drawn in the right-to-left layout's physical space,
/// mirrored in left-to-right ones (D1).
class IslandArt extends StatelessWidget {
  /// The current island, as wide as the map and [layout] high. [doneN]
  /// lessons are done; [segments] overrides how much of each trail piece is
  /// drawn (0 to 1); [complete] raises the unit flag, [flagUp] of the way.
  const IslandArt.current({
    required IslandLayout this.layout,
    required this.tone,
    required this.unitIndex,
    required this.saturation,
    required this.doneN,
    required this.segments,
    required LastStone this.last,
    required this.lit,
    required this.flagUp,
    required this.complete,
    required MapFrame this.frame,
    this.flagWave = false,
    super.key,
  }) : status = UnitLessonStatus.current;

  /// A done, open or locked island, folded small ([compactSize]).
  const IslandArt.compact({
    required this.status,
    required this.tone,
    required this.unitIndex,
    required this.flagWave,
    super.key,
  }) : layout = null,
       saturation = 0,
       doneN = 0,
       segments = const {},
       last = null,
       lit = false,
       flagUp = 1,
       complete = false,
       frame = null;

  /// A compact island's drawing box; the art overflows it a little.
  static const compactSize = MapLayout.compactSize;

  final IslandLayout? layout;
  final SeaTone tone;
  final int unitIndex;
  final double saturation;
  final int doneN;
  final Map<int, double> segments;
  final LastStone? last;

  /// The lighthouse's lamp (or the gate's flag) is lit: one lesson to go.
  final bool lit;
  final double flagUp;
  final bool complete;
  final MapFrame? frame;
  final UnitLessonStatus status;

  /// The flag's pennant waves (the loop budget decides; never under reduce
  /// motion).
  final bool flagWave;

  double get _saturation => switch (status) {
    UnitLessonStatus.done => 1,
    UnitLessonStatus.locked => 0,
    UnitLessonStatus.open => .15,
    UnitLessonStatus.current => saturation,
  };

  @override
  Widget build(BuildContext context) {
    final shades = IslandShades.of(context, tone, _saturation);
    final ink = _Ink.of(context);
    final mirrored = Directionality.of(context) == TextDirection.ltr;
    final layout = this.layout;
    final frame = this.frame;
    final current = layout != null && frame != null;
    // Every lesson done: the trail leaves the island and the unit flag rises.
    final finished = current && (complete || doneN >= layout.n);
    final spec = current
        ? _ArtSpec.current(
            layout: layout,
            frame: frame,
            unitIndex: unitIndex,
            shades: shades,
            ink: ink,
            doneN: doneN,
            segments: segments,
            last: last ?? LastStone.none,
            lit: lit,
            exitDrawn: finished,
          )
        : _ArtSpec.compact(
            unitIndex: unitIndex,
            status: status,
            shades: shades,
            ink: ink,
          );
    final flag = current
        ? (finished ? _FlagShape.unit(layout.lastStone, flagUp) : null)
        : (status == UnitLessonStatus.done ? _FlagShape.compact : null);
    final size = current ? Size(frame.width, layout.height) : compactSize;
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                painter: _ArtPainter(spec: spec, mirrored: mirrored),
              ),
            ),
            if (flag != null)
              _WavingFlag(
                shape: flag,
                ink: ink,
                waving: flagWave,
                mirrored: mirrored,
              ),
          ],
        ),
      ),
    );
  }
}

/// The colours an island draws with besides its ground (§5.4 of the plan).
@immutable
final class _Ink {
  const _Ink({
    required this.surface,
    required this.outline,
    required this.primaryStrong,
    required this.reward,
    required this.textPrimary,
    required this.success,
    required this.onSuccess,
    required this.trail,
    required this.trailTodo,
  });

  factory _Ink.of(BuildContext context) {
    final colors = context.colors;
    final sea = SeaPalette.of(context);
    return _Ink(
      surface: colors.surface,
      outline: context.scheme.outline,
      primaryStrong: colors.primaryStrong,
      reward: colors.reward.fill,
      textPrimary: colors.textPrimary,
      success: colors.success.fill,
      onSuccess: colors.surface,
      trail: sea.trail,
      trailTodo: sea.trailTodo,
    );
  }

  final Color surface;
  final Color outline;
  final Color primaryStrong;
  final Color reward;
  final Color textPrimary;
  final Color success;
  final Color onSuccess;
  final Color trail;
  final Color trailTodo;

  @override
  bool operator ==(Object other) =>
      other is _Ink &&
      other.surface == surface &&
      other.outline == outline &&
      other.primaryStrong == primaryStrong &&
      other.reward == reward &&
      other.textPrimary == textPrimary &&
      other.success == success &&
      other.onSuccess == onSuccess &&
      other.trail == trail &&
      other.trailTodo == trailTodo;

  @override
  int get hashCode => Object.hash(
    surface,
    outline,
    primaryStrong,
    reward,
    textPrimary,
    success,
    onSuccess,
    trail,
    trailTodo,
  );
}

/// Everything one island's picture depends on: equal specs draw the same
/// picture, so it is recorded once and kept (map §20).
@immutable
final class _ArtSpec {
  const _ArtSpec.current({
    required IslandLayout this.layout,
    required MapFrame this.frame,
    required this.unitIndex,
    required this.shades,
    required this.ink,
    required this.doneN,
    required this.segments,
    required LastStone this.last,
    required this.lit,
    required this.exitDrawn,
  }) : status = UnitLessonStatus.current;

  const _ArtSpec.compact({
    required this.unitIndex,
    required this.status,
    required this.shades,
    required this.ink,
  }) : layout = null,
       frame = null,
       doneN = 0,
       segments = const {},
       last = null,
       lit = false,
       exitDrawn = false;

  final IslandLayout? layout;
  final MapFrame? frame;
  final int unitIndex;
  final UnitLessonStatus status;
  final IslandShades shades;
  final _Ink ink;
  final int doneN;
  final Map<int, double> segments;
  final LastStone? last;
  final bool lit;
  final bool exitDrawn;

  @override
  bool operator ==(Object other) =>
      other is _ArtSpec &&
      other.unitIndex == unitIndex &&
      other.status == status &&
      other.shades == shades &&
      other.ink == ink &&
      other.doneN == doneN &&
      mapEquals(other.segments, segments) &&
      other.last == last &&
      other.lit == lit &&
      other.exitDrawn == exitDrawn &&
      other.frame == frame &&
      other.layout?.height == layout?.height &&
      listEquals(other.layout?.stones, layout?.stones);

  @override
  int get hashCode => Object.hash(
    unitIndex,
    status,
    shades,
    ink,
    doneN,
    Object.hashAllUnordered(segments.entries.map((e) => (e.key, e.value))),
    last,
    lit,
    exitDrawn,
    frame,
    layout?.height,
    layout == null ? null : Object.hashAll(layout!.stones),
  );

  ui.Picture record() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final layout = this.layout;
    final frame = this.frame;
    if (layout != null && frame != null) {
      _paintCurrent(canvas, layout, frame);
    } else {
      _paintCompact(canvas);
    }
    return recorder.endRecording();
  }

  bool get _odd => unitIndex.isOdd;
  int get _seed => 7 + unitIndex * 53;

  void _paintCurrent(Canvas canvas, IslandLayout layout, MapFrame frame) {
    final h = layout.height;
    final sx = frame.sx;
    _ground(
      canvas,
      cx: frame.scaled(180),
      cy: h / 2 - 10,
      rx: 164,
      ry: h / 2 - 18,
      lx: frame.scaled(180 + (_odd ? 92 : -92)),
      ly: h - 22,
      lrx: 66,
      lry: 34,
      sx: sx,
    );
    _tufts(canvas, layout.tufts);
    _trail(canvas, layout);
    switch (last) {
      case LastStone.gate:
        _gate(canvas, layout.lastStone);
      case LastStone.lighthouse:
        _lighthouse(canvas, layout.lastStone);
      case LastStone.none || null:
        break;
    }
  }

  void _paintCompact(Canvas canvas) {
    const cx = 88.0;
    const cy = 54.0;
    _ground(
      canvas,
      cx: cx,
      cy: cy,
      rx: _odd ? 72 : 78,
      ry: _odd ? 45 : 40,
      lx: cx + (_odd ? 60 : -60),
      ly: cy + (_odd ? -12 : 14),
      lrx: 30,
      lry: 24,
    );
    _tufts(canvas, const [Offset(30, 44), Offset(144, 58), Offset(60, 76)]);
    // The medallion's post, its foot and its ring; the cover is a widget.
    canvas
      ..drawRect(
        const Rect.fromLTWH(86.5, 62, 3, 14),
        Paint()..color = ink.outline,
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(88, 77), width: 18, height: 6),
        Paint()..color = shades.sandEdge,
      )
      ..drawCircle(const Offset(88, 42), 25, Paint()..color = ink.surface);
    if (status == UnitLessonStatus.done) {
      canvas.drawLine(
        const Offset(150, 80),
        const Offset(150, 34),
        _stroke(ink.outline, 2.5),
      );
    }
  }

  /// Shallows, sand edge, sand and grass, each a spit then the island
  /// (map §4.3). Horizontal radii scale with the frame ([sx]).
  void _ground(
    Canvas canvas, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required double lx,
    required double ly,
    required double lrx,
    required double lry,
    double sx = 1,
  }) {
    for (final (grow, rise, color, dy) in [
      (18.0, 16.0, shades.shallow, 6.0),
      (8.0, 8.0, shades.sandEdge, 6.0),
      (7.0, 6.0, shades.sand, 2.0),
      (0.0, 0.0, shades.grass, -4.0),
    ]) {
      final paint = Paint()..color = color;
      canvas
        ..drawPath(
          islandBlob(
            lx,
            ly + dy,
            (lrx + grow * .7) * sx,
            lry + rise * .7,
            _seed + 3,
          ),
          paint,
        )
        ..drawPath(
          islandBlob(cx, cy + dy, (rx + grow) * sx, ry + rise, _seed),
          paint,
        );
    }
  }

  void _tufts(Canvas canvas, List<Offset> at) {
    final path = Path();
    for (final Offset(dx: a, dy: b) in at) {
      path
        ..moveTo(a - 4, b)
        ..relativeLineTo(4, -6)
        ..relativeLineTo(4, 6)
        ..moveTo(a + 3, b + 1)
        ..relativeLineTo(3, -4)
        ..relativeLineTo(3, 4);
    }
    canvas.drawPath(path, _stroke(shades.grassDeep, 2));
  }

  /// The dotted way ahead under the drawn trail: stone to stone up to the
  /// current one, out of the island once it is done (map §4.7).
  void _trail(Canvas canvas, IslandLayout layout) {
    final n = layout.n;
    final todo = _stroke(ink.trailTodo, 3);
    for (var j = 0; j < n; j++) {
      for (final metric in toPath(layout.segments[j]).computeMetrics()) {
        for (var at = 0.0; at < metric.length; at += 10) {
          canvas.drawPath(
            metric.extractPath(at, math.min(at + 2, metric.length)),
            todo,
          );
        }
      }
    }
    final drawn = _stroke(ink.trail, 9);
    for (var j = 0; j <= n; j++) {
      final share =
          segments[j] ??
          (j == n
              ? (exitDrawn ? 1.0 : 0.0)
              : (j == 0 || j <= doneN ? 1.0 : 0.0));
      if (share <= 0) continue;
      final path = toPath(layout.segments[j]);
      if (share >= 1) {
        canvas.drawPath(path, drawn);
        continue;
      }
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * share), drawn);
      }
    }
  }

  /// The level check's gate, drawn round (292, 346) of the design.
  void _gate(Canvas canvas, Offset stone) {
    canvas
      ..save()
      ..translate(stone.dx - 292, stone.dy - 346)
      ..drawOval(
        Rect.fromCenter(center: const Offset(292, 366), width: 52, height: 12),
        Paint()..color = shades.sandEdge,
      );
    final posts = Path()
      ..moveTo(274, 364)
      ..relativeLineTo(0, -34)
      ..moveTo(310, 364)
      ..relativeLineTo(0, -34);
    final flag = Path()
      ..moveTo(292, 312)
      ..relativeLineTo(0, -18)
      ..moveTo(292, 294)
      ..relativeLineTo(14, 0)
      ..relativeLineTo(-4, 5)
      ..relativeLineTo(4, 5)
      ..relativeLineTo(-14, 0);
    canvas
      ..drawPath(posts, _stroke(ink.surface, 9))
      ..drawPath(posts, _stroke(ink.outline, 1.5, cap: StrokeCap.butt))
      ..drawPath(
        Path()
          ..moveTo(270, 332)
          ..quadraticBezierTo(292, 306, 314, 332),
        _stroke(ink.primaryStrong, 6),
      )
      ..drawPath(flag, Paint()..color = lit ? ink.reward : ink.outline)
      ..drawPath(flag, _stroke(ink.outline, 1.5, cap: StrokeCap.butt))
      ..restore();
  }

  /// The unit review's lighthouse, its lamp lit with one lesson to go.
  void _lighthouse(Canvas canvas, Offset stone) {
    final body = Path()
      ..moveTo(280, 366)
      ..relativeLineTo(4, -48)
      ..relativeLineTo(16, 0)
      ..relativeLineTo(4, 48)
      ..close();
    final stripes = Path()
      ..moveTo(281.4, 350)
      ..relativeLineTo(21.2, 0)
      ..relativeLineTo(.6, 7)
      ..relativeLineTo(-22.4, 0)
      ..close()
      ..moveTo(282.8, 332)
      ..relativeLineTo(18.4, 0)
      ..relativeLineTo(.6, 7)
      ..relativeLineTo(-19.6, 0)
      ..close();
    final lamp = RRect.fromLTRBR(284, 304, 300, 318, const Radius.circular(2));
    final roof = Path()
      ..moveTo(281, 305)
      ..relativeLineTo(11, -12)
      ..relativeLineTo(11, 12)
      ..close();
    canvas
      ..save()
      ..translate(stone.dx - 292, stone.dy - 346)
      ..drawOval(
        Rect.fromCenter(center: const Offset(292, 368), width: 44, height: 12),
        Paint()..color = shades.sandEdge,
      )
      ..drawPath(body, Paint()..color = ink.surface)
      ..drawPath(body, _stroke(ink.outline, 1.5, cap: StrokeCap.butt))
      ..drawPath(stripes, Paint()..color = ink.primaryStrong)
      ..drawRRect(lamp, Paint()..color = lit ? ink.reward : ink.surface)
      ..drawRRect(
        lamp,
        _stroke(ink.outline, 1.5, cap: StrokeCap.butt, join: StrokeJoin.miter),
      )
      ..drawPath(roof, Paint()..color = ink.textPrimary)
      ..restore();
  }
}

Paint _stroke(
  Color color,
  double width, {
  StrokeCap cap = StrokeCap.round,
  StrokeJoin join = StrokeJoin.round,
}) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = cap
  ..strokeJoin = join;

/// The recorded pictures, the most recently used last; a few dozen at most
/// (an island's fill animating records one per frame).
abstract final class _Pictures {
  static const _limit = 48;
  static final _kept = <_ArtSpec, ui.Picture>{};

  static ui.Picture of(_ArtSpec spec) {
    final kept = _kept.remove(spec);
    if (kept != null) return _kept[spec] = kept;
    final made = spec.record();
    _kept[spec] = made;
    if (_kept.length > _limit) _kept.remove(_kept.keys.first);
    return made;
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter({required this.spec, required this.mirrored});

  final _ArtSpec spec;
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.drawPicture(_Pictures.of(spec));
    if (mirrored) canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.spec != spec || old.mirrored != mirrored;
}

/// A flag on its pole: the pennant waves about its pole side (map §14,
/// `skewY 0 ↔ −6°`), the check inside reads the right way when mirrored.
@immutable
final class _FlagShape {
  const _FlagShape({
    required this.pennant,
    required this.check,
    required this.checkWidth,
    required this.origin,
    this.pole,
    this.shift = Offset.zero,
  });

  /// A done compact island's ✓ flag; its pole is in the island's picture.
  static final compact = _FlagShape(
    pennant: Path()
      ..moveTo(150, 34)
      ..relativeLineTo(26, 0)
      ..relativeLineTo(-6, 9)
      ..relativeLineTo(6, 9)
      ..relativeLineTo(-26, 0)
      ..close(),
    check: Path()
      ..moveTo(156, 43)
      ..relativeLineTo(3.5, 3.5)
      ..relativeLineTo(7, -7),
    checkWidth: 2.4,
    origin: const Offset(150, 43),
  );

  /// The unit-complete flag, 60 to the end side of the last stone, risen
  /// [up] of its 34 (map §4.7).
  factory _FlagShape.unit(Offset stone, double up) => _FlagShape(
    pole: Path()
      ..moveTo(232, 316)
      ..lineTo(232, 262),
    pennant: Path()
      ..moveTo(232, 262)
      ..relativeLineTo(34, 0)
      ..relativeLineTo(-7, 11)
      ..relativeLineTo(7, 11)
      ..relativeLineTo(-34, 0)
      ..close(),
    check: Path()
      ..moveTo(240, 273)
      ..relativeLineTo(4, 4)
      ..relativeLineTo(8, -8),
    checkWidth: 2.6,
    origin: const Offset(232, 273),
    shift: Offset(
      stone.dx - 292,
      (1 - up.clamp(0.0, 1.0)) * _rise + stone.dy - 346,
    ),
  );

  static const _rise = 34.0;

  final Path? pole;
  final Path pennant;
  final Path check;
  final double checkWidth;

  /// The pennant's pole side, its middle: it skews about this.
  final Offset origin;
  final Offset shift;
}

class _WavingFlag extends StatefulWidget {
  const _WavingFlag({
    required this.shape,
    required this.ink,
    required this.waving,
    required this.mirrored,
  });

  final _FlagShape shape;
  final _Ink ink;
  final bool waving;
  final bool mirrored;

  @override
  State<_WavingFlag> createState() => _WavingFlagState();
}

class _WavingFlagState extends State<_WavingFlag>
    with SingleTickerProviderStateMixin {
  late final _wave = AnimationController(
    vsync: this,
    duration: AppMotion.homeFlag,
  );
  late final _eased = CurvedAnimation(parent: _wave, curve: AppMotion.inOut);

  void _sync() {
    final run = widget.waving && !AppMotion.reduceMotion(context);
    if (run && !_wave.isAnimating) {
      _wave.repeat(reverse: true);
    } else if (!run && _wave.isAnimating) {
      _wave.stop();
    }
    if (!run && AppMotion.reduceMotion(context)) _wave.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_WavingFlag old) {
    super.didUpdateWidget(old);
    if (old.waving != widget.waving) _sync();
  }

  @override
  void dispose() {
    _eased.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _FlagPainter(
      shape: widget.shape,
      ink: widget.ink,
      mirrored: widget.mirrored,
      wave: _eased,
    ),
  );
}

class _FlagPainter extends CustomPainter {
  _FlagPainter({
    required this.shape,
    required this.ink,
    required this.mirrored,
    required this.wave,
  }) : super(repaint: wave);

  final _FlagShape shape;
  final _Ink ink;
  final bool mirrored;
  final Animation<double> wave;

  static final _tilt = math.tan(-AppMotion.homeFlagSkew * math.pi / 180);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (mirrored) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.translate(shape.shift.dx, shape.shift.dy);
    final pole = shape.pole;
    if (pole != null) canvas.drawPath(pole, _stroke(ink.outline, 3));
    final origin = shape.origin;
    canvas
      ..translate(origin.dx, origin.dy)
      ..skew(0, _tilt * wave.value)
      ..translate(-origin.dx, -origin.dy)
      ..drawPath(shape.pennant, Paint()..color = ink.success);
    if (mirrored) {
      // The check keeps its reading direction inside the mirrored pennant.
      final middle = shape.check.getBounds().center.dx;
      canvas
        ..translate(middle * 2, 0)
        ..scale(-1, 1);
    }
    canvas
      ..drawPath(shape.check, _stroke(ink.onSuccess, shape.checkWidth))
      ..restore();
  }

  @override
  bool shouldRepaint(_FlagPainter old) =>
      old.shape != shape ||
      old.ink != ink ||
      old.mirrored != mirrored ||
      old.wave != wave;
}
