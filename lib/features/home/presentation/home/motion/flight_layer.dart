import 'dart:async';
import 'dart:math' as math;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/presentation/home/motion/motion_timeline.dart';
import 'package:flutter/widgets.dart';

/// The flying guide at one moment: its centre and size on the stage.
typedef FlightPose = ({
  Offset centre,
  double size,
  MascotExpression expression,
});

/// One spark of a burst: where, how big, how clear.
typedef SparkDot = ({Offset centre, double radius, double opacity});

/// The guide's flight and the sparks' burst as pure functions of time
/// (design "Home Archipelago", motion §1.1, §1.2).
abstract final class FlightPath {
  /// A spark's radius at full size.
  static const sparkRadius = 4.0;

  /// The guide [t] of the way (eased by [AppMotion.homeFlight]) from [from]
  /// to [to]: a V through a point [AppMotion.homeFlightApex] above the higher
  /// end, its size through the two sizes' middle.
  static ({Offset centre, double size}) at({
    required Offset from,
    required double fromSize,
    required Offset to,
    required double toSize,
    required double t,
  }) {
    final apex = Offset(
      (from.dx + to.dx) / 2,
      math.min(from.dy, to.dy) - AppMotion.homeFlightApex,
    );
    final middle = (fromSize + toSize) / 2;
    if (t <= .5) {
      final k = t / .5;
      return (
        centre: Offset.lerp(from, apex, k)!,
        size: lerp(fromSize, middle, k),
      );
    }
    final k = (t - .5) / .5;
    return (centre: Offset.lerp(apex, to, k)!, size: lerp(middle, toSize, k));
  }

  /// How long a burst of [count] sparks lasts, the last one starting
  /// [AppMotion.homeSparkStep] after the one before.
  static Duration burstLength(int count) =>
      AppMotion.homeSparks + AppMotion.homeSparkStep * math.max(0, count - 1);

  /// Spark [j] of [count] around [centre] at [ms] into the burst: the first
  /// one straight up, each out from [r0] past [r1] to [r2].
  static SparkDot spark({
    required Offset centre,
    required int j,
    required int count,
    required double ms,
    double r0 = 22,
    double r1 = 36,
    double r2 = 52,
  }) {
    final angle = j / count * 2 * math.pi - math.pi / 2;
    final start = AppMotion.homeSparkStep * j;
    final local = ms - msOf(start);
    if (local < 0 || local >= msOf(AppMotion.homeSparks)) {
      return (centre: centre, radius: 0, opacity: 0);
    }
    final e = phase(ms, start, AppMotion.homeSparks, AppMotion.out);
    final r = keyframes(e, [(0, r0), (.4, r1), (1, r2)]);
    final scale = keyframes(e, const [(0, .4), (.4, 1), (1, .6)]);
    final opacity = keyframes(e, const [(0, 0), (.4, 1), (1, 0)]);
    return (
      centre: centre + Offset(math.cos(angle) * r, math.sin(angle) * r),
      radius: sparkRadius * scale,
      opacity: opacity.clamp(0.0, 1.0),
    );
  }
}

final class _Flight {
  _Flight({
    required this.from,
    required this.fromSize,
    required this.to,
    required this.toSize,
    required this.length,
    required this.expression,
    required this.start,
  });

  final Offset from;
  final double fromSize;
  final Offset to;
  final double toSize;
  final Duration length;
  final MascotExpression expression;
  final Duration start;
  final done = Completer<void>();
}

final class _Burst {
  _Burst({
    required this.centre,
    required this.count,
    required this.r0,
    required this.r1,
    required this.r2,
    required this.start,
  });

  final Offset centre;
  final int count;
  final double r0;
  final double r1;
  final double r2;
  final Duration start;
  final done = Completer<void>();

  Duration get length => FlightPath.burstLength(count);
}

/// The guide's flights and the sparks' bursts over the stage (motion §1).
/// Positions are the stage's right-to-left frame (D1): x from the left of
/// the right-to-left layout, y from the top of the top bar; the layer
/// mirrors them in English. One guide: a new flight ends the one before.
class FlightLayerController extends ChangeNotifier {
  /// Runs on [vsync]'s frames when given, so it pauses with its page.
  FlightLayerController({TickerProvider? vsync}) {
    _clock = MotionClock(vsync, _tick);
  }

  late final MotionClock _clock;
  _Flight? _flight;
  final _bursts = <_Burst>[];
  BuildContext? _context;
  var _disposed = false;

  /// The guide is in the air.
  bool get flying => _flight != null;

  /// The mounted layer's context, for an overlay above home ([ContainerReveal]).
  BuildContext? get overlayContext => _context;

  /// Where the flying guide is now, if it flies.
  FlightPose? get guide {
    final flight = _flight;
    if (flight == null) return null;
    final at = FlightPath.at(
      from: flight.from,
      fromSize: flight.fromSize,
      to: flight.to,
      toSize: flight.toSize,
      t: phase(
        msOf(_clock.now),
        flight.start,
        flight.length,
        AppMotion.homeFlight,
      ),
    );
    return (centre: at.centre, size: at.size, expression: flight.expression);
  }

