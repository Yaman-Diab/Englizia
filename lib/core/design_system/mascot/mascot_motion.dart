import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/foundation.dart';

/// The idle loop at one moment: float, wave and blink from the welcome
/// screen design. Pure, so it is computed per frame and tested directly.
@immutable
final class MascotFrame {
  const MascotFrame({
    this.lift = 0,
    this.shadowRadius = 42,
    this.waveAngle = 0,
    this.waveMarks = 1,
    this.eyeOpenness = 1,
    this.eyeHighlight = 1,
  });

  /// At rest: what the drawing shows when motion is reduced.
  static const still = MascotFrame();

  /// Upward float in drawing units (0 to 5).
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

  static MascotFrame at(Duration elapsed, {required bool waving}) {
    final float = _ease(_phase(elapsed, AppMotion.characterFloat));
    final blink = _phase(elapsed, AppMotion.characterBlink);
    final wave = _phase(elapsed, AppMotion.characterWave);
    return MascotFrame(
      lift: 5 * float,
      shadowRadius: 42 - 7 * float,
      waveAngle: waving ? _keys(wave, _waveTimes, _waveAngles) : 0,
      waveMarks: waving ? _keys(wave, _marksTimes, _marksValues) : 1,
      eyeOpenness: _keys(blink, _blinkTimes, _blinkValues),
      eyeHighlight: _keys(blink, _glintTimes, _glintValues),
    );
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
      other.eyeHighlight == eyeHighlight;

  @override
  int get hashCode => Object.hash(
    lift,
    shadowRadius,
    waveAngle,
    waveMarks,
    eyeOpenness,
    eyeHighlight,
  );
}
