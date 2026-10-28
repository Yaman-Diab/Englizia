import 'dart:math' as math;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// One gentle beat on [child] — grows a little and back — each time
/// [trigger] changes: a flame when the streak goal changes, a badge when a
/// count goes up. Never on the first build, and not at all under reduce
/// motion.
class Pulse extends StatefulWidget {
  const Pulse({
    required this.trigger,
    required this.child,
    this.alignment = Alignment.center,
    this.growth = defaultGrowth,
    super.key,
  });

  final Object? trigger;
  final Widget child;

  /// The point that stays put while it grows (a flame grows from its base).
  final Alignment alignment;

  /// How much bigger at the top of the beat: [defaultGrowth] for a mark, a
  /// few percent for a whole button.
  final double growth;
  static const defaultGrowth = .18;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
    value: 1,
  );

  @override
  void didUpdateWidget(Pulse oldWidget) {
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.scale(
      scale: 1 + widget.growth * math.sin(math.pi * _controller.value),
      alignment: widget.alignment,
      child: child,
    ),
    child: widget.child,
  );
}
