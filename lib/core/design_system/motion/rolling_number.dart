import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:flutter/widgets.dart';

/// One number rolling up into the next, as a day's streak turns over. Only the
/// new number reaches a screen reader. With nothing to roll, it stays still.
class RollingNumber extends StatelessWidget {
  const RollingNumber({
    required this.from,
    required this.to,
    required this.style,
    required this.delay,
    this.duration = AppMotion.numberRoll,
    super.key,
  });

  final int from;
  final int to;
  final TextStyle style;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (from == to) return Text('$to', style: style);
    return Semantics(
      label: '$to',
      excludeSemantics: true,
      child: ClipRect(
        child: TimedValue(
          delay: delay,
          duration: duration,
          curve: AppMotion.overshoot,
          // Half of the two numbers shows; which half follows the value.
          builder: (_, value) => Align(
            alignment: Alignment(0, 2 * value - 1),
            heightFactor: .5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$from', style: style),
                Text('$to', style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
