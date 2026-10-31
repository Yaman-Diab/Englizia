import 'dart:math' as math;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// A word card going from one place to another.
final class ChipMove {
  const ChipMove({required this.from, required this.to, required this.face});

  /// Slot ids, as given to [ChipStageState.slot].
  final String from;
  final String to;

  /// What flies, drawn to fill whatever size it has on the way.
  final Widget face;
}

/// Where word cards fly: a card measures where it is, the answer changes, and
/// then it travels on an arc to where it landed, over everything, while what
/// it left behind closes up. Nothing but the flight repaints, and no state
/// outside this widget changes per frame. Under reduce motion a card just
/// fades in where it landed.
class ChipStage extends StatefulWidget {
  const ChipStage({required this.builder, super.key});

  final Widget Function(BuildContext context, ChipStageState stage) builder;

  @override
  State<ChipStage> createState() => ChipStageState();
}

class ChipStageState extends State<ChipStage> with TickerProviderStateMixin {
  static const _placedPrefix = 'placed:';
  static const _arc = 22.0;
  static const _growth = .05;

  final _keys = <String, GlobalKey>{};
  final _hidden = <String>{};
  final _flights = <_Flight>[];
  final _fading = <String>{};
  var _closing = <String, Offset>{};

  late final _closeUp = AnimationController(
    vsync: this,
    duration: AppMotion.closeUp,
    value: 1,
  );
  late final _fade = AnimationController(
    vsync: this,
    duration: AppMotion.stepOutReduced + AppMotion.stagger,
    value: 1,
  );
  late final _motion = Listenable.merge([_closeUp, _fade]);

  /// Slot [id] holds a card that hasn't landed yet.
  bool isHidden(String id) => _hidden.contains(id);

  /// The placed slot of a card.
  static String placed(String chipId) => '$_placedPrefix$chipId';

  /// The bank slot of a card.
  static String bank(String chipId) => 'bank:$chipId';

  /// A place a card can be measured at. With [hideContent], the content stays
  /// invisible until its card lands; without it, the caller asks [isHidden]
  /// and draws the empty place itself.
  Widget slot(String id, Widget child, {bool hideContent = true}) =>
      AnimatedBuilder(
        animation: _motion,
        builder: (_, child) {
          final away = _closing[id];
          return Transform.translate(
            offset: away == null ? Offset.zero : away * (1 - _closeUp.value),
            child: Opacity(
              opacity: hideContent && _hidden.contains(id)
                  ? 0
                  : _fading.contains(id)
                  ? _fade.value
                  : 1,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: _keys.putIfAbsent(id, GlobalKey.new),
          child: child,
        ),
      );

  /// Runs [apply], which changes the answer, and flies [moves].
  void move(List<ChipMove> moves, VoidCallback apply) {
    final reduce = AppMotion.reduceMotion(context);
    final before = _rects();
    if (!reduce) setState(() => _hidden.addAll(moves.map((m) => m.to)));
    apply();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _land(moves, before, reduce: reduce);
    });
  }

  void _land(
    List<ChipMove> moves,
    Map<String, Rect> before, {
    required bool reduce,
  }) {
    final after = _rects();
    if (reduce) {
      _fading
        ..clear()
        ..addAll(moves.map((m) => m.to));
      _fade.forward(from: 0);
      return;
    }
    setState(() {
      for (final move in moves) {
        final from = before[move.from];
        final to = after[move.to];
        if (from == null || to == null) {
          _hidden.remove(move.to);
        } else {
          _fly(move, from, to);
        }
      }
      final landing = {for (final move in moves) move.to};
      _closing = {
        for (final entry in after.entries)
          if (entry.key.startsWith(_placedPrefix) &&
              !landing.contains(entry.key) &&
              before[entry.key] != null &&
              before[entry.key]!.topLeft != entry.value.topLeft)
            entry.key: before[entry.key]!.topLeft - entry.value.topLeft,
      };
    });
    if (_closing.isNotEmpty) _closeUp.forward(from: 0);
  }

  void _fly(ChipMove move, Rect from, Rect to) {
    final controller = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
    );
    final flight = _Flight(
      controller: controller,
      progress: CurvedAnimation(parent: controller, curve: AppMotion.out),
      from: from,
      to: to,
      face: move.face,
    );
    _flights.add(flight);
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _flights.remove(flight);
        _hidden.remove(move.to);
      });
      flight.dispose();
    });
  }

  Map<String, Rect> _rects() {
    final stage = context.findRenderObject();
    if (stage is! RenderBox) return const {};
    return {
      for (final MapEntry(:key, :value) in _keys.entries)
        if (value.currentContext?.findRenderObject() case final RenderBox box
            when box.attached && box.hasSize)
          key: box.localToGlobal(Offset.zero, ancestor: stage) & box.size,
    };
  }

  @override
  void dispose() {
    for (final flight in _flights) {
      flight.dispose();
    }
    _closeUp.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      widget.builder(context, this),
      for (final flight in _flights)
        AnimatedBuilder(
          animation: flight.progress,
          builder: (_, face) {
            final t = flight.progress.value;
            final lift = math.sin(math.pi * t);
            return Positioned.fromRect(
              rect: Rect.lerp(
                flight.from,
                flight.to,
                t,
              )!.shift(Offset(0, -_arc * lift)),
              child: Transform.scale(scale: 1 + _growth * lift, child: face),
            );
          },
          child: IgnorePointer(
            child: RepaintBoundary(child: ExcludeSemantics(child: flight.face)),
          ),
        ),
    ],
  );
}

final class _Flight {
  _Flight({
    required this.controller,
    required this.progress,
    required this.from,
    required this.to,
    required this.face,
  });

  final AnimationController controller;
  final CurvedAnimation progress;
  final Rect from;
  final Rect to;
  final Widget face;

  void dispose() {
    progress.dispose();
    controller.dispose();
  }
}
