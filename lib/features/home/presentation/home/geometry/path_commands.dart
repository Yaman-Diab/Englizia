import 'package:flutter/painting.dart';

/// One command of a drawn path, kept as data so the map's geometry can be
/// computed and tested without a canvas.
sealed class PathCommand {
  const PathCommand();

  /// Where the pen is after this command.
  Offset get end;
}

/// Starts a new sub-path at [point].
final class MoveTo extends PathCommand {
  const MoveTo(this.point);

  final Offset point;

  @override
  Offset get end => point;

  @override
  bool operator ==(Object other) => other is MoveTo && other.point == point;

  @override
  int get hashCode => Object.hash(MoveTo, point);

  @override
  String toString() => 'M${_n(point.dx)} ${_n(point.dy)}';
}

/// A straight line to [point].
final class LineTo extends PathCommand {
  const LineTo(this.point);

  final Offset point;

  @override
  Offset get end => point;

  @override
  bool operator ==(Object other) => other is LineTo && other.point == point;

  @override
  int get hashCode => Object.hash(LineTo, point);

  @override
  String toString() => 'L${_n(point.dx)} ${_n(point.dy)}';
}

/// A cubic Bézier to [end] through [c1] and [c2].
final class CubicTo extends PathCommand {
  const CubicTo(this.c1, this.c2, this.end);

  final Offset c1;
  final Offset c2;

  @override
  final Offset end;

  @override
  bool operator ==(Object other) =>
      other is CubicTo && other.c1 == c1 && other.c2 == c2 && other.end == end;

  @override
  int get hashCode => Object.hash(CubicTo, c1, c2, end);

  @override
  String toString() =>
      'C${_n(c1.dx)} ${_n(c1.dy)} ${_n(c2.dx)} ${_n(c2.dy)} '
      '${_n(end.dx)} ${_n(end.dy)}';
}

/// [commands] as a [Path].
Path toPath(List<PathCommand> commands) {
  final path = Path();
  for (final command in commands) {
    switch (command) {
      case MoveTo(:final point):
        path.moveTo(point.dx, point.dy);
      case LineTo(:final point):
        path.lineTo(point.dx, point.dy);
      case CubicTo(:final c1, :final c2, :final end):
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    }
  }
  return path;
}

/// [commands] written as an SVG path, numbers to one decimal: for tests and
/// debugging.
String svgOf(List<PathCommand> commands) => commands.join();

String _n(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
}
