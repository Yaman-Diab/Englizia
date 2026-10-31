import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// Eases its size when [child]'s changes, so what arrives opens its place. Under
/// reduce motion it isn't there at all: an `AnimatedSize` given no time dirties
/// itself during its own layout.
class SmoothSize extends StatelessWidget {
  const SmoothSize({
    required this.child,
    this.duration = AppMotion.fast,
    this.curve = AppMotion.out,
    this.alignment = AlignmentDirectional.topStart,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => AppMotion.reduceMotion(context)
      ? child
      : AnimatedSize(
          duration: duration,
          curve: curve,
          alignment: alignment,
          child: child,
        );
}
