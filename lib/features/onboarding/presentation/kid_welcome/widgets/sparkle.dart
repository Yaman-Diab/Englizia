import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/widgets.dart';

/// A four-pointed twinkle in the reward color, beside the happy guide.
/// Decorative: screen readers skip it.
class Sparkle extends StatelessWidget {
  const Sparkle({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _SparklePainter(context.colors.reward.fill),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // The designs' star: four curved points meeting at the center.
    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w / 2, h / 2, w, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, h)
      ..quadraticBezierTo(w / 2, h / 2, 0, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}
