import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/stage_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Builds a layer of the stage from where the header stands this frame.
typedef StageLayerBuilder =
    Widget Function(BuildContext context, StageMetrics metrics);

/// The stage's layers in the design's order (design "Home Archipelago",
/// header §1), in main coordinates (y 0 at the top bar's top): the stage
/// under the top bar, pulled down by `pull`, holds the map's scroll view, the
/// day header folding by `collapse` and the level header under it; over it
/// the pull's guide, the top bar, the ring, the guide's words, the switch
/// strip, the back button, the flights and the skip layer.
///
/// Only the layers that follow the header rebuild as it moves; the
/// [scrollView] is built once per change of the map. A vertical drag on the
/// headers scrolls the map too.
class HomeStage extends StatelessWidget {
  const HomeStage({
    required this.stage,
    required this.scrollController,
    required this.scrollView,
    required this.dayHeader,
    required this.levelHeader,
    required this.pullGuide,
    required this.topBar,
    required this.ring,
    required this.say,
    required this.flights,
    required this.skip,
    this.mapOpacity = 1,
    this.contentShift = 0,
    this.switchStrip,
    this.backButton,
    super.key,
  });

  final StageController stage;

  /// The map's, which a drag on the headers moves.
  final ScrollController scrollController;
  final Widget scrollView;
  final StageLayerBuilder dayHeader;
  final StageLayerBuilder levelHeader;

  /// The pull's guide, the ring and the guide's words fill the main area
  /// and place themselves.
  final StageLayerBuilder pullGuide;
  final StageLayerBuilder topBar;

  final StageLayerBuilder ring;
  final StageLayerBuilder say;
  final Widget flights;
  final Widget skip;

  /// M11's fade of the map while the track switches.
  final double mapOpacity;

  /// A card closing: the map and the level header come up from this far.
  final double contentShift;

  /// Places itself under the top bar.
  final Widget? switchStrip;

  /// Placed at the bottom of the end side, 18 in and 20 up.
  final Widget? backButton;

  static const backEnd = 18.0;
  static const backBottom = 20.0;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      PositionedDirectional(
        top: StageMetrics.topBar,
        start: 0,
        end: 0,
        bottom: 0,
        child: ClipRect(
          child: ListenableBuilder(
            listenable: stage,
            child: Transform.translate(
              offset: Offset(0, contentShift),
              child: Opacity(
                opacity: mapOpacity.clamp(0.0, 1.0),
                child: scrollView,
              ),
            ),
            builder: (context, map) {
              final metrics = stage.metrics;
              return Transform.translate(
                offset: Offset(0, metrics.pull),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: map!),
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      child: Transform.translate(
                        offset: Offset(0, metrics.head - metrics.collapse),
                        child: Transform.translate(
                          offset: Offset(0, contentShift),
                          child: _DragToScroll(
                            controller: scrollController,
                            child: levelHeader(context, metrics),
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      child: Transform.translate(
                        offset: Offset(0, -metrics.collapse),
                        child: _DragToScroll(
                          controller: scrollController,
                          child: dayHeader(context, metrics),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: ListenableBuilder(
            listenable: stage,
            builder: (context, _) => pullGuide(context, stage.metrics),
          ),
        ),
      ),
      PositionedDirectional(
        top: 0,
        start: 0,
        end: 0,
        height: StageMetrics.topBar,
        child: ListenableBuilder(
          listenable: stage,
          builder: (context, _) => topBar(context, stage.metrics),
        ),
      ),
      Positioned.fill(
        child: ListenableBuilder(
          listenable: stage,
          builder: (context, _) => ring(context, stage.metrics),
        ),
      ),
      Positioned.fill(
        child: ListenableBuilder(
          listenable: stage,
          builder: (context, _) => say(context, stage.metrics),
        ),
      ),
      if (switchStrip case final strip?) Positioned.fill(child: strip),
      if (backButton case final button?)
        PositionedDirectional(end: backEnd, bottom: backBottom, child: button),
      Positioned.fill(child: flights),
      Positioned.fill(child: skip),
    ],
  );
}

/// A vertical drag on a header scrolls the map under it, as the finger
/// expects; taps still reach the header's buttons.
class _DragToScroll extends StatefulWidget {
  const _DragToScroll({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  State<_DragToScroll> createState() => _DragToScrollState();
}

class _DragToScrollState extends State<_DragToScroll> {
  Drag? _drag;

  void _start(DragStartDetails details) {
    if (!widget.controller.hasClients) return;
    _drag = widget.controller.position.drag(details, () => _drag = null);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    excludeFromSemantics: true,
    behavior: HitTestBehavior.translucent,
    onVerticalDragStart: _start,
    onVerticalDragUpdate: (details) => _drag?.update(details),
    onVerticalDragEnd: (details) => _drag?.end(details),
    onVerticalDragCancel: () => _drag?.cancel(),
    child: widget.child,
  );
}
