import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:flutter/widgets.dart';

/// The sea under the whole map, deepening down to the horizon, and the
/// horizon band from [horizonY] to the bottom (map §11). Emar and kids have
/// their own seas; the general track's is its level's. [waves] go between
/// the sea and the band, which covers them.
class SeaLayer extends StatelessWidget {
  const SeaLayer({
    required this.tone,
    required this.cefr,
    required this.height,
    required this.horizonY,
    required this.horizonOpen,
    required this.nextCefr,
    this.waves,
    super.key,
  });

  final SeaTone tone;
  final HomeCefr? cefr;
  final double height;
  final double horizonY;

  /// 0 closed (haze, a line on top), 1 open on the next level's sea (M7).
  final double horizonOpen;
  final HomeCefr? nextCefr;

  /// The [WavesLayer] over the sea, under the horizon band.
  final Widget? waves;

  /// The sea of [tone] at level [cefr].
  ///
  /// ASSUMPTION(design): an unknown level is drawn in the A2 sea (D38).
  static Color seaOf(SeaPalette sea, SeaTone tone, HomeCefr? cefr) =>
      switch (tone) {
        SeaTone.emar => sea.emar,
        SeaTone.kids => sea.kids,
        SeaTone.general => sea.cefrSea(cefr?.name),
      };

  /// The open horizon: the next level's sea, else the deep one (D38).
  static Color openHorizonOf(SeaPalette sea, HomeCefr? next) =>
      next == null ? sea.deep : sea.cefrSea(next.name);

  @override
  Widget build(BuildContext context) {
    final sea = SeaPalette.of(context);
    final top = seaOf(sea, tone, cefr);
    final open = horizonOpen.clamp(0.0, 1.0).toDouble();
    final line = context.scheme.outline;
    final waves = this.waves;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _SeaPainter(top: top, bottom: sea.seaBottom(top)),
              ),
            ),
            ?waves,
            CustomPaint(
              painter: _HorizonPainter(
                top: horizonY,
                fill: Color.lerp(sea.haze, openHorizonOf(sea, nextCefr), open)!,
                line: line.withValues(alpha: line.a * .5 * (1 - open)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeaPainter extends CustomPainter {
  _SeaPainter({required this.top, required this.bottom});

  final Color top;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SeaPainter old) => old.top != top || old.bottom != bottom;
}

/// The band at the bottom of the level: haze with a line on top while the
/// next level is closed, its sea once open.
class _HorizonPainter extends CustomPainter {
  _HorizonPainter({required this.top, required this.fill, required this.line});

  final double top;
  final Color fill;
  final Color line;

  static const _lineWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (top >= size.height) return;
    canvas.drawRect(
      Rect.fromLTRB(0, top, size.width, size.height),
      Paint()..color = fill,
    );
    if (line.a > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, top + _lineWidth),
        Paint()..color = line,
      );
    }
  }

  @override
  bool shouldRepaint(_HorizonPainter old) =>
      old.top != top || old.fill != fill || old.line != line;
}
