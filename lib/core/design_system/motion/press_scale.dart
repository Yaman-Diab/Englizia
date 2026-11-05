import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// Shrinks [child] a little while pressed, for a card that answers the finger:
/// to [scale], [AppMotion.scaleMedium] unless a design says otherwise. Stays
/// as it is under reduce motion, and when not [enabled].
class PressScale extends StatefulWidget {
  const PressScale({
    required this.child,
    this.enabled = true,
    this.scale = AppMotion.scaleMedium,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled ? (_) => _set(true) : null,
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _pressed && !AppMotion.reduceMotion(context) ? widget.scale : 1,
      duration: AppMotion.micro,
      curve: AppMotion.out,
      child: widget.child,
    ),
  );
}
