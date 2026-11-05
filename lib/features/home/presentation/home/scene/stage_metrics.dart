import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Where home's floating header stands (design "Home Archipelago", header
/// §5): the day header [head] high folds by [collapse] as the map scrolls,
/// the ring shrinks to the top bar, and the stage drops by [pull] while
/// pulled. Coordinates are the right-to-left layout's physical ones, y 0 at
/// the top of the top bar.
@immutable
final class StageMetrics {
  const StageMetrics({
    required this.width,
    required this.height,
    required this.head,
    required this.topSlot,
    required this.collapse,
    required this.scroll,
    required this.pull,
    required this.kids,
  });

  static const topBar = 56.0;
  static const levelHeader = 40.0;
  static const shoreEdge = 8.0;
  static const ringBox = 96.0;
  static const ringMin = 28.0;

  final double width;

  /// Below the safe area, above the tab bar.
  final double height;

  /// The day header as measured (D3).
  final double head;

  /// The strip under the top bar (email, offline, refresh failed).
  final double topSlot;
  final double collapse;
  final double scroll;
  final double pull;
  final bool kids;

  /// Where the map's own content starts.
  double get pt => head + levelHeader;

  /// The map's viewport, under the top bar.
  double get view => height - topBar;

  /// How far the header has folded, 0 to 1.
  double get progress =>
      head <= 0 ? 0 : (collapse / head).clamp(0.0, 1.0).toDouble();

  double get greetingOpacity => math.max(0.0, 1 - 1.8 * progress);

  bool get collapsed => progress > .5;

  /// The top bar's divider shows once the header is all folded.
  bool get dividerOn => collapse >= head - 1;

  bool get sayBubbleAllowed => collapse < 20;

  double get ringScale => 1 - (1 - ringMin / ringBox) * progress;

  double get ringTop =>
      (1 - progress) * (topBar + topSlot - collapse + pull) + progress * 14;

  /// From the layout's left: the ring's start in right-to-left.
  double get ringLeft => 20;

  Offset get ringCenter =>
      Offset(ringLeft + 48 * ringScale, ringTop + 48 * ringScale);

  double get ringGuideSize => 64 * ringScale;

  /// A point of the map (y from the map's top) on the stage.
  Offset toMain(Offset mapPoint) =>
      Offset(mapPoint.dx, topBar + pull + pt + mapPoint.dy - scroll);

  /// The back-to-lesson button's centre, at the bottom of the end side.
  Offset get backButtonCentre =>
      Offset(18 + (kids ? 32 : 28), height - 20 - (kids ? 32 : 28));

  StageMetrics copyWith({
    double? width,
    double? height,
    double? head,
    double? topSlot,
    double? collapse,
    double? scroll,
    double? pull,
    bool? kids,
  }) => StageMetrics(
    width: width ?? this.width,
    height: height ?? this.height,
    head: head ?? this.head,
    topSlot: topSlot ?? this.topSlot,
    collapse: collapse ?? this.collapse,
    scroll: scroll ?? this.scroll,
    pull: pull ?? this.pull,
    kids: kids ?? this.kids,
  );

  @override
  bool operator ==(Object other) =>
      other is StageMetrics &&
      other.width == width &&
      other.height == height &&
      other.head == head &&
      other.topSlot == topSlot &&
      other.collapse == collapse &&
      other.scroll == scroll &&
      other.pull == pull &&
      other.kids == kids;

  @override
  int get hashCode =>
      Object.hash(width, height, head, topSlot, collapse, scroll, pull, kids);
}
