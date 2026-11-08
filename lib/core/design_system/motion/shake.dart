import 'dart:ui' show lerpDouble;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// A short sideways shake of [child] each time [trigger] changes: a field
/// that refused what was sent. Never on the first build, and not at all
/// under reduce motion (the error's border, icon and text still show).
///
/// [offsets] and [duration] give another design's shake (a stone, a locked
/// island); by default the account designs' one.
class Shake extends StatefulWidget {
  const Shake({
    required this.trigger,
    required this.child,
    this.offsets = defaultOffsets,
    this.duration,
    super.key,
  });

  final Object? trigger;
  final Widget child;

  /// Offsets in logical pixels at evenly spaced moments, mirrored for
  /// right-to-left so the first move is toward the start.
  final List<double> offsets;

  /// [AppMotion.shake] when null.
  final Duration? duration;

  /// The account designs' shake, dying out.
  static const defaultOffsets = [0.0, -7.0, 6.0, -4.0, 2.0, 0.0];

  /// The offset [t] of the way through a shake of [offsets] in equal legs,
  /// [curve] easing the whole: for a shake a motion drives itself.
  static double offsetAt(
    List<double> offsets,
    double t, {
    Curve curve = AppMotion.out,
  }) {
    if (offsets.length < 2) return offsets.firstOrNull ?? 0;
    final position = curve.transform(t.clamp(0.0, 1.0)) * (offsets.length - 1);
    final i = position.floor().clamp(0, offsets.length - 2);
    return lerpDouble(offsets[i], offsets[i + 1], position - i)!;
  }

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration ?? AppMotion.shake,
    value: 1,
  );

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration ?? AppMotion.shake;
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

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          direction * Shake.offsetAt(widget.offsets, _controller.value),
          0,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
