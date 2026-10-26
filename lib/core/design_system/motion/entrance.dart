import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// How an element arrives on screen; every variant also fades in.
enum EntranceMotion {
  /// Rises into place (text, cards, actions).
  up,

  /// Drops into place (top badges).
  down,

  /// Grows in with a small overshoot (the guide, speech bubbles).
  pop,
}

/// One element of a screen's staggered entrance, played once when it first
/// builds. Timings come from `entrance_choreography.dart`; under reduce motion
/// the child is shown as is.
///
/// The delay runs on the animation's own timeline, not a timer, so leaving the
/// screen early leaves nothing pending.
class Entrance extends StatelessWidget {
  const Entrance({
    required this.motion,
    required this.delay,
    required this.child,
    super.key,
  });

  final EntranceMotion motion;
  final Duration delay;
  final Widget child;

  /// Starting scale of a popping element (designs).
  static const _popFrom = .82;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;
    final arrival = child.animate().fadeIn(
      delay: delay,
      duration: AppMotion.entrance,
      curve: AppMotion.smoothOut,
    );
    return switch (motion) {
      EntranceMotion.up => arrival.moveY(
        begin: AppMotion.distanceMedium,
        end: 0,
      ),
      EntranceMotion.down => arrival.moveY(
        begin: -AppMotion.distanceMedium,
        end: 0,
      ),
      EntranceMotion.pop => arrival.scaleXY(
        begin: _popFrom,
        end: 1,
        curve: AppMotion.bounce,
      ),
    };
  }
}
