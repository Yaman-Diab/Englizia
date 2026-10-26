import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// Replaces its child with a short fade-and-rise whenever the child's key
/// changes: a speech bubble's line, a counter, a label. Give the child a key
/// that changes with its content, e.g. `Text(line, key: ValueKey(line))`.
/// The swap is instant under reduce motion.
class Swap extends StatelessWidget {
  const Swap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.medium),
      switchInCurve: AppMotion.smoothOut,
      switchOutCurve: AppMotion.smoothOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, AppMotion.distanceSmall * (1 - animation.value)),
            child: child,
          ),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
