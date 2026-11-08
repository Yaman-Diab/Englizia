import 'dart:math' as math;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/stage_controller.dart';
import 'package:flutter/material.dart';

/// The map's scroll view (design "Home Archipelago", M12): the
/// header's room, then the map; every scroll feeds the [stage], and at the
/// very top a pull down follows the finger at [AppMotion.homePullFactor] up
/// to [AppMotion.homePullMax]. What the pull does as it moves and when let
/// go (the threshold's tick, the hold, the refresh, the way back) is the
/// page's: [onPull] and [onRelease].
class MapScrollView extends StatefulWidget {
  const MapScrollView({
    required this.controller,
    required this.stage,
    required this.top,
    required this.child,
    required this.onPull,
    required this.onRelease,
    required this.onScrolled,
    this.canPull = true,
    super.key,
  });

  final ScrollController controller;
  final StageController stage;

  /// The header's room above the map (`PT`).
  final double top;

  /// The map.
  final Widget child;

  /// The pull moved to this far.
  final ValueChanged<double> onPull;

  /// Let go at this far; done once the stage is back.
  final Future<void> Function(double pull) onRelease;

  /// Any scroll: the stone card closes.
  final VoidCallback onScrolled;

  /// False while a celebration plays.
  final bool canPull;

  @override
  State<MapScrollView> createState() => _MapScrollViewState();
}

class _MapScrollViewState extends State<MapScrollView> {
  late final _physics = _PullPhysics(held: () => widget.stage.pulling);
  int? _pointer;
  double _from = 0;
  bool _releasing = false;

  bool get _atTop =>
      !widget.controller.hasClients || widget.controller.offset <= 0;

  void _down(PointerDownEvent event) {
    if (!mounted) return;
    if (_pointer != null || !widget.canPull || _releasing || !_atTop) return;
    _pointer = event.pointer;
    _from = event.position.dy;
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || !mounted) return;
    if (!_atTop && !widget.stage.pulling) {
      // The map scrolled first: the pull starts once it is back at the top.
      _from = event.position.dy;
      return;
    }
    final drag = event.position.dy - _from;
    final pull = drag <= 0
        ? 0.0
        : math.min(AppMotion.homePullMax, drag * AppMotion.homePullFactor);
    if (pull == widget.stage.pull) return;
    widget.stage.setPull(pull);
    widget.onPull(pull);
  }

  Future<void> _up(PointerEvent event) async {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (!mounted) return;
    final pull = widget.stage.pull;
    if (pull <= 0) return;
    _releasing = true;
    try {
      await widget.onRelease(pull);
    } finally {
      _releasing = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollUpdateNotification) {
      widget.stage.onScroll(notification.metrics.pixels);
      widget.onScrolled();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ColoredBox(
        color: context.colors.background,
        child: CustomScrollView(
          controller: widget.controller,
          physics: _physics,
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: widget.top)),
            SliverToBoxAdapter(child: widget.child),
          ],
        ),
      ),
    ),
  );
}

/// Clamped at the edges, as the design's page; while the map is pulled the
/// finger moves the pull, not the map.
class _PullPhysics extends ClampingScrollPhysics {
  const _PullPhysics({required this.held, super.parent});

  final bool Function() held;

  @override
  _PullPhysics applyTo(ScrollPhysics? ancestor) =>
      _PullPhysics(held: held, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      held() ? 0 : super.applyPhysicsToUserOffset(position, offset);
}