  /// Every spark now in the air.
  List<SparkDot> get sparks => [
    for (final burst in _bursts)
      for (var j = 0; j < burst.count; j++)
        FlightPath.spark(
          centre: burst.centre,
          j: j,
          count: burst.count,
          ms: msOf(_clock.now - burst.start),
          r0: burst.r0,
          r1: burst.r1,
          r2: burst.r2,
        ),
  ];

  /// Flies the guide from [from] at [fromSize] to [to] at [toSize] over
  /// [duration] with [expression]; done when it lands (or another flight
  /// takes over).
  Future<void> fly(
    Offset from,
    double fromSize,
    Offset to,
    double toSize,
    Duration duration,
    MascotExpression expression,
  ) {
    if (_disposed) return Future.value();
    _land(_flight);
    final flight = _Flight(
      from: from,
      fromSize: fromSize,
      to: to,
      toSize: toSize,
      length: duration,
      expression: expression,
      start: _clock.now,
    );
    _flight = flight;
    _clock.start();
    notifyListeners();
    return flight.done.future;
  }

  /// [count] sparks out from [centre] (motion §1.2); done when the last one
  /// fades.
  Future<void> burst(
    Offset centre,
    int count, {
    double r0 = 22,
    double r1 = 36,
    double r2 = 52,
  }) {
    if (_disposed || count <= 0) return Future.value();
    final burst = _Burst(
      centre: centre,
      count: count,
      r0: r0,
      r1: r1,
      r2: r2,
      start: _clock.now,
    );
    _bursts.add(burst);
    _clock.start();
    notifyListeners();
    return burst.done.future;
  }

  /// Ends every flight and burst at once.
  void cancel() {
    _land(_flight);
    _flight = null;
    for (final burst in _bursts) {
      if (!burst.done.isCompleted) burst.done.complete();
    }
    _bursts.clear();
    _clock.stop();
    if (!_disposed) notifyListeners();
  }

  void _land(_Flight? flight) {
    if (flight != null && !flight.done.isCompleted) flight.done.complete();
  }

  void _tick() {
    final now = _clock.now;
    final flight = _flight;
    if (flight != null && now - flight.start >= flight.length) {
      _flight = null;
      _land(flight);
    }
    _bursts.removeWhere((burst) {
      final over = now - burst.start >= burst.length;
      if (over && !burst.done.isCompleted) burst.done.complete();
      return over;
    });
    if (_flight == null && _bursts.isEmpty) _clock.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    cancel();
    _disposed = true;
    _clock.dispose();
    super.dispose();
  }
}

/// Draws [controller]'s flights and sparks above everything; it takes no
/// touches and says nothing to a screen reader. Fill the stage with it.
class FlightLayer extends StatelessWidget {
  const FlightLayer({required this.controller, super.key});

  final FlightLayerController controller;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(child: _FlightLayerBody(controller: controller)),
  );
}

class _FlightLayerBody extends StatefulWidget {
  const _FlightLayerBody({required this.controller});

  final FlightLayerController controller;

  @override
  State<_FlightLayerBody> createState() => _FlightLayerBodyState();
}

class _FlightLayerBodyState extends State<_FlightLayerBody> {
  @override
  void initState() {
    super.initState();
    widget.controller._context = context;
  }

  @override
  void didUpdateWidget(_FlightLayerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._context == context) {
        oldWidget.controller._context = null;
      }
      widget.controller._context = context;
    }
  }

  @override
  void dispose() {
    if (widget.controller._context == context) {
      widget.controller._context = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final guide = widget.controller.guide;
      final sparks = widget.controller.sparks;
      if (guide == null && sparks.isEmpty) return const SizedBox.expand();
      final mirror = Directionality.of(context) == TextDirection.ltr;
      return LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: [
            if (sparks.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: SparksPainter(
                    sparks: sparks,
                    color: context.colors.reward.fill,
                    mirror: mirror,
                  ),
                ),
              ),
            if (guide != null)
              PositionedDirectional(
                start: box.maxWidth - guide.centre.dx - guide.size / 2,
                top: guide.centre.dy - guide.size / 2,
                width: guide.size,
                height: guide.size,
                child: Mascot(
                  expression: guide.expression,
                  size: guide.size,
                  animate: false,
                  sparkles: false,
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Sparks, given in the right-to-left frame, mirrored in English (D1).
class SparksPainter extends CustomPainter {
  const SparksPainter({
    required this.sparks,
    required this.color,
    required this.mirror,
  });

  final List<SparkDot> sparks;
  final Color color;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    if (mirror) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final paint = Paint();
    for (final spark in sparks) {
      if (spark.opacity <= 0 || spark.radius <= 0) continue;
      paint.color = color.withValues(alpha: color.a * spark.opacity);
      canvas.drawCircle(spark.centre, spark.radius, paint);
    }
  }

  @override
  bool shouldRepaint(SparksPainter old) =>
      old.color != color || old.mirror != mirror || old.sparks != sparks;
}
