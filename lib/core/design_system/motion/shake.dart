import 'dart:ui' show lerpDouble;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// A short sideways shake of [child] each time [trigger] changes: a field
/// that refused what was sent. Never on the first build, and not at all
/// under reduce motion (the error's border, icon and text still show).
class Shake extends StatefulWidget {
  const Shake({required this.trigger, required this.child, super.key});

  final Object? trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shake,
    value: 1,
  );

  /// Offsets in logical pixels at evenly spaced moments (designs), dying
  /// out; mirrored for right-to-left so the first move is toward the start.
  static const _offsets = [0.0, -7.0, 6.0, -4.0, 2.0, 0.0];

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger &&
        !AppMotion.reduceMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _offsetAt(double t) {
    final position = AppMotion.out.transform(t) * (_offsets.length - 1);
    final i = position.floor().clamp(0, _offsets.length - 2);
    return lerpDouble(_offsets[i], _offsets[i + 1], position - i)!;
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(direction * _offsetAt(_controller.value), 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}
