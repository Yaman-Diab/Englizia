import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// Plays a short settle on [child] — a little smaller and faded, then back
/// in place — each time [trigger] changes, so an update elsewhere on the
/// screen draws the eye to what it changed (a preview, a total). Never on
/// the first build, and not at all under reduce motion.
class Settle extends StatefulWidget {
  const Settle({required this.trigger, required this.child, super.key});

  final Object? trigger;
  final Widget child;

  @override
  State<Settle> createState() => _SettleState();
}

class _SettleState extends State<Settle> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.smoothOut,
  );

  @override
  void didUpdateWidget(Settle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger &&
        !AppMotion.reduceMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, child) {
      final t = _curve.value;
      return Opacity(
        opacity: _fadeFrom + (1 - _fadeFrom) * t,
        child: Transform.scale(
          scale: AppMotion.scaleMedium + (1 - AppMotion.scaleMedium) * t,
          child: child,
        ),
      );
    },
    child: widget.child,
  );

  static const _fadeFrom = .6;
}
