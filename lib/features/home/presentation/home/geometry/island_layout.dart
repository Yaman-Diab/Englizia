import 'dart:math' as math;

import 'package:englizia/features/home/presentation/home/geometry/path_commands.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:flutter/painting.dart';

/// The bubble's side towards its stone, in the layout's physical space.
enum TailSide { top, bottom, left, right }

/// Where the lesson bubble sits across the island, in the
/// right-to-left layout's physical x.
final class BubbleFrame {
  const BubbleFrame({
    required this.x0,
    required this.x1,
    required this.tailX,
    required this.side,
  });

  /// The bubble's physical left and right edges.
  final double x0;
  final double x1;

  /// The 18-px tail square's left edge, from [x0] (the design's `tx`); 0 for
  /// a tail on the left or right side.
  final double tailX;
  final TailSide side;

  double get width => x1 - x0;

  @override
  bool operator ==(Object other) =>
      other is BubbleFrame &&
      other.x0 == x0 &&
      other.x1 == x1 &&
      other.tailX == tailX &&
      other.side == side;

  @override
  int get hashCode => Object.hash(x0, x1, tailX, side);

  @override
  String toString() => 'BubbleFrame($x0, $x1, tail $tailX $side)';
}

/// The current island's rows of stones, its trail and its bubble gap (design
/// "Home Archipelago" `lay()`). Rows hold up to three stones and snake from the
/// right; one big gap holds the bubble, before the current row (after it when
/// that is the first). x is the right-to-left layout's physical x across the
/// whole width ([MapFrame]), y the island's own.
final class IslandLayout {
  const IslandLayout._({
    required this.frame,
    required this.kids,
    required this.n,
    required this.rows,
    required this.clear,
    required this.bubbleRow,
    required this.sizes,
    required this.starts,
    required this.rowY,
    required this.stones,
    required this.height,
    required this.bubbleCenterY,
    required this.bubbleOpacity,
    required this.segments,
    required this.exit,
    required this.station,
    required this.tufts,
    required this.banner,
    required this.bannerRoom,
  });

