import 'dart:math' as math;
import 'dart:ui';

/// CSS `color-mix(in oklab, a aShare, b)`: [aShare] of [a], the rest of [b],
/// premultiplied by alpha as CSS does. The designs derive their tints this
/// way, so a mix computed here matches what the board renders.
Color mixOklab(Color a, Color b, double aShare) {
  final x = _Oklab.of(a);
  final y = _Oklab.of(b);
  final share = aShare.clamp(0.0, 1.0);
  final alpha = _lerp(y.alpha, x.alpha, share);
  if (alpha <= 0) return const Color(0x00000000);
  double mix(double p, double q) =>
      _lerp(q * y.alpha, p * x.alpha, share) / alpha;
  return _Oklab(mix(x.l, y.l), mix(x.a, y.a), mix(x.b, y.b), alpha).toColor();
}

/// CSS `color-mix(in oklch, a aShare, b)`, the hue by the shorter way round.
/// A grey (white, black) has no hue of its own and takes the other's.
Color mixOklch(Color a, Color b, double aShare) {
  final x = _Oklab.of(a);
  final y = _Oklab.of(b);
  final share = aShare.clamp(0.0, 1.0);
  final alpha = _lerp(y.alpha, x.alpha, share);
  if (alpha <= 0) return const Color(0x00000000);
  final xc = x.chroma;
  final yc = y.chroma;
  var xh = xc < _grey ? null : x.hue;
  var yh = yc < _grey ? null : y.hue;
  xh ??= yh ?? 0;
  yh ??= xh;
  final turn = yh - xh;
  if (turn > 180) {
    xh += 360;
  } else if (turn < -180) {
    yh += 360;
  }
  double mix(double p, double q) =>
      _lerp(q * y.alpha, p * x.alpha, share) / alpha;
  final l = mix(x.l, y.l);
  final c = mix(xc, yc);
  final h = _lerp(yh, xh, share) * math.pi / 180;
  return _Oklab(l, c * math.cos(h), c * math.sin(h), alpha).toColor();
}

/// Below this chroma a colour counts as grey: its hue is powerless.
const _grey = 1e-4;

double _lerp(double from, double to, double t) => from + (to - from) * t;

final class _Oklab {
  const _Oklab(this.l, this.a, this.b, this.alpha);

  factory _Oklab.of(Color color) {
    final r = _linear(color.r);
    final g = _linear(color.g);
    final b = _linear(color.b);
    final l = math.pow(
      0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
      1 / 3,
    );
    final m = math.pow(
      0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
      1 / 3,
    );
    final s = math.pow(
      0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
      1 / 3,
    );
    return _Oklab(
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
      color.a,
    );
  }

  final double l;
  final double a;
  final double b;
  final double alpha;

  double get chroma => math.sqrt(a * a + b * b);

  /// In degrees, 0 to 360.
  double get hue => (math.atan2(b, a) * 180 / math.pi + 360) % 360;

  Color toColor() {
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    final l3 = l_ * l_ * l_;
    final m3 = m_ * m_ * m_;
    final s3 = s_ * s_ * s_;
    return Color.from(
      alpha: alpha.clamp(0.0, 1.0),
      red: _gamma(4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3),
      green: _gamma(-1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3),
      blue: _gamma(-0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3),
    );
  }

  static double _linear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  /// Back to sRGB, clipped to its gamut as browsers show it.
  static double _gamma(double channel) {
    final value = channel <= 0.0031308
        ? 12.92 * channel
        : 1.055 * math.pow(channel, 1 / 2.4) - 0.055;
    return value.clamp(0.0, 1.0);
  }
}
