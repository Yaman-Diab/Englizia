import 'dart:math' as math;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/foundation.dart';

/// How an expression idles: how high and how fast it floats, how much the
/// whole figure sways, how far the gesturing (right) arm swings, and how
/// much it stretches at the top of a float and squashes at the bottom.
/// Calm expressions drift; lively ones bounce.
@immutable
final class MascotIdle {
  const MascotIdle({
    this.lift = 5,
    this.period = AppMotion.characterFloat,
    this.sway = 0,
    this.swing = 0,
    this.stretch = .012,
  });

  /// The welcome screen's float.
  static const standard = MascotIdle();

  /// Float height in drawing units.
  final double lift;

  /// One float cycle.
  final Duration period;

  /// Degrees the figure rocks either way over one float.
  final double sway;

  /// Degrees the right arm swings at the top of a float (negative raises).
  final double swing;

  /// Height change at the top and bottom of a float, as a fraction.
  final double stretch;

  /// Blends the amounts of [a] and [b]; the period is [b]'s.
  static MascotIdle lerp(MascotIdle a, MascotIdle b, double t) => MascotIdle(
    lift: _lerp(a.lift, b.lift, t),
    period: b.period,
    sway: _lerp(a.sway, b.sway, t),
    swing: _lerp(a.swing, b.swing, t),
    stretch: _lerp(a.stretch, b.stretch, t),
  );

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) =>
      other is MascotIdle &&
      other.lift == lift &&
      other.period == period &&
      other.sway == sway &&
      other.swing == swing &&
      other.stretch == stretch;

  @override
  int get hashCode => Object.hash(lift, period, sway, swing, stretch);
}

/// The idle loop at one moment: float, sway, arm swing, blink and the
/// expression's small loops. Pure, so it is computed per frame and tested
/// directly.
@immutable
final class MascotFrame {
  const MascotFrame({
    this.lift = 0,
    this.shadowRadius = 42,
    this.waveAngle = 0,
    this.waveMarks = 1,
    this.eyeOpenness = 1,
    this.eyeHighlight = 1,
    this.sway = 0,
    this.swing = 0,
    this.stretch = 0,
    this.pulse,
  });

  /// At rest: what the drawing shows when motion is reduced.
  static const still = MascotFrame();

  /// Upward float in drawing units.
  final double lift;

  /// Horizontal radius of the ground shadow; shrinks as the figure rises.
  final double shadowRadius;

  /// Right-arm rotation in degrees around the shoulder.
  final double waveAngle;

  /// Opacity of the wave marks beside the waving hand.
  final double waveMarks;

  /// 1 = open, ~0.1 = shut, for round and looking eyes.
  final double eyeOpenness;
  final double eyeHighlight;

  /// Extra tilt of the whole figure, in degrees.
  final double sway;

  /// Extra right-arm rotation from the expression's gesture, in degrees.
  final double swing;

  /// Height change of the figure, as a fraction (negative squashes).
  final double stretch;

  /// Position in the [AppMotion.characterPulse] cycle, 0–1; null when the
  /// small loops rest (talking dots full, sparkles at full size).
  final double? pulse;

  static MascotFrame at(
    Duration elapsed, {
    required bool waving,
    MascotIdle idle = MascotIdle.standard,
    double? floatPhase,
  }) {
    final cycle = floatPhase ?? _phase(elapsed, idle.period);
    final float = _ease(cycle % 1);
    final blink = _phase(elapsed, AppMotion.characterBlink);
    final wave = _phase(elapsed, AppMotion.characterWave);
    return MascotFrame(
      lift: idle.lift * float,
      shadowRadius: 42 - 1.4 * idle.lift * float,
      waveAngle: waving ? _keys(wave, _waveTimes, _waveAngles) : 0,
      waveMarks: waving ? _keys(wave, _marksTimes, _marksValues) : 1,
      eyeOpenness: _keys(blink, _blinkTimes, _blinkValues),
      eyeHighlight: _keys(blink, _glintTimes, _glintValues),
      sway: idle.sway * math.sin(2 * math.pi * cycle),
      swing: idle.swing * float,
      stretch: idle.stretch * (2 * float - 1),
      pulse: _phase(elapsed, AppMotion.characterPulse),
    );
  }

  /// 0 → 1 → 0 around [center] of a 0–1 cycle, [width] wide, smooth at the
  /// edges; wraps around the cycle. For staggered loops (dot i at i × 0.2).
  static double bump(double t, {required double center, double width = .5}) {
    var d = (t - center).abs() % 1;
    if (d > .5) d = 1 - d;
    if (d >= width / 2) return 0;
    return .5 + .5 * math.cos(math.pi * d / (width / 2));
  }

  static double _phase(Duration elapsed, Duration period) =>
      (elapsed.inMicroseconds % period.inMicroseconds) / period.inMicroseconds;

  /// Up on the first half, down on the second, eased like the design.
  static double _ease(double t) => t < .5
      ? AppMotion.float.transform(t * 2)
      : 1 - AppMotion.float.transform(t * 2 - 1);

  static double _keys(double t, List<double> times, List<double> values) {
    for (var i = 1; i < times.length; i++) {
      if (t <= times[i]) {
        final span = times[i] - times[i - 1];
        final local = span == 0 ? 1.0 : (t - times[i - 1]) / span;
        return values[i - 1] + (values[i] - values[i - 1]) * local;
      }
    }
    return values.last;
  }

  // Keyframes from the welcome screen design (SMIL timings, fractions of a cycle).
  static const _waveTimes = <double>[0, .11, .22, .33, .44, .55, 1];
  static const _waveAngles = <double>[0, -22, 6, -22, 6, 0, 0];
  static const _marksTimes = <double>[0, .08, .45, .58, 1];
  static const _marksValues = <double>[0, 1, 1, 0, 0];
  static const _blinkTimes = <double>[0, .9, .94, .98, 1];
  static const _blinkValues = <double>[1, 1, .11, 1, 1];
  static const _glintTimes = <double>[0, .9, .93, .98, 1];
  static const _glintValues = <double>[1, 1, 0, 1, 1];

  @override
  bool operator ==(Object other) =>
      other is MascotFrame &&
      other.lift == lift &&
      other.shadowRadius == shadowRadius &&
      other.waveAngle == waveAngle &&
      other.waveMarks == waveMarks &&
      other.eyeOpenness == eyeOpenness &&
      other.eyeHighlight == eyeHighlight &&
      other.sway == sway &&
      other.swing == swing &&
      other.stretch == stretch &&
      other.pulse == pulse;

  @override
  int get hashCode => Object.hash(
    lift,
    shadowRadius,
    waveAngle,
    waveMarks,
    eyeOpenness,
    eyeHighlight,
    sway,
    swing,
    stretch,
    pulse,
  );
}
