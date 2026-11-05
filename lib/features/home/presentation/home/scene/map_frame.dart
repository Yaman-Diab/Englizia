import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The design's 360-wide frame on a screen [width] wide (D2): at most 480,
/// centred. Positions are physical x from the left of the right-to-left
/// layout; a widget is placed with `PositionedDirectional(start: startOf(…))`,
/// which mirrors in English on its own (D1).
///
/// ASSUMPTION(design): scaled x for stones, art points and the review
/// station; edge-anchored insets for turns, compact islands and cards;
/// sizes, fonts, strokes and every vertical value unscaled.
@immutable
final class MapFrame {
  MapFrame(this.width) : frame = math.min(width, maxWidth);

  /// The widest the design's frame grows.
  static const maxWidth = 480.0;

  /// The design's own width.
  static const designWidth = 360.0;

  final double width;
  final double frame;

  /// Where the frame starts, from the screen's left.
  double get left => (width - frame) / 2;

  double get sx => frame / designWidth;

  /// A design x, scaled with the frame.
  double scaled(double designX) => left + designX * sx;

  /// [inset] from the frame's left edge: its end in right-to-left.
  double fromEnd(double inset) => left + inset;

  /// [inset] from the frame's right edge: its start in right-to-left.
  double fromStart(double inset) => left + frame - inset;

  double get centre => left + frame / 2;

  /// [rect]'s `start` for `PositionedDirectional`.
  double startOf(Rect rect) => width - rect.right;

  @override
  bool operator ==(Object other) => other is MapFrame && other.width == width;

  @override
  int get hashCode => width.hashCode;
}
