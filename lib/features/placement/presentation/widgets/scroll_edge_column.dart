import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// A scrolling [body] over a pinned [footer], with a thin line between them
/// while there is content under the footer. Only the body's own scrolling
/// counts, not that of something scrolling inside it.
class ScrollEdgeColumn extends StatefulWidget {
  const ScrollEdgeColumn({required this.body, required this.footer, super.key});

  final Widget body;
  final Widget footer;

  @override
  State<ScrollEdgeColumn> createState() => _ScrollEdgeColumnState();
}

class _ScrollEdgeColumnState extends State<ScrollEdgeColumn> {
  bool _moreBelow = false;

  bool _follow(int depth, ScrollMetrics metrics) {
    if (depth != 0) return false;
    final more = metrics.extentAfter > 2;
    if (more != _moreBelow) setState(() => _moreBelow = more);
    return false;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => _follow(n.depth, n.metrics),
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (n) => _follow(n.depth, n.metrics),
            child: widget.body,
          ),
        ),
      ),
      AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.quick),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: _moreBelow ? context.colors.border : Colors.transparent,
            ),
          ),
        ),
        child: widget.footer,
      ),
    ],
  );
}
