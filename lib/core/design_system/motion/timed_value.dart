import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Gives [builder] a value going from 0 to 1 once, after [delay], for what a
/// plain fade or scale can't draw: a ring filling, a line growing. It runs on the
/// animation's own timeline, so nothing is left pending. Under reduce motion the
/// value is 1 from the start.
class TimedValue extends StatelessWidget {
  const TimedValue({
    required this.delay,
    required this.duration,
    required this.builder,
    this.curve = AppMotion.out,
    super.key,
  });

  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return builder(context, 1);
    return const SizedBox.shrink().animate().custom(
      delay: delay,
      duration: duration,
      curve: curve,
      builder: (context, value, _) => builder(context, value),
    );
  }
}
