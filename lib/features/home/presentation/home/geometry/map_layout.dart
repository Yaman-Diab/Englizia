import 'dart:math' as math;

import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/path_commands.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/painting.dart';

/// Where the review box goes: above the island, at its exit, or nowhere.
enum BoxPlace { top, exit, hide }

/// The scroll home opens on, relative to the current island's top, and the
/// review box's place (map §9, the design's `anch()`): computed once on
/// open, never on scroll. The current stone, its label and the bubble stay
/// at least 12 above the tab bar and 20 under the level header.
final class MapAnchor {
  const MapAnchor({required this.box, required this.rel});

  /// [pt] is the header space above the map, [view] the scroll viewport.
  /// [bubbleHeight] is the bubble as measured (D4); 0 takes the design's
  /// reserved height. [lastLandmark]: the last stone is drawn as a lighthouse
  /// or a gate (D8), which stands taller than a stone.
  static MapAnchor compute({
    required IslandLayout island,
    required int current,
    required bool kids,
    required bool reviewBox,
    required bool reviewStation,
    required bool partial,
    required double pt,
    required double view,
    required double bubbleHeight,
    bool lastLandmark = true,
  }) {
    var box = reviewBox ? BoxPlace.top : null;
    final rest = reviewBox ? _boxTopRel : _plainRel;
    if (current >= island.n) return MapAnchor(box: box, rel: rest);

    final k = math.min(island.n - 1, math.max(0, current));
    final tall = k == island.n - 1 && !kids && !reviewStation && lastLandmark;
    final at = reviewStation
        ? island.station ?? island.stones[k]
        : island.stones[k];
    final radius = kids
        ? 40.0
        : reviewStation
        ? 27.0
        : 32.0;
    final label = kids ? 24.0 : 19.0;
    final stoneTop = tall ? at.dy - 56 : at.dy - radius;
    final stoneBottom = tall
        ? at.dy + 26 + label + 16
        : at.dy + radius + 6 + label;
    final bubble = bubbleHeight > 0
        ? bubbleHeight
        : kids
        ? 148.0
        : partial
        ? 182.0
        : 170.0;
    final top = math.min(stoneTop, island.bubbleCenterY - bubble / 2);
    final bottom = math.max(stoneBottom, island.bubbleCenterY + bubble / 2);
    (double, double) range(double t, double b) => (b + pt + 12 - view, t - 20);

    var (lo, hi) = range(top, bottom);
    if (reviewBox) {
      final (lo2, hi2) = range(math.min(top, -58), math.max(bottom, 8));
      final (lo3, hi3) = range(top, math.max(bottom, island.height + 48));
      if (lo2 <= hi2) {
        (lo, hi) = (lo2, hi2);
        box = BoxPlace.top;
      } else if (lo3 <= hi3) {
        (lo, hi) = (lo3, hi3);
        box = BoxPlace.exit;
      } else {
        box = BoxPlace.hide;
      }
    }
    if (lo > hi) return MapAnchor(box: box, rel: hi);

    final preferred = box == BoxPlace.top ? _boxTopRel : _plainRel;
    final rr = kids ? 32.0 : 24.0;
    // What must show whole or hide whole under the header: the banner, the
    // review box when it can't fit, and the rows done above the current one.
    final blocks = <({double a, double b, bool mustHide})>[
      (a: 2, b: kids ? 66 : 50, mustHide: false),
      if (box == BoxPlace.hide) (a: -58, b: 8, mustHide: true),
      for (var q = 0; q < island.rowOf(k); q++)
        (
          a: island.rowY[q] - rr,
          b: island.rowY[q] + rr + 6 + label,
          mustHide: false,
        ),
    ];
    bool fits(double v) => blocks.every(
      (block) => (!block.mustHide && block.a - v >= 8) || block.b - v <= 8,
    );
    final candidates = [
      preferred,
      lo,
      hi,
      for (final block in blocks) ...[block.a - 8, block.b - 8],
    ];
    double? best;
    for (final v in candidates) {
      if (v < lo || v > hi || !fits(v)) continue;
      if (best == null || (v - preferred).abs() < (best - preferred).abs()) {
        best = v;
      }
    }
    return MapAnchor(box: box, rel: best ?? preferred.clamp(lo, hi).toDouble());
  }

  static const _boxTopRel = -62.0;
  static const _plainRel = -10.0;

  final BoxPlace? box;

  /// The opening scroll, from the current island's top.
  final double rel;

  @override
  bool operator ==(Object other) =>
      other is MapAnchor && other.box == box && other.rel == rel;

  @override
  int get hashCode => Object.hash(box, rel);

  @override
  String toString() => 'MapAnchor($box, $rel)';
}

/// One island's place on the map. A compact island's [rect] is its 176×112
/// drawing; the current island spans the width. [right]: it sits in the
/// start column (right in right-to-left).
final class IslandSlot {
  const IslandSlot({
    required this.index,
    required this.status,
    required this.rect,
    required this.right,
  });

  final int index;
  final UnitLessonStatus status;
  final Rect rect;
  final bool right;
}

/// The bridge from island [from] to the next one (or into the horizon after
/// the last): a cubic falling straight out of one and into the other.
final class BridgeCurve {
  const BridgeCurve({
    required this.from,
    required this.p0,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.built,
  });

  final int from;
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final Offset p3;

  /// Reached: drawn in full unless a motion draws it.
  final bool built;

  /// The whole bridge.
  List<PathCommand> get whole => [MoveTo(p0), CubicTo(p1, p2, p3)];

