import 'package:englizia/core/design_system/app_motion.dart';
import 'package:flutter/material.dart';

/// How one element enters: slide down, slide up, or pop (grow with a small
/// overshoot), each fading in.
enum EntranceMotion { down, up, pop }

/// Runs one staggered entrance for a screen; children read it through
/// [EntranceItem]. Skipped entirely when motion is reduced.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({required this.child, super.key});

  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller
        ..duration = AppMotion.heroEntrance
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _EntranceScope(animation: _controller, child: widget.child);
}

class _EntranceScope extends InheritedWidget {
  const _EntranceScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_EntranceScope oldWidget) =>
      animation != oldWidget.animation;
}

/// One element of a [StaggeredEntrance], animating between [begin] and [end]
/// (fractions of the whole entrance).
class EntranceItem extends StatelessWidget {
  const EntranceItem({
    required this.motion,
    required this.begin,
    required this.end,
    required this.child,
    super.key,
  });

  final EntranceMotion motion;
  final double begin;
  final double end;
  final Widget child;

  /// Starting scale of a popping element (welcome design).
  static const _popFrom = .82;

  @override
  Widget build(BuildContext context) {
    final parent = context
        .dependOnInheritedWidgetOfExactType<_EntranceScope>()!
        .animation;
    final progress = parent.drive(
      CurveTween(curve: Interval(begin, end, curve: AppMotion.smoothOut)),
    );
    final fade = FadeTransition(opacity: progress, child: child);
    return switch (motion) {
      EntranceMotion.pop => ScaleTransition(
        scale: parent.drive(
          Tween(begin: _popFrom, end: 1.0).chain(
            CurveTween(curve: Interval(begin, end, curve: AppMotion.bounce)),
          ),
        ),
        child: fade,
      ),
      EntranceMotion.down || EntranceMotion.up => AnimatedBuilder(
        animation: progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            (motion == EntranceMotion.down ? -1 : 1) *
                AppMotion.distanceMedium *
                (1 - progress.value),
          ),
          child: child,
        ),
        child: fade,
      ),
    };
  }
}
