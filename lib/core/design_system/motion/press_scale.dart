import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// Shrinks [child] a little while pressed, for a card that answers the finger:
/// to [scale], [AppMotion.scaleMedium] unless a design says otherwise, over
/// [duration] ([AppMotion.micro] by default). Stays as it is under reduce
/// motion, and when not [enabled].
class PressScale extends StatefulWidget {
  const PressScale({
    required Widget this.child,
    this.enabled = true,
    this.scale = AppMotion.scaleMedium,
    this.duration = AppMotion.micro,
    super.key,
  }) : builder = null;

  /// [builder] draws the child, pressed or not, for a design that also
  /// changes its colours while pressed.
  const PressScale.builder({
    required Widget Function(BuildContext context, bool pressed) this.builder,
    this.enabled = true,
    this.scale = AppMotion.scaleMedium,
    this.duration = AppMotion.micro,
    super.key,
  }) : child = null;

  final Widget? child;
  final Widget Function(BuildContext context, bool pressed)? builder;
  final bool enabled;
  final double scale;
  final Duration duration;

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
      duration: widget.duration,
      curve: AppMotion.out,
      child: widget.builder?.call(context, _pressed) ?? widget.child,
    ),
  );
}
