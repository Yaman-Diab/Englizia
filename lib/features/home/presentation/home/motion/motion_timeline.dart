import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How home looks at one moment of a motion: what the map and the header
/// draw instead of the data, where the guide is, and its face.
///
/// The overrides that only time a motion whose curve and keyframes the
/// drawing widget knows carry its linear progress, 0 to 1: `isleRise`,
/// `boxIn`, `levelCardIn`, `bubbleIn`, `stonePop.t`, `pulse.t`, `shakeT`,
/// `ringArcIn`, `ringGuideIn`, `guideJump`, `guideHop`, `ringSparks`,
/// `flameFlip`, `streakRoll`, `freezeGlint`. Everything else is drawn as it
/// comes, already eased: the trail's and bridges' shares, `rowT`, `tail.t`,
/// `flagUp`, `clouds`, `horizonOpen`, `saturation`, `islandGrow`,
/// `mapOpacity`, `bubbleContent`, `ringFraction`, `contentShift` (px), and
/// the `t` of `GuideHop` and `GuideOnBridge`.
typedef MotionFrame = ({
  MapOverrides map,
  HeaderOverrides header,
  GuidePlacement? guide,
  MascotExpression? expression,
});

/// The data as it is: no motion.
const MotionFrame stillFrame = (
  map: MapOverrides.none,
  header: HeaderOverrides.none,
  guide: null,
  expression: null,
);

/// What a motion does at a moment besides drawing (design "Home
/// Archipelago", motion §7–§9, §16).
enum MotionCue {
  /// The guide flies from the ring to the finished stone.
  flyToStone,

  /// The finished stone fills: a light tap and six sparks.
  fillStone,

  /// The guide flies back from the next stone to the ring.
  flyHome,

  /// Today's goal reached: a firm tap, the goal's sound, the ring's sparks.
  goal,

  /// The unit done: the pattern tap, its sound, eight sparks at the
  /// lighthouse.
  unitDone,

  /// The camera moves to the next island.
  camera,

  /// The next unit is the current one: the header folds, the map jumps to it.
  finish,

  /// The level done: the pattern tap and its sound as its card rises.
  levelDone,

  /// Kids: the guide says the new unit's name.
  kidSay,
}

typedef TimedCue = ({Duration at, MotionCue cue});

/// A motion as a pure function of time, so each of the design's beats can be
/// checked without a screen.
abstract interface class MotionTimeline {
  Duration get length;

  /// Until then the motion can't be skipped past, and home's other motion
  /// waits (no snap, no hop between ring and stone, no back button).
  Duration get busyUntil;

  List<TimedCue> get cues;

  MotionFrame frameAt(Duration t);
}

/// Milliseconds, the unit every design timing is given in.
double msOf(Duration d) =>
    d.inMicroseconds / Duration.microsecondsPerMillisecond;

/// How far a phase that starts at [start] and lasts [length] is at [ms],
/// through [curve]: 0 before it, 1 after it (the design's `fill: both`).
double phase(
  double ms,
  Duration start,
  Duration length, [
  Curve curve = AppMotion.linear,
]) {
  final span = msOf(length);
  final k = span <= 0 ? 1.0 : ((ms - msOf(start)) / span).clamp(0.0, 1.0);
  return curve.transform(k);
}

/// The value of keyframes `(offset, value)` at eased time [e], straight
/// between them; past either end the nearest pair goes on, as the web's
/// animations do with an overshooting curve.
double keyframes(double e, List<(double, double)> frames) {
  var i = 0;
  while (i < frames.length - 2 && e > frames[i + 1].$1) {
    i++;
  }
  final (a, va) = frames[i];
  final (b, vb) = frames[i + 1];
  if (b == a) return vb;
  return va + (vb - va) * (e - a) / (b - a);
}

double lerp(double a, double b, double t) => a + (b - a) * t;

/// A clock for home's motions: it runs on [vsync]'s frames (paused with the
/// page) only while something moves, and never goes back.
final class MotionClock {
  MotionClock(TickerProvider? vsync, this._onTick) {
    _ticker = vsync?.createTicker(_tick) ?? Ticker(_tick);
  }

  final VoidCallback _onTick;
  late final Ticker _ticker;
  Duration _base = Duration.zero;
  Duration _now = Duration.zero;

  Duration get now => _now;

  bool get running => _ticker.isActive;

  void start() {
    if (_ticker.isActive) return;
    _base = _now;
    _ticker.start();
  }

  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void _tick(Duration elapsed) {
    _now = _base + elapsed;
    _onTick();
  }

  void dispose() => _ticker.dispose();
}
