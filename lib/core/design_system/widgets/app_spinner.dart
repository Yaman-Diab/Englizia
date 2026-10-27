import 'dart:math' as math;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// The app's one "working" mark (account designs): a faint ring with a
/// quarter arc turning on it. Buttons, pages and sheets all wait with it, so
/// waiting looks the same everywhere. [color] defaults to the ambient text
/// color, which inside a button is the button's foreground.
class AppSpinner extends StatefulWidget {
  const AppSpinner({
    this.size = buttonSize,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final double size;
  final Color? color;

  /// Read by screen readers; null leaves the spinner silent (the widget
  /// around it already says what is happening).
  final String? semanticLabel;

  /// Inside a large button (designs).
  static const buttonSize = 24.0;

  /// Inside a regular or text button.
  static const compactSize = 20.0;

  /// Alone on a page.
  static const pageSize = 36.0;

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(
    vsync: this,
    duration: AppMotion.spinnerTurn,
  )..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color;
    final spinner = SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _SpinnerPainter(
          turn: _turn,
          color: color ?? const Color(0xFF000000),
        ),
      ),
    );
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: spinner,
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({required this.turn, required this.color})
    : super(repaint: turn);

  final Animation<double> turn;
  final Color color;

  /// Stroke 3 and track 30% on a 24 box (designs).
  static const _strokeRatio = 3 / 24;
  static const _trackOpacity = .3;
  static const _arc = math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * _strokeRatio;
    // Radius 9 on a 24 box: the ring sits one stroke in from the edge.
    final rect = (Offset.zero & size).deflate(stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawOval(
        rect,
        paint..color = color.withValues(alpha: color.a * _trackOpacity),
      )
      ..drawArc(
        rect,
        -math.pi / 2 + turn.value * 2 * math.pi,
        _arc,
        false,
        paint..color = color,
      );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.color != color;
}
