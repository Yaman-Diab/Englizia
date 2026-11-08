import 'dart:async';
import 'dart:math' as math;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The floating header's state as the map scrolls, snaps and is pulled
/// (design "Home Archipelago"): scrolling down folds the day header
/// one to one, the first scroll up brings it back, it never folds more than
/// the map has scrolled, and a pause snaps it open or shut.
class StageController extends ChangeNotifier {
  /// Without [vsync] the snap jumps; [reduceMotion] makes it jump too.
  StageController({TickerProvider? vsync, bool Function()? reduceMotion})
    : _vsync = vsync,
      _reduceMotion = reduceMotion ?? _never;

  static bool _never() => false;

  final TickerProvider? _vsync;
  final bool Function() _reduceMotion;

  double width = 0;
  double height = 0;
  bool kids = false;

  /// The day header's height.
  double head = 0;
  double topSlot = 0;

  /// How far the day header has folded, 0 to [head].
  double collapse = 0;
  double scroll = 0;

  /// How far the stage is pulled down (M12).
  double pull = 0;

  /// A scroll home started itself: the header folds with it.
  bool programmatic = false;

  /// Told when the header passes half folded (the guide's hop, M8).
  ValueChanged<bool>? collapsedChanged;

  /// Asked before a snap: true leaves the header where it is (M5, M6).
  bool Function()? holdSnap;

  /// Told [AppMotion.homeSnapDelay] after the map last scrolled: the back
  /// button and the ambient motion look again.
  VoidCallback? onIdle;

  ScrollController? _scroll;
  final _scrollValue = ValueNotifier<double>(0);
  AnimationController? _snap;
  Timer? _idle;
  bool _quiet = false;
  bool _wasCollapsed = false;

  /// A fold in progress: the header goes from [c0] to [head] as the map goes
  /// from [from] to [target].
  ({double from, double target, double c0})? _fold;

  /// The map's offset, for the waves' parallax.
  ValueListenable<double> get scrollListenable => _scrollValue;

  bool get pulling => pull > 0;

  /// The map moved (a finger, or home's own scroll) since [jumpTo] last put
  /// it on its anchor.
  bool get moved => _moved;
  bool _moved = false;

  StageMetrics get metrics => StageMetrics(
    width: width,
    height: height,
    head: head,
    topSlot: topSlot,
    collapse: collapse,
    scroll: scroll,
    pull: pull,
    kids: kids,
  );

  /// The map's scroll view, which [scrollTo], [jumpTo] and [shiftScroll] move.
  void attach(ScrollController controller) => _scroll = controller;

  /// The map scrolled to [st].
  void onScroll(double st) {
    final delta = st - scroll;
    scroll = st;
    _scrollValue.value = st;
    if (_quiet) return;
    _moved = true;
    _stopSnap();
    final fold = _fold;
    final most = math.max(0.0, math.min(head, st));
    if (fold != null) {
      final span = fold.target - fold.from;
      final e = span == 0
          ? 1.0
          : ((st - fold.from) / span).clamp(0.0, 1.0).toDouble();
      collapse = math.min(fold.c0 + (head - fold.c0) * e, most);
    } else {
      collapse = (collapse + delta).clamp(0.0, most).toDouble();
    }
    _changed();
    _idle?.cancel();
    _idle = Timer(AppMotion.homeSnapDelay, _onIdle);
  }

  void _onIdle() {
    settle();
    onIdle?.call();
  }

  /// Snaps a half-folded header open, or shut as far as the map has scrolled
  /// (M8); never while pulled, while home scrolls itself or while [holdSnap]
  /// says so.
  void settle() {
    if (pulling || programmatic || (holdSnap?.call() ?? false)) return;
    final from = collapse;
    if (from <= 0 || from >= head) return;
    final to = from > head / 2 ? math.min(head, scroll) : 0.0;
    if ((to - from).abs() < .5) return;
    final vsync = _vsync;
    if (vsync == null || _reduceMotion()) {
      collapse = to;
      _changed();
      return;
    }
    _snapFrom = from;
    _snapTo = to;
    final snap = _snap ??= AnimationController(
      vsync: vsync,
      duration: AppMotion.homeSnap,
    )..addListener(_snapStep);
    unawaited(snap.forward(from: 0));
  }

  double _snapFrom = 0;
  double _snapTo = 0;

  void _snapStep() {
    final t = AppMotion.homeSnapCurve.transform(_snap!.value);
    collapse = _snapFrom + (_snapTo - _snapFrom) * t;
    _changed();
  }

  void _stopSnap() {
    final snap = _snap;
    if (snap == null || !snap.isAnimating) return;
    snap.stop();
  }

  /// Scrolls the map to [target] over [duration]; with
  /// [foldHeader] the header folds with the same ease and ends folded as far
  /// as the map has scrolled, otherwise it follows the scroll as a finger's
  /// would (M6's camera). Under reduce motion it jumps. A scroll started
  /// meanwhile takes over: this one then leaves the header to it.
  Future<void> scrollTo(
    double target,
    Duration duration, {
    bool foldHeader = true,
  }) async {
    final controller = _scroll;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    final to = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _stopSnap();
    final mine = ++_scrolls;
    programmatic = true;
    _fold = foldHeader
        ? (from: controller.offset, target: to, c0: collapse)
        : null;
    try {
      if (_reduceMotion() ||
          duration <= Duration.zero ||
          (to - controller.offset).abs() < .5) {
        controller.jumpTo(to);
      } else {
        await controller.animateTo(
          to,
          duration: duration,
          curve: AppMotion.homeScrollCurve,
        );
      }
    } finally {
      if (mine == _scrolls) {
        programmatic = false;
        _fold = null;
        if (foldHeader) {
          collapse = math.max(0.0, math.min(head, scroll));
          _changed();
        }
      }
    }
  }

  /// [scrollTo]'s calls so far: only the latest ends home's scroll.
  var _scrolls = 0;

  /// Puts the map at [offset] with the header at [collapse]: the opening
  /// anchor (c = 0), or M6's new one.
  void jumpTo(double offset, {double collapse = 0}) {
    _place(offset, collapse: collapse);
    _moved = false;
  }

  void _place(double offset, {required double collapse}) {
    final controller = _scroll;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    _quiet = true;
    try {
      controller.jumpTo(
        offset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    } finally {
      _quiet = false;
    }
    this.collapse = math.max(0.0, math.min(collapse, math.min(head, scroll)));
    _changed();
  }

  /// Moves the map by [delta] without touching the header: the header was
  /// measured taller or shorter than the design's.
  void shiftScroll(double delta) {
    if (delta == 0) return;
    final controller = _scroll;
    if (controller == null || !controller.hasClients) return;
    _place(controller.offset + delta, collapse: collapse);
  }

  void setPull(double value) {
    if (value == pull) return;
    pull = value;
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    final collapsed = metrics.collapsed;
    if (collapsed != _wasCollapsed) {
      _wasCollapsed = collapsed;
      collapsedChanged?.call(collapsed);
    }
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _idle?.cancel();
    _snap?.dispose();
    _scrollValue.dispose();
    super.dispose();
  }
}
