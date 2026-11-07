import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:flutter/widgets.dart';

/// The three clouds over a locked island's drawing, in its
/// 176 × 112 box: they drift [AppMotion.homeFogDrift] to and fro while
/// [running], and part ±40 and fade as [clear] goes to 1 (M6). Decorative.
class FogLayer extends StatefulWidget {
  const FogLayer({required this.clear, required this.running, super.key});

  /// 0 covered, 1 gone.
  final double clear;
  final bool running;

  @override
  State<FogLayer> createState() => _FogLayerState();
}

class _FogLayerState extends State<FogLayer>
    with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(
    vsync: this,
    duration: AppMotion.homeFog,
  );
  late final _eased = CurvedAnimation(parent: _drift, curve: AppMotion.inOut);

  void _sync() {
    final reduce = AppMotion.reduceMotion(context);
    final run = widget.running && !reduce && widget.clear < 1;
    if (run && !_drift.isAnimating) {
      _drift.repeat(reverse: true);
    } else if (!run && _drift.isAnimating) {
      _drift.stop();
    }
    if (reduce) _drift.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(FogLayer old) {
    super.didUpdateWidget(old);
    if (old.running != widget.running || old.clear != widget.clear) _sync();
  }

  @override
  void dispose() {
    _eased.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox.fromSize(
        size: MapLayout.compactSize,
        child: CustomPaint(
          painter: _FogPainter(
            color: SeaPalette.of(context).fog,
            clear: widget.clear.clamp(0.0, 1.0).toDouble(),
            drift: _eased,
            mirrored: Directionality.of(context) == TextDirection.ltr,
          ),
        ),
      ),
    ),
  );
}

class _FogPainter extends CustomPainter {
  _FogPainter({
    required this.color,
    required this.clear,
    required this.drift,
    required this.mirrored,
  }) : super(repaint: drift);

  final Color color;
  final double clear;
  final Animation<double> drift;
  final bool mirrored;

  /// Each cloud: where it sits, its scale; odd ones part to the start side.
  static const _clouds = [
    (6.0, 30.0, 1.0),
    (114.0, 50.0, .9),
    (48.0, 84.0, .75),
  ];
  static const _part = 40.0;
  static const _opacity = .94;

  /// One cloud as a single outline, so its faded parts don't overlap.
  static final _cloud = [
    Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 12)),
    Path()..addOval(Rect.fromCircle(center: const Offset(14, -5), radius: 15)),
    Path()..addOval(Rect.fromCircle(center: const Offset(30, 1), radius: 11)),
    Path()..addRRect(RRect.fromLTRBR(-2, 0, 32, 12, const Radius.circular(6))),
  ].reduce((a, b) => Path.combine(PathOperation.union, a, b));

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = _opacity * (1 - clear);
    if (alpha <= 0) return;
    if (mirrored) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    final paint = Paint()..color = color.withValues(alpha: color.a * alpha);
    final along = drift.value * AppMotion.homeFogDrift;
    for (final (j, (x, y, scale)) in _clouds.indexed) {
      canvas
        ..save()
        ..translate(x + (j.isOdd ? _part : -_part) * clear + along, y)
        ..scale(scale)
        ..drawPath(_cloud, paint)
        ..restore();
    }
    if (mirrored) canvas.restore();
  }

  @override
  bool shouldRepaint(_FogPainter old) =>
      old.color != color ||
      old.clear != clear ||
      old.drift != drift ||
      old.mirrored != mirrored;
}