  /// The layout for [lessons] stones, [current] the one to do now (the
  /// count once all are done). While the rows move (09ب), [rowFrom] is the
  /// old gap's row and [rowT] how far they have moved, already eased.
  /// [reviewStation] adds the review station before the current stone;
  /// [gapExtra] widens the bubble's gap for a bubble taller than the design's.
  factory IslandLayout.compute({
    required int lessons,
    required int current,
    required bool kids,
    required MapFrame frame,
    int? rowFrom,
    double rowT = 1,
    bool reviewStation = false,
    double gapExtra = 0,
  }) {
    final n = math.max(1, lessons);
    final rows = (n / 3).ceil();
    final base = n ~/ rows;
    final extra = n % rows;
    final sizes = [for (var r = 0; r < rows; r++) base + (r < extra ? 1 : 0)];
    final starts = <int>[];
    var count = 0;
    for (final size in sizes) {
      starts.add(count);
      count += size;
    }
    int rowOf(int i) {
      for (var r = rows - 1; r >= 0; r--) {
        if (i >= starts[r]) return r;
      }
      return 0;
    }

    final y0 = kids ? 94.0 : 78.0;
    final step = kids ? 110.0 : 96.0;
    final gap = (kids ? 266.0 : 276.0) + math.max(0, gapExtra);
    final above = kids ? 66.0 : 62.0;
    final below = kids ? 50.0 : 44.0;
    final tail = kids ? 100.0 : 86.0;

    final cc = math.min(n - 1, math.max(0, current));
    final currentRow = rowOf(cc);
    // ASSUMPTION(design): one row (≤ 3 lessons) keeps a virtual gap after it,
    // so the bubble has its room; the prototype has none.
    final clear = rows == 1 ? 0 : math.max(0, currentRow - 1);

    List<double> rowsWithGapAfter(int gapRow) {
      final y = [y0];
      for (var r = 1; r < rows; r++) {
        y.add(y[r - 1] + (r - 1 == gapRow ? gap : step));
      }
      return y;
    }

    double centreOf(List<double> y, int gapRow) {
      final c0 = math.max(0, gapRow);
      final next = c0 + 1 < y.length ? y[c0 + 1] : y[c0] + gap;
      return (y[c0] + above + next - below) / 2;
    }

    final from = rows > 1 && rowFrom != null
        ? rowFrom.clamp(0, rows - 2)
        : null;
    final moving = from != null && from != clear ? from : null;
    final t = moving == null ? 1.0 : rowT.clamp(0.0, 1.0).toDouble();
    final target = rowsWithGapAfter(clear);
    final start = moving == null ? target : rowsWithGapAfter(moving);
    final rowY = [
      for (var r = 0; r < rows; r++) start[r] + (target[r] - start[r]) * t,
    ];
    final centreFrom = centreOf(start, moving ?? clear);
    final bubbleCenterY =
        centreFrom + (centreOf(target, clear) - centreFrom) * t;
    final bubbleRow = moving != null && t < .5 ? moving : clear;
    final bubbleOpacity = moving == null
        ? 1.0
        : t < .5
        ? math.max(0.0, 1 - 4 * t)
        : math.max(0.0, 4 * t - 3);

    const columns = {
      3: [312.0, 196.0, 80.0],
      2: [292.0, 100.0],
      1: [196.0],
    };
    final stones = <Offset>[
      for (var r = 0; r < rows; r++)
        for (final x
            in r.isOdd ? columns[sizes[r]]!.reversed : columns[sizes[r]]!)
          Offset(frame.scaled(x), rowY[r]),
    ];
    final height = rows == 1 ? y0 + gap - 10 : rowY[rows - 1] + tail;

    // The row turns run down the island's edge: the end side after an even
    // row, the start side after an odd one.
    double turnX(int row) =>
        row.isOdd ? frame.fromStart(_edge) : frame.fromEnd(_edge);

    final first = stones[0];
    final last = stones[n - 1];
    final segments = <List<PathCommand>>[
      [
        MoveTo(Offset(first.dx, -4)),
        CubicTo(
          Offset(first.dx, 20),
          Offset(first.dx, 40),
          Offset(first.dx, first.dy - 24),
        ),
      ],
      for (var i = 1; i < n; i++)
        _between(stones[i - 1], stones[i], rowOf(i - 1), rowOf(i), turnX),
      [
        MoveTo(last),
        CubicTo(
          Offset(last.dx, last.dy + 30),
          Offset(last.dx, height - 30),
          Offset(last.dx, height - 6),
        ),
      ],
    ];

    Offset? station;
    if (reviewStation) {
      // ASSUMPTION(design): when the current stone does not start its row,
      // the station falls back to the stone before it.
      final row = starts.indexOf(cc);
      station = row > 0
          ? Offset(turnX(row - 1), (rowY[row - 1] + rowY[row]) / 2)
          : stones[math.max(0, cc - 1)];
    }

    final bannerStart = frame.scaled(kids ? 64 : 104);
    final bannerEnd = frame.fromStart(20);
    return IslandLayout._(
      frame: frame,
      kids: kids,
      n: n,
      rows: rows,
      clear: clear,
      bubbleRow: bubbleRow,
      sizes: List.unmodifiable(sizes),
      starts: List.unmodifiable(starts),
      rowY: List.unmodifiable(rowY),
      stones: List.unmodifiable(stones),
      height: height,
      bubbleCenterY: bubbleCenterY,
      bubbleOpacity: bubbleOpacity,
      segments: List.unmodifiable(segments),
      exit: Offset(last.dx, height - 6),
      station: station,
      tufts: List.unmodifiable([
        for (final (x, y) in [
          (44.0, height * .4),
          (332.0, height * .38),
          (244.0, height * .57),
          (118.0, height - 36),
          (214.0, height - 30),
          (336.0, height * .66),
          (100.0, height * .45),
        ])
          Offset(frame.scaled(x), y),
      ]),
      banner: kids
          ? Rect.fromLTRB(bannerStart, 2, bannerEnd, 66)
          : Rect.fromLTWH(
              bannerStart,
              2,
              math.min(236, bannerEnd - bannerStart),
              48,
            ),
      bannerRoom: Rect.fromLTRB(
        frame.fromEnd(bannerReach),
        2,
        bannerEnd,
        kids ? 66 : 50,
      ),
    );
  }

  /// The trail's inset from the island's side where it turns to the next row.
  static const _edge = 26.0;

  /// How far the parked guide stands from its stone, towards the middle, and
  /// above it.
  static const _spotAcross = 58.0;
  static const _spotUp = 8.0;

  final MapFrame frame;
  final bool kids;

  /// The stones (lessons) and the rows they snake through.
  final int n;
  final int rows;

  /// The bubble's gap follows this row.
  final int clear;

