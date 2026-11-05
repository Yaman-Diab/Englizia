import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The waves' pattern drifting over the sea (map §11): a 48 × 34 tile
/// repeated over the map, sliding one tile along in [AppMotion.homeWaves]
/// while [running], and lowered by [AppMotion.homeWaveParallax] of the
/// [scroll] so it moves slower than the islands. The pattern repeats, so the
/// layer only moves within one tile; it is drawn once and moved as a layer.
class WavesLayer extends StatefulWidget {
  const WavesLayer({
    required this.height,
    required this.scroll,
    required this.running,
    super.key,
  });

  /// The map's height.
  final double height;
  final ValueListenable<double> scroll;
  final bool running;

  static const tile = Size(48, 34);

  @override
  State<WavesLayer> createState() => _WavesLayerState();
}

class _WavesLayerState extends State<WavesLayer>
    with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(
    vsync: this,
    duration: AppMotion.homeWaves,
  );
  late Listenable _moves = Listenable.merge([_drift, widget.scroll]);

  void _sync() {
    final run = widget.running && !AppMotion.reduceMotion(context);
    if (run && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!run && _drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WavesLayer old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      _moves = Listenable.merge([_drift, widget.scroll]);
    }
    if (old.running != widget.running) _sync();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mirrored = Directionality.of(context) == TextDirection.ltr;
    final wave = SeaPalette.of(context).wave;
    const tile = WavesLayer.tile;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(
          height: widget.height,
          child: ClipRect(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _moves,
                builder: (context, child) {
                  final along = _drift.value * tile.width;
                  final down =
                      (widget.scroll.value * AppMotion.homeWaveParallax) %
                      tile.height;
                  return Transform.translate(
                    offset: Offset(mirrored ? -along : along, down),
                    child: child,
                  );
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    isComplex: true,
                    painter: _WavesPainter(color: wave, mirrored: mirrored),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tiles over the layer and one tile beyond each side, so a move within
/// a tile never shows an edge.
class _WavesPainter extends CustomPainter {
  _WavesPainter({required this.color, required this.mirrored});

  final Color color;
  final bool mirrored;

  Path _pattern(Size size) {
    const tile = WavesLayer.tile;
    final path = Path();
    for (
      var x = -tile.width * 2;
      x < size.width + tile.width;
      x += tile.width
    ) {
      for (var y = -tile.height; y < size.height; y += tile.height) {
        path
          ..moveTo(x + 4, y + 12)
          ..relativeQuadraticBezierTo(6, -5, 12, 0)
          ..moveTo(x + 28, y + 29)
          ..relativeQuadraticBezierTo(6, -5, 12, 0);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (mirrored) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas.drawPath(
      _pattern(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    if (mirrored) canvas.restore();
  }

  @override
  bool shouldRepaint(_WavesPainter old) =>
      old.color != color || old.mirrored != mirrored;
}
