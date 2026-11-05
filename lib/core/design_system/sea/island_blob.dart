import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// How far each of [count] points round an island's ellipse is pushed out
/// (above 1) or in (below 1), at most [wobble]: the design's seeded integer
/// generator, so the same [seed] always gives the same shape.
List<double> blobJitter(int seed, {double wobble = .1, int count = 10}) {
  var state = seed;
  return [
    for (var i = 0; i < count; i++)
      () {
        state = (state * 9301 + 49297) % 233280;
        return 1 + (state / 233280 - .5) * 2 * wobble;
      }(),
  ];
}

/// [islandBlob]'s outline as points: the start, then three per curve (its
/// two controls and its end), closed back to the start.
List<Offset> islandBlobPoints(
  double cx,
  double cy,
  double rx,
  double ry,
  int seed, {
  double wobble = .1,
  int count = 10,
}) {
  final jitter = blobJitter(seed, wobble: wobble, count: count);
  final points = [
    for (var i = 0; i < count; i++)
      Offset(
        cx + math.cos(i / count * math.pi * 2) * rx * jitter[i],
        cy + math.sin(i / count * math.pi * 2) * ry * jitter[i],
      ),
  ];
  // A closed Catmull-Rom curve through the points, as cubic Béziers.
  return [
    points[0],
    for (var i = 0; i < count; i++) ...[
      points[i] +
          (points[(i + 1) % count] - points[(i - 1 + count) % count]) / 6,
      points[(i + 1) % count] - (points[(i + 2) % count] - points[i]) / 6,
      points[(i + 1) % count],
    ],
  ];
}

/// A soft closed shape through [count] points around an ellipse, each pushed
/// in or out by up to [wobble]; the same [seed] always draws the same shape.
Path islandBlob(
  double cx,
  double cy,
  double rx,
  double ry,
  int seed, {
  double wobble = .1,
  int count = 10,
}) {
  final points = islandBlobPoints(
    cx,
    cy,
    rx,
    ry,
    seed,
    wobble: wobble,
    count: count,
  );
  final path = Path()..moveTo(points[0].dx, points[0].dy);
  for (var i = 1; i + 2 < points.length; i += 3) {
    path.cubicTo(
      points[i].dx,
      points[i].dy,
      points[i + 1].dx,
      points[i + 1].dy,
      points[i + 2].dx,
      points[i + 2].dy,
    );
  }
  return path..close();
}

/// Draws [draw]'s design, [width] × [height], into [size]: scaled to cover it
/// (held to the bottom) or to fit it (centred); [mirrored] when the layout runs
/// left to right, as the designs are drawn right to left.
void paintInBox(
  Canvas canvas,
  Size size,
  double width,
  double height, {
  required bool cover,
  required bool mirrored,
  required void Function() draw,
}) {
  final scale = cover
      ? math.max(size.width / width, size.height / height)
      : math.min(size.width / width, size.height / height);
  canvas.save();
  if (mirrored) {
    canvas
      ..translate(size.width, 0)
      ..scale(-1, 1);
  }
  canvas
    ..translate(
      (size.width - width * scale) / 2,
      cover ? size.height - height * scale : (size.height - height * scale) / 2,
    )
    ..scale(scale);
  draw();
  canvas.restore();
}