  /// The row the bubble's gap follows as drawn (bc0): the old one during the
  /// first half of a row move.
  final int bubbleRow;
  final List<int> sizes;

  /// The first stone of each row.
  final List<int> starts;
  final List<double> rowY;

  /// Each stone's centre.
  final List<Offset> stones;
  final double height;

  /// The bubble's vertical centre, and how much of it shows while rows move.
  final double bubbleCenterY;
  final double bubbleOpacity;

  /// n + 1 pieces of the trail: in from the top, between each two stones,
  /// out from the last one.
  final List<List<PathCommand>> segments;

  /// Where the trail leaves the island, towards the next bridge.
  final Offset exit;

  /// The review station on the trail before the current stone, when the
  /// review comes first.
  final Offset? station;

  /// Where the grass tufts stand.
  final List<Offset> tufts;

  /// The island's banner box: its left edge is the end inset, its width the
  /// most it may take.
  final Rect banner;

  /// Where the banner may reach: [banner] and on to [bannerReach] from the
  /// frame's end, for Emar's book line where the design's width would cut
  /// it (IslandBanner).
  final Rect bannerRoom;

  /// The nearest the banner comes to the frame's end edge.
  static const bannerReach = 20.0;

  /// The last stone, which may be drawn as a lighthouse or a gate.
  Offset get lastStone => stones[n - 1];

  int rowOf(int i) {
    for (var r = rows - 1; r >= 0; r--) {
      if (i >= starts[r]) return r;
    }
    return 0;
  }

  /// Where the guide parks beside stone [k], its centre: 58 towards the
  /// island's middle and 8 up; -1 is the review station.
  Offset spot(int k) {
    final at = k < 0 ? station ?? stones[0] : stones[k.clamp(0, n - 1)];
    return Offset(
      at.dx + (at.dx > frame.centre ? -_spotAcross : _spotAcross),
      at.dy - _spotUp,
    );
  }

  /// The bubble's edges and tail: across the island, inset on the side the
  /// trail turns, its tail on the edge towards [targetRow]'s stone at
  /// [targetX]; with [reviewFirst], narrower and pointing at the station.
  BubbleFrame bubbleFrame({
    required bool reviewFirst,
    required double targetX,
    required int targetRow,
  }) {
    final c0 = math.max(0, bubbleRow);
    final even = c0.isEven;
    var x0 = frame.fromEnd(even ? 46 : 20);
    var x1 = frame.fromStart(even ? 20 : 46);
    if (reviewFirst) {
      if (even) {
        x0 = frame.fromEnd(70);
      } else {
        x1 = frame.fromStart(70);
      }
      return BubbleFrame(
        x0: x0,
        x1: x1,
        tailX: 0,
        side: even ? TailSide.left : TailSide.right,
      );
    }
    final tailX = targetX.clamp(x0 + 30, x1 - 30) - x0 - 9;
    return BubbleFrame(
      x0: x0,
      x1: x1,
      tailX: tailX,
      side: targetRow <= c0 ? TailSide.top : TailSide.bottom,
    );
  }

  static List<PathCommand> _between(
    Offset a,
    Offset b,
    int rowA,
    int rowB,
    double Function(int row) turnX,
  ) {
    if (rowA == rowB) {
      final run = b.dx - a.dx;
      return [
        MoveTo(a),
        CubicTo(
          Offset(a.dx + run * .35, a.dy - 20),
          Offset(b.dx - run * .35, b.dy + 22),
          b,
        ),
      ];
    }
    final e = turnX(rowA);
    final drop = b.dy - a.dy;
    if (drop >= 180) {
      return [
        MoveTo(a),
        CubicTo(
          Offset(e, a.dy + 14),
          Offset(e, a.dy + 56),
          Offset(e, a.dy + 90),
        ),
        LineTo(Offset(e, b.dy - 90)),
        CubicTo(Offset(e, b.dy - 56), Offset(e, b.dy - 14), b),
      ];
    }
    // ASSUMPTION(design): across a normal row step the design's turn would
    // double back on itself, so it meets at the middle instead.
    final middle = (a.dy + b.dy) / 2;
    return [
      MoveTo(a),
      CubicTo(
        Offset(e, a.dy + 14),
        Offset(e, a.dy + .3 * drop),
        Offset(e, middle),
      ),
      CubicTo(Offset(e, b.dy - .3 * drop), Offset(e, b.dy - 14), b),
    ];
  }
}
