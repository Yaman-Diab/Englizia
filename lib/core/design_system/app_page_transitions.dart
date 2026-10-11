import 'package:englizia/core/design_system/app_motion.dart';
import 'package:flutter/material.dart';

/// Android page transition: the incoming page fades in while sliding
/// [AppMotion.distanceLarge] in from the end side (right in LTR, left in RTL).
///
/// The page underneath stays still, so only one layer animates and no window
/// background shows through. No blur. With reduce motion on, the page appears
/// in place. iOS keeps [CupertinoPageTransitionsBuilder] (see `AppTheme`).
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  /// Also used for the reverse (pop) transition.
  @override
  Duration get transitionDuration => AppMotion.fast;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduceMotion(context)) return child;
    return _AppPageTransition(animation: animation, child: child);
  }
}

class _AppPageTransition extends StatefulWidget {
  const _AppPageTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_AppPageTransition> createState() => _AppPageTransitionState();
}

class _AppPageTransitionState extends State<_AppPageTransition> {
  late CurvedAnimation _progress = _curve(widget.animation);

  // smoothOut in both directions: a pop also starts fast and lands softly.
  static CurvedAnimation _curve(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: AppMotion.smoothOut,
    reverseCurve: AppMotion.smoothOut.flipped,
  );

  @override
  void didUpdateWidget(_AppPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _progress.dispose();
      _progress = _curve(widget.animation);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromEnd = Directionality.of(context) == TextDirection.rtl
        ? -AppMotion.distanceLarge
        : AppMotion.distanceLarge;
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(fromEnd * (1 - _progress.value), 0),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
