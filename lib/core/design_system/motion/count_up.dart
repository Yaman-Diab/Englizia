import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';

/// A number that counts up to [value]: from zero on first showing, and from what
/// it shows now when [value] changes, so a total can grow in place. Under reduce
/// motion the number is simply there. Only [builder] rebuilds as it counts.
///
/// [builder] draws the number; a screen reader should get the final value, not
/// each step, so the caller labels it.
class CountUp extends StatefulWidget {
  const CountUp({
    required this.value,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = AppMotion.countUp,
    this.onDone,
    super.key,
  });

  final int value;
  final Widget Function(BuildContext context, int shown) builder;
  final Duration delay;
  final Duration duration;

  /// It reached [value] by counting, for what follows the last step.
  final VoidCallback? onDone;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  Curve _curve = AppMotion.countUpCurve;
  var _from = 0;
  var _to = 0;

  int get _shown =>
      (_from + (_to - _from) * _curve.transform(_controller.value)).round();

  void _countTo(int value) {
    final from = _shown;
    _to = value;
    if (from == value || AppMotion.reduceMotion(context)) {
      _from = value;
      _controller
        ..stop()
        ..value = 1;
      return;
    }
    _from = from;
    final total = widget.delay + widget.duration;
    _curve = Interval(
      widget.delay.inMicroseconds / total.inMicroseconds,
      1,
      curve: AppMotion.countUpCurve,
    );
    _controller.duration = total;
    _controller.forward(from: 0).then((_) {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_to != widget.value) {
      _countTo(widget.value);
    } else if (AppMotion.reduceMotion(context) && _controller.isAnimating) {
      _countTo(_to);
      _jumpToEnd();
    }
  }

  /// Reduce motion came on while counting: no more steps.
  void _jumpToEnd() {
    _from = _to;
    _controller
      ..stop()
      ..value = 1;
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _countTo(widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _shown),
  );
}
