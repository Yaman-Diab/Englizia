import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// [child] (usually the guide) hops once after [delay], for a quiet success.
/// Stays still under reduce motion.
class HopOnce extends StatelessWidget {
  const HopOnce({
    required this.delay,
    required this.child,
    this.height = 10,
    super.key,
  });

  final Duration delay;
  final Widget child;
  final double height;

  static const _up = Duration(milliseconds: 120);
  static const _down = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;
    return Animate(delay: delay, child: child)
        .moveY(begin: 0, end: -height, duration: _up, curve: AppMotion.out)
        .then()
        .moveY(begin: 0, end: height, duration: _down, curve: AppMotion.inOut);
  }
}
