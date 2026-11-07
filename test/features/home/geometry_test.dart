import 'dart:ui';

import 'package:englizia/core/design_system/sea/island_blob.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/path_commands.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// The numbers of an SVG path, in order, with its command letters.
List<Object> _tokens(String svg) => [
  for (final match in RegExp(
    r'[MLCZ]|-?\d*\.?\d+',
  ).allMatches(svg.replaceAll(',', ' ')))
    switch (match[0]!) {
      final letter when RegExp('[MLCZ]').hasMatch(letter) => letter,
      final number => double.parse(number),
    },
];

/// [actual] is the SVG path [expected], each number within [tolerance].
void _expectPath(String actual, String expected, {double tolerance = .051}) {
  final a = _tokens(actual);
  final e = _tokens(expected);
  expect(a.length, e.length, reason: '$actual\nvs\n$expected');
  for (var i = 0; i < a.length; i++) {
    if (e[i] is String) {
      expect(a[i], e[i], reason: 'token $i of $actual');
    } else {
      expect(
        a[i] as double,
        closeTo(e[i] as double, tolerance),
        reason: 'token $i of $actual\nvs\n$expected',
      );
    }
  }
}

String _blobSvg(List<Offset> points) {
  String n(double v) => v.toStringAsFixed(1);
  final out = StringBuffer('M${n(points[0].dx)} ${n(points[0].dy)}');
  for (var i = 1; i + 2 < points.length; i += 3) {
    out.write(
      'C${n(points[i].dx)} ${n(points[i].dy)} '
      '${n(points[i + 1].dx)} ${n(points[i + 1].dy)} '
      '${n(points[i + 2].dx)} ${n(points[i + 2].dy)}',
    );
  }
  return '${out}Z';
}