  /// The first [t] of it, split by the curve's parameter (de Casteljau, not
  /// arc length, as the design draws it; motion §1.3).
  List<PathCommand> part(double t) {
    if (t <= 0) return const [];
    if (t >= 1) return whole;
    final a = Offset.lerp(p0, p1, t)!;
    final b = Offset.lerp(p1, p2, t)!;
    final c = Offset.lerp(p2, p3, t)!;
    final d = Offset.lerp(a, b, t)!;
    final e = Offset.lerp(b, c, t)!;
    return [MoveTo(p0), CubicTo(a, d, Offset.lerp(d, e, t)!)];
  }
}

/// The map's vertical stack: the islands from the top, the current one full
/// size, then the horizon (map §2 `geo()`, §10 bridges). Physical x of the
/// right-to-left layout across the whole width; y from the map's top.
final class MapLayout {
  const MapLayout._({
    required this.islands,
    required this.currentIndex,
    required this.horizonY,
    required this.height,
    required this.bridges,
    required this.reviewBox,
    required this.anchor,
  });

  /// [currentUnit] is the units' count when every unit is done. [ordered]:
  /// units open one after another (Emar's are all open, all bridged).
  static MapLayout compute({
    required List<UnitLessonStatus> units,
    required int currentUnit,
    required bool ordered,
    required IslandLayout? current,
    required MapAnchor anchor,
    required bool reviewBox,
    required MapFrame frame,
  }) {
    final exitBox = anchor.box == BoxPlace.exit;
    final islands = <IslandSlot>[];
    var y = 26.0;
    int? currentIndex;
    for (final (i, status) in units.indexed) {
      if (i == currentUnit && current != null) {
        if (i > 0) y += 36;
        if (reviewBox && !exitBox) y += 64;
        currentIndex = i;
        islands.add(
          IslandSlot(
            index: i,
            status: status,
            rect: Rect.fromLTWH(0, y, frame.width, current.height),
            right: i.isEven,
          ),
        );
        y += current.height + 30 + (exitBox ? 52 : 0);
      } else {
        final right = i.isEven;
        islands.add(
          IslandSlot(
            index: i,
            status: status,
            rect: Rect.fromLTWH(
              right ? frame.fromStart(196) : frame.fromEnd(20),
              y,
              compactSize.width,
              compactSize.height,
            ),
            right: right,
          ),
        );
        y += 124;
      }
    }
    final horizonY = y + 46;
    final height = horizonY + 250;

    Offset entry(IslandSlot slot) => slot.index == currentIndex
        ? Offset(current!.stones[0].dx, slot.rect.top - 4)
        : Offset(slot.rect.left + 88, slot.rect.top + 8);
    Offset leave(IslandSlot slot) => slot.index == currentIndex
        ? Offset(current!.exit.dx, slot.rect.top + current.exit.dy)
        : Offset(
            slot.right ? slot.rect.left + 16 : slot.rect.left + 160,
            slot.rect.top + 70,
          );

    final count = units.length;
    final bridges = [
      for (var k = 0; k < count; k++)
        () {
          final a = leave(islands[k]);
          final b = k < count - 1
              ? entry(islands[k + 1])
              : Offset(frame.centre, horizonY + 6);
          final dy = b.dy - a.dy;
          return BridgeCurve(
            from: k,
            p0: a,
            p1: Offset(a.dx, a.dy + dy * .55),
            p2: Offset(b.dx, b.dy - dy * .55),
            p3: b,
            built:
                (!ordered && k < count - 1) ||
                k + 1 <= currentUnit ||
                (k == count - 1 && currentUnit >= count),
          );
        }(),
    ];

    Rect? box;
    if (reviewBox && current != null && currentIndex != null) {
      final island = islands[currentIndex].rect;
      if (anchor.box == BoxPlace.top) {
        box = Rect.fromLTWH(
          frame.fromEnd(10),
          island.top - 58,
          reviewBoxSize.width,
          reviewBoxSize.height,
        );
      } else if (anchor.box == BoxPlace.exit) {
        // Opposite the exit: 10 in from the side the trail doesn't leave by.
        final exitOnEnd = current.lastStone.dx < frame.centre;
        box = Rect.fromLTWH(
          exitOnEnd
              ? frame.fromStart(10) - reviewBoxSize.width
              : frame.fromEnd(10),
          island.top + current.height - 22,
          reviewBoxSize.width,
          reviewBoxSize.height,
        );
      }
    }

    return MapLayout._(
      islands: List.unmodifiable(islands),
      currentIndex: currentIndex,
      horizonY: horizonY,
      height: height,
      bridges: List.unmodifiable(bridges),
      reviewBox: box,
      anchor: anchor,
    );
  }

  /// A compact island's drawing (0.75 of a standard 236 × 150); its button
  /// adds the labels under it, 176 × 162.
  static const compactSize = Size(176, 112);

  /// The review box as placed. ASSUMPTION(design): it is content-sized, about
  /// 68 high (D9); the anchor keeps the design's room for it.
  static const reviewBoxSize = Size(198, 68);

  final List<IslandSlot> islands;
  final int? currentIndex;

  /// Hy, the horizon band's top, and mapH, the map's height.
  final double horizonY;
  final double height;
  final List<BridgeCurve> bridges;

  /// The review box, 198 wide (map §8); null when it doesn't show.
  final Rect? reviewBox;
  final MapAnchor anchor;

  IslandSlot? get current =>
      currentIndex == null ? null : islands[currentIndex!];

  /// The scroll home opens at, with the header open: the anchor, held to
  /// the content; the bottom when no island is current.
  double initialScroll({required double pt, required double view}) {
    final most = math.max(0.0, pt + height - view);
    final island = current;
    final at = island == null ? height : island.rect.top + anchor.rel;
    return at.clamp(0.0, most).toDouble();
  }
}
