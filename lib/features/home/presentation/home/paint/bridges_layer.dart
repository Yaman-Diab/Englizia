import 'dart:ui' show PointMode;

import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/path_commands.dart';
import 'package:flutter/widgets.dart';

/// The dotted bridges between islands, under them: grey dots the
/// whole way, white dots over the part reached. [fills] overrides how much
/// of bridge k is built, 0 to 1, by the curve's parameter (M6 draws one).
/// Physical space of the right-to-left layout, mirrored in left-to-right.
class BridgesLayer extends StatelessWidget {
  const BridgesLayer({required this.layout, required this.fills, super.key});

  final MapLayout layout;
  final Map<int, double> fills;

  @override
  Widget build(BuildContext context) {
    final sea = SeaPalette.of(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(
          height: layout.height,
          child: RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              painter: _BridgesPainter(
                bridges: [
                  for (final bridge in layout.bridges)
                    (
                      curve: bridge,
                      built: (fills[bridge.from] ?? (bridge.built ? 1.0 : 0.0))
                          .clamp(0.0, 1.0)
                          .toDouble(),
                    ),
                ],
                todo: sea.bridgeTodo,
                done: sea.bridge,
                mirrored: Directionality.of(context) == TextDirection.ltr,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BridgesPainter extends CustomPainter {
  _BridgesPainter({
    required this.bridges,
    required this.todo,
    required this.done,
    required this.mirrored,
  });

  final List<({BridgeCurve curve, double built})> bridges;
  final Color todo;
  final Color done;
  final bool mirrored;

  /// A dash of `0 10` with round caps: a dot every 10 along the way.
  static const _gap = 10.0;
  static const _todoDot = 4.0;
  static const _builtDot = 6.5;

  static void _dots(
    Canvas canvas,
    List<PathCommand> commands,
    double diameter,
    Color color,
  ) {
    final points = <Offset>[
      for (final metric in toPath(commands).computeMetrics())
        for (var at = 0.0; at <= metric.length; at += _gap)
          ?metric.getTangentForOffset(at)?.position,
    ];
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = color
        ..strokeWidth = diameter
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    for (final bridge in bridges) {
      _dots(canvas, bridge.curve.whole, _todoDot, todo);
    }
    for (final bridge in bridges) {
      if (bridge.built <= 0) continue;
      _dots(canvas, bridge.curve.part(bridge.built), _builtDot, done);
    }
    if (mirrored) canvas.restore();
  }

  @override
  bool shouldRepaint(_BridgesPainter old) {
    if (old.todo != todo || old.done != done || old.mirrored != mirrored) {
      return true;
    }
    if (old.bridges.length != bridges.length) return true;
    for (var i = 0; i < bridges.length; i++) {
      final a = old.bridges[i];
      final b = bridges[i];
      if (a.built != b.built ||
          a.curve.p0 != b.curve.p0 ||
          a.curve.p1 != b.curve.p1 ||
          a.curve.p2 != b.curve.p2 ||
          a.curve.p3 != b.curve.p3) {
        return true;
      }
    }
    return false;
  }
}