void main() {
  final design = MapFrame(360);

  group('island blob (map §4.2)', () {
    test('the jitter of seeds 7 and 113', () {
      const seed7 = [
        0.9981,
        1.0122,
        0.9231,
        0.9488,
        0.9886,
        1.0013,
        0.9157,
        1.0758,
        1.0179,
        0.9822,
      ];
      const seed113 = [
        1.0433,
        0.9334,
        0.9883,
        0.9073,
        1.0491,
        0.9427,
        0.932,
        0.9532,
        1.0467,
        1.0006,
      ];
      final seven = blobJitter(7);
      final big = blobJitter(113);
      for (var i = 0; i < 10; i++) {
        expect(seven[i], closeTo(seed7[i], .00006));
        expect(big[i], closeTo(seed113[i], .00006));
      }
    });

    test('the current island and a compact island grass, as drawn', () {
      _expectPath(
        _blobSvg(islandBlobPoints(180, 206, 164, 202, 113)),
        'M351.1 206.0C349.6 244.3 324.0 285.2 303.8 316.8C283.7 348.5 258.4 '
        '385.3 230.1 395.9C201.8 406.4 165.6 391.2 134.0 380.3C102.5 369.4 '
        '58.9 359.6 40.8 330.6C22.7 301.5 22.8 245.2 25.4 206.0C28.0 166.8 '
        '38.6 125.9 56.3 95.3C74.1 64.8 102.2 37.9 131.7 22.9C161.1 7.8 '
        '202.9 -5.8 233.0 4.9C263.2 15.6 293.1 53.7 312.8 87.2C332.4 120.7 '
        '352.6 167.7 351.1 206.0Z',
        tolerance: .1,
      );
      _expectPath(
        _blobSvg(islandBlobPoints(88, 50, 78, 40, 7)),
        'M165.9 50.0C166.2 57.8 161.1 67.9 151.9 73.8C142.6 79.7 124.7 83.1 '
        '110.2 85.1C95.8 87.2 79.2 88.1 65.1 86.1C51.0 84.1 34.8 79.3 25.6 '
        '73.2C16.4 67.2 9.1 57.5 9.9 50.0C10.7 42.5 21.5 35.3 30.2 28.5C38.9 '
        '21.6 48.4 11.9 62.1 9.1C75.8 6.2 97.9 8.3 112.5 11.3C127.2 14.2 '
        '141.1 20.5 150.0 26.9C158.9 33.4 165.5 42.2 165.9 50.0Z',
        tolerance: .1,
      );
    });

    test('islandBlob builds a closed path over the points', () {
      final bounds = islandBlob(88, 50, 78, 40, 7).getBounds();
      expect(bounds.left, closeTo(9.1, .6));
      expect(bounds.right, closeTo(166.2, .6));
    });
  });

  group('island layout (map §3, plan §11)', () {
    IslandLayout lay(
      int n,
      int cur, {
      bool kids = false,
      MapFrame? frame,
      int? rowFrom,
      double rowT = 1,
      bool station = false,
    }) => IslandLayout.compute(
      lessons: n,
      current: cur,
      kids: kids,
      frame: frame ?? design,
      rowFrom: rowFrom,
      rowT: rowT,
      reviewStation: station,
    );

    List<(double, double)> points(IslandLayout l) => [
      for (final p in l.stones) (p.dx, p.dy),
    ];

    test('4 lessons, two rows of two', () {
      final l = lay(4, 2);
      expect(l.sizes, [2, 2]);
      expect(l.clear, 0);
      expect(l.rowY, [78, 354]);
      expect(l.height, 440);
      expect(l.bubbleCenterY, 225);
      expect(points(l), [(292, 78), (100, 78), (100, 354), (292, 354)]);
    });

    test('6 lessons, the default island', () {
      final l = lay(6, 3);
      expect(l.rows, 2);
      expect(l.sizes, [3, 3]);
      expect(l.starts, [0, 3]);
      expect(l.rowY, [78, 354]);
      expect(l.height, 440);
      expect(l.bubbleCenterY, 225);
      expect(points(l), [
        (312, 78),
        (196, 78),
        (80, 78),
        (80, 354),
        (196, 354),
        (312, 354),
      ]);
      expect(l.exit, const Offset(312, 434));
    });

    test('8 lessons put the bubble before the current row', () {
      final l = lay(8, 4);
      expect(l.sizes, [3, 3, 2]);
      expect(l.clear, 0);
      expect(l.rowY, [78, 354, 450]);
      expect(l.height, 536);
      expect(l.bubbleCenterY, 225);
      expect(points(l).sublist(6), [(292, 450), (100, 450)]);
    });

    test('8 lessons, the rows move when the current goes to row 2 (09ب)', () {
      final before = lay(8, 5);
      final after = lay(8, 6);
      expect(before.rowY, [78, 354, 450]);
      expect(after.rowY, [78, 174, 450]);
      expect(after.clear, 1);
      expect(before.bubbleCenterY, 225);
      expect(after.bubbleCenterY, 321);
      expect(after.height, before.height);

      final mid = lay(8, 6, rowFrom: 0, rowT: .4);
      expect(mid.rowY[1], closeTo(354 + (174 - 354) * .4, 1e-9));
      expect(mid.rowY[2], 450);
      expect(mid.bubbleCenterY, closeTo(225 + 96 * .4, 1e-9));
      expect(mid.bubbleRow, 0);
      expect(lay(8, 6, rowFrom: 0, rowT: .6).bubbleRow, 1);
      expect(mid.bubbleOpacity, 0);
      expect(lay(8, 6, rowFrom: 0, rowT: .1).bubbleOpacity, closeTo(.6, 1e-9));
      expect(lay(8, 6, rowFrom: 0, rowT: .2).bubbleRow, 0);
      expect(lay(8, 6, rowFrom: 0, rowT: .9).bubbleOpacity, closeTo(.6, 1e-9));
      expect(lay(8, 6, rowFrom: 1, rowT: .4).bubbleOpacity, 1);
    });

    test('10 lessons', () {
      final l = lay(10, 8);
      expect(l.sizes, [3, 3, 2, 2]);
      expect(l.clear, 2);
      expect(l.rowY, [78, 174, 270, 546]);
      expect(l.height, 632);
      expect(l.bubbleCenterY, 417);
      expect(points(l).sublist(6), [
        (292, 270),
        (100, 270),
        (100, 546),
        (292, 546),
      ]);
    });

    test('kids, 6 lessons', () {
      final l = lay(6, 3, kids: true);
      expect(l.rowY, [94, 360]);
      expect(l.height, 460);
      expect(l.bubbleCenterY, 235);
      expect(points(l).first, (312, 94));
    });

    test('one row keeps a virtual gap (D5)', () {
      final l = lay(3, 1);
      expect(l.rows, 1);
      expect(l.rowY, [78]);
      expect(l.height, 344);
      expect(l.bubbleCenterY, 225);
      expect(points(l), [(312, 78), (196, 78), (80, 78)]);
      final kids = lay(2, 0, kids: true);
      expect(kids.height, 350);
      expect(kids.bubbleCenterY, 235);
      expect(points(lay(1, 0)), [(196, 78)]);
    });

    test('a taller bubble widens its gap (D4)', () {
      final l = IslandLayout.compute(
        lessons: 6,
        current: 3,
        kids: false,
        frame: design,
        gapExtra: 20,
      );
      expect(l.rowY, [78, 374]);
      expect(l.height, 460);
      expect(l.bubbleCenterY, 235);
    });

    test('the default trail, exactly (map §3.7)', () {
      final segments = [for (final s in lay(6, 3).segments) svgOf(s)];
      const expected = [
        'M312 -4C312 20 312 40 312 54',
        'M312 78C271.4 58 236.6 100 196 78',
        'M196 78C155.4 58 120.6 100 80 78',
        'M80 78C26 92 26 134 26 168L26 264C26 298 26 340 80 354',
        'M80 354C120.6 334 155.4 376 196 354',
        'M196 354C236.6 334 271.4 376 312 354',
        'M312 354C312 384 312 410 312 434',
      ];
      expect(segments.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        _expectPath(segments[i], expected[i]);
      }
    });

    test('a row turn across a normal step meets at the middle (D6)', () {
      // 10 lessons: rows 0 → 1 are 96 apart.
      final turn = svgOf(lay(10, 8).segments[3]);
      _expectPath(turn, 'M80 78C26 92 26 106.8 26 126C26 145.2 26 160 80 174');
    });

    test('row turns run on the side the row ends', () {
      final l = lay(10, 0);
      final firstTurn = l.segments[3].whereType<CubicTo>().first.end.dx;
      final secondTurn = l.segments[6].whereType<CubicTo>().first.end.dx;
      expect(firstTurn, 26);
      expect(secondTurn, 334);
    });

    test('the review station sits on the turn before the current stone', () {
      final l = lay(6, 3, station: true);
      expect(l.station, const Offset(26, 216));
      expect(l.spot(-1), const Offset(84, 208));
      // Not first in its row: the stone before it (map AMBIG-5).
      expect(lay(6, 4, station: true).station, const Offset(80, 354));
      expect(lay(6, 3).station, isNull);
    });

    test('the guide parks 58 towards the middle, 8 up', () {
      final l = lay(6, 3);
      expect(l.spot(0), const Offset(254, 70));
      expect(l.spot(3), const Offset(138, 346));
    });

    test('the bubble frame and its tail (bubble §2.1, §2.2)', () {
      final l = lay(6, 3);
      final frame = l.bubbleFrame(
        reviewFirst: false,
        targetX: l.stones[3].dx,
        targetRow: 1,
      );
      expect(frame.x0, 46);
      expect(frame.x1, 340);
      expect(frame.width, 294);
      expect(frame.tailX, 25);
      expect(frame.side, TailSide.bottom);
      final above = l.bubbleFrame(
        reviewFirst: false,
        targetX: l.stones[1].dx,
        targetRow: 0,
      );
      expect(above.side, TailSide.top);
      expect(above.tailX, 196 - 46 - 9);

      final review = lay(
        6,
        3,
        station: true,
      ).bubbleFrame(reviewFirst: true, targetX: 26, targetRow: 1);
      expect(review.x0, 70);
      expect(review.x1, 340);
      expect(review.width, 270);
      expect(review.side, TailSide.left);

      // An odd gap row moves the inset to the other side.
      final odd = lay(
        8,
        6,
      ).bubbleFrame(reviewFirst: false, targetX: 292, targetRow: 2);
      expect(odd.x0, 20);
      expect(odd.x1, 314);
    });

    test('320 scales x, keeps the turn edges and every y (D2)', () {
      final narrow = lay(6, 3, frame: MapFrame(320));
      expect(narrow.stones[0].dx, closeTo(312 * 320 / 360, 1e-9));
      expect(narrow.rowY, [78, 354]);
      expect(narrow.height, 440);
      final turn = narrow.segments[3].whereType<CubicTo>().first.end;
      expect(turn.dx, 26);
      final frame = narrow.bubbleFrame(
        reviewFirst: false,
        targetX: narrow.stones[3].dx,
        targetRow: 1,
      );
      expect(frame.x0, 46);
      expect(frame.x1, 300);
    });

    test('a wide screen centres a 480 frame', () {
      final wide = lay(6, 3, frame: MapFrame(600));
      expect(wide.stones[0].dx, closeTo(60 + 312 * 480 / 360, 1e-9));
      final turn = wide.segments[3].whereType<CubicTo>().first.end;
      expect(turn.dx, 60 + 26);
    });

    test('the banner box (map §7)', () {
      expect(lay(6, 3).banner, const Rect.fromLTWH(104, 2, 236, 48));
      final narrow = lay(6, 3, frame: MapFrame(320)).banner;
      expect(narrow.left, closeTo(104 * 320 / 360, 1e-9));
      expect(narrow.right, closeTo(300, 1e-9));
      expect(lay(6, 3, kids: true).banner, const Rect.fromLTRB(64, 2, 340, 66));
      // Emar's book line may take it on to 20 from the frame's end.
      expect(lay(6, 3).bannerRoom, const Rect.fromLTRB(20, 2, 340, 50));
      expect(
        lay(6, 3, frame: MapFrame(600)).bannerRoom,
        const Rect.fromLTRB(60 + 20, 2, 60 + 480 - 20, 50),
      );
    });

    test('tufts stand at the design points', () {
      final l = lay(6, 3);
      expect(l.tufts.first, const Offset(44, 176));
      expect(l.tufts[3], const Offset(118, 404));
    });
  });

  group('anchor (map §9)', () {
    test('the default island: box at the exit, rel 42 at VIEW 624', () {
      final island = IslandLayout.compute(
        lessons: 6,
        current: 3,
        kids: false,
        frame: design,
      );
      final anchor = MapAnchor.compute(
        island: island,
        current: 3,
        kids: false,
        reviewBox: true,
        reviewStation: false,
        partial: false,
        pt: 154,
        view: 624,
        bubbleHeight: 170,
      );
      expect(anchor.box, BoxPlace.exit);
      expect(anchor.rel, 42);
    });

    test('a tall screen puts the box on top', () {
      final island = IslandLayout.compute(
        lessons: 6,
        current: 3,
        kids: false,
        frame: design,
      );
      final anchor = MapAnchor.compute(
        island: island,
        current: 3,
        kids: false,
        reviewBox: true,
        reviewStation: false,
        partial: false,
        pt: 154,
        view: 800,
        bubbleHeight: 0,
      );
      expect(anchor.box, BoxPlace.top);
      // The box's top 20 under the header.
      expect(anchor.rel, -58 - 20);
    });

    test('a short screen hides the box and keeps the bubble 20 under', () {
      final island = IslandLayout.compute(
        lessons: 6,
        current: 3,
        kids: false,
        frame: design,
      );
      final anchor = MapAnchor.compute(
        island: island,
        current: 3,
        kids: false,
        reviewBox: true,
        reviewStation: false,
        partial: false,
        pt: 154,
        view: 300,
        bubbleHeight: 170,
      );
      expect(anchor.box, BoxPlace.hide);
      // Nothing fits: the top of the bubble 20 under the header.
      expect(anchor.rel, 140 - 20);
    });

    test('no review box, a done unit: the plain rest', () {
      final island = IslandLayout.compute(
        lessons: 6,
        current: 6,
        kids: false,
        frame: design,
      );
      final anchor = MapAnchor.compute(
        island: island,
        current: 6,
        kids: false,
        reviewBox: false,
        reviewStation: false,
        partial: false,
        pt: 154,
        view: 624,
        bubbleHeight: 170,
      );
      expect(anchor.box, isNull);
      expect(anchor.rel, -10);
    });

    test('first lesson, no box: the banner shows whole', () {
      final island = IslandLayout.compute(
        lessons: 6,
        current: 0,
        kids: false,
        frame: design,
      );
      final anchor = MapAnchor.compute(
        island: island,
        current: 0,
        kids: false,
        reviewBox: false,
        reviewStation: false,
        partial: false,
        pt: 154,
        view: 624,
        bubbleHeight: 170,
      );
      expect(anchor.rel, -10);
    });
  });

  group('map layout (map §2, §10)', () {
    final statuses = [
      UnitLessonStatus.done,
      UnitLessonStatus.done,
      UnitLessonStatus.current,
      for (var i = 0; i < 5; i++) UnitLessonStatus.locked,
    ];
    final island = IslandLayout.compute(
      lessons: 6,
      current: 3,
      kids: false,
      frame: design,
    );
    final anchor = MapAnchor.compute(
      island: island,
      current: 3,
      kids: false,
      reviewBox: true,
      reviewStation: false,
      partial: false,
      pt: 154,
      view: 624,
      bubbleHeight: 170,
    );
    final map = MapLayout.compute(
      units: statuses,
      currentUnit: 2,
      ordered: true,
      current: island,
      anchor: anchor,
      reviewBox: true,
      frame: design,
    );

    test('the stack of the worked example', () {
      expect(
        [for (final slot in map.islands) slot.rect.top],
        [26, 150, 310, 832, 956, 1080, 1204, 1328],
      );
      expect(map.horizonY, 1498);
      expect(map.height, 1748);
      expect(map.currentIndex, 2);
      expect(map.islands[2].rect, const Rect.fromLTWH(0, 310, 360, 440));
      expect(map.islands[0].rect, const Rect.fromLTWH(164, 26, 176, 112));
      expect(map.islands[1].rect, const Rect.fromLTWH(20, 150, 176, 112));
      expect(map.initialScroll(pt: 154, view: 624), 310 + 42);
    });

    test('the bridge into the current island', () {
      _expectPath(
        svgOf(map.bridges[1].whole),
        'M180 220 C180 267.3 312 258.7 312 306',
      );
      expect(map.bridges[0].built, isTrue);
      expect(map.bridges[1].built, isTrue);
      expect(map.bridges[2].built, isFalse);
      expect(map.bridges.length, 8);
      // The last runs into the horizon.
      expect(map.bridges.last.p3, const Offset(180, 1498 + 6));
      // Out of the current island from its exit.
      expect(map.bridges[2].p0, const Offset(312, 310 + 434));
    });

    test('a part of a bridge by its parameter (de Casteljau)', () {
      final bridge = map.bridges[1];
      expect(bridge.part(0), isEmpty);
      expect(bridge.part(1), bridge.whole);
      final half = bridge.part(.5);
      final end = (half.last as CubicTo).end;
      // The curve's point at t = .5.
      expect(end.dx, closeTo((180 + 3 * 180 + 3 * 312 + 312) / 8, 1e-9));
      expect(end.dy, closeTo((220 + 3 * 267.3 + 3 * 258.7 + 306) / 8, 1e-9));
    });

    test('the review box at the exit, opposite the trail (map §8)', () {
      // The last stone is on the start side: the box on the end side.
      expect(map.reviewBox, const Rect.fromLTWH(10, 310 + 440 - 22, 198, 68));
    });

    test('the box on top adds its room above the island', () {
      final tall = MapAnchor.compute(
        island: island,
        current: 3,
        kids: false,
        reviewBox: true,
        reviewStation: false,
        partial: false,
        pt: 154,
        view: 800,
        bubbleHeight: 170,
      );
      final layout = MapLayout.compute(
        units: statuses,
        currentUnit: 2,
        ordered: true,
        current: island,
        anchor: tall,
        reviewBox: true,
        frame: design,
      );
      expect(layout.islands[2].rect.top, 310 + 64);
      expect(layout.islands[3].rect.top, 310 + 64 + 440 + 30);
      expect(layout.reviewBox, const Rect.fromLTWH(10, 374 - 58, 198, 68));
    });

    test('Emar bridges every island; all done ends at the bottom', () {
      final emar = MapLayout.compute(
        units: [
          UnitLessonStatus.current,
          for (var i = 0; i < 5; i++) UnitLessonStatus.open,
        ],
        currentUnit: 0,
        ordered: false,
        current: island,
        anchor: const MapAnchor(box: null, rel: -10),
        reviewBox: false,
        frame: design,
      );
      expect(
        [for (final b in emar.bridges) b.built],
        [true, true, true, true, true, false],
      );
      expect(emar.islands[0].rect.top, 26);

      final done = MapLayout.compute(
        units: [for (var i = 0; i < 4; i++) UnitLessonStatus.done],
        currentUnit: 4,
        ordered: true,
        current: null,
        anchor: const MapAnchor(box: null, rel: -10),
        reviewBox: false,
        frame: design,
      );
      expect(done.currentIndex, isNull);
      expect(done.bridges.every((b) => b.built), isTrue);
      expect(done.height, 26 + 4 * 124 + 46 + 250);
      expect(done.initialScroll(pt: 154, view: 624), 154 + done.height - 624);
    });

    test('compact columns keep their edges at 320', () {
      final narrow = MapFrame(320);
      final layout = MapLayout.compute(
        units: statuses,
        currentUnit: 2,
        ordered: true,
        current: IslandLayout.compute(
          lessons: 6,
          current: 3,
          kids: false,
          frame: narrow,
        ),
        anchor: anchor,
        reviewBox: true,
        frame: narrow,
      );
      expect(layout.islands[0].rect.left, 320 - 196);
      expect(layout.islands[1].rect.left, 20);
      expect(layout.reviewBox!.left, 10);
    });
  });
}
