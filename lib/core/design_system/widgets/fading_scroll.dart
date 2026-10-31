import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// Text that scrolls inside its card, fading out at the bottom until its end is
/// reached, so a learner can tell there is more of it.
class FadingScroll extends StatefulWidget {
  const FadingScroll({
    required this.padding,
    required this.child,
    this.fade = 44,
    super.key,
  });

  final EdgeInsetsGeometry padding;
  final double fade;
  final Widget child;

  @override
  State<FadingScroll> createState() => _FadingScrollState();
}

class _FadingScrollState extends State<FadingScroll> {
  final _scroll = ScrollController();
  bool _atEnd = true;

  bool _follow(ScrollMetrics metrics) {
    final atEnd = metrics.extentAfter <= 2;
    if (atEnd != _atEnd) setState(() => _atEnd = atEnd);
    // The page must not take this scrolling for its own.
    return true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solid = context.colors.surface;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [solid, solid, if (_atEnd) solid else Colors.transparent],
        stops: [
          0,
          bounds.height == 0
              ? 1
              : ((bounds.height - widget.fade) / bounds.height).clamp(0, 1),
          1,
        ],
      ).createShader(bounds),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _follow(n.metrics),
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) => _follow(n.metrics),
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
