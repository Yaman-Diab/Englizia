import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// Moves between the steps of a flow, one at a time: when the child's key
/// changes, the old step slides out toward the start while fading, then the new
/// one slides in from the end. A plain fade under reduce motion. Give the child
/// a key that changes with the step.
class SlideSwap extends StatefulWidget {
  const SlideSwap({required this.child, super.key});

  final Widget child;

  @override
  State<SlideSwap> createState() => _SlideSwapState();
}

class _SlideSwapState extends State<SlideSwap>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  late Widget _shown = widget.child;
  bool _leaving = false;

  @override
  void didUpdateWidget(SlideSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Widget.canUpdate(_shown, widget.child)) {
      _shown = widget.child;
    } else if (!_leaving) {
      _leave();
    }
  }

  Future<void> _leave() async {
    final reduce = AppMotion.reduceMotion(context);
    _leaving = true;
    await _controller
        .animateBack(
          0,
          duration: reduce ? AppMotion.stepOutReduced : AppMotion.stepOut,
          curve: AppMotion.inOut,
        )
        .orCancel
        .catchError((_) {});
    if (!mounted) return;
    setState(() {
      _shown = widget.child;
      _leaving = false;
    });
    await _controller
        .animateTo(
          1,
          duration: reduce ? AppMotion.quick : AppMotion.fast,
          curve: AppMotion.out,
        )
        .orCancel
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    final forward = Directionality.of(context) == TextDirection.rtl
        ? 1.0
        : -1.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final away = 1 - _controller.value;
        final side = _leaving ? forward : -forward;
        return Opacity(
          opacity: _controller.value,
          child: reduce
              ? child
              : Transform.translate(
                  offset: Offset(side * AppMotion.distanceLarge * away, 0),
                  child: child,
                ),
        );
      },
      child: _shown,
    );
  }
}
