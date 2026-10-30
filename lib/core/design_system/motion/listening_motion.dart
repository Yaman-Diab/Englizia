import 'dart:math' as math;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// Rebuilds with the progress of a repeating cycle while [active]; stays at
/// the start when not, and under reduce motion.
class _Loop extends StatefulWidget {
  const _Loop({
    required this.active,
    required this.duration,
    required this.builder,
  });

  final bool active;
  final Duration duration;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  void _sync() {
    if (widget.active && !AppMotion.reduceMotion(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating || _controller.value != 0) {
      _controller.value = 0;
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Loop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

/// The guide nodding along while [active].
class ListeningNod extends StatelessWidget {
  const ListeningNod({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  /// Four degrees each way, from near its feet (design).
  static const _angle = 4 * math.pi / 180;
  static const _pivot = Alignment(0, .8);

  @override
  Widget build(BuildContext context) => _Loop(
    active: active,
    duration: AppMotion.characterNod,
    builder: (_, progress) => Transform.rotate(
      angle: _angle * math.sin(progress * 2 * math.pi),
      alignment: _pivot,
      child: child,
    ),
  );
}

/// Waves leaving a button of [size] while [active]: rings by default, or
/// [filled] discs for a stronger pulse. [count] of them, evenly apart.
class ListeningWaves extends StatelessWidget {
  const ListeningWaves({
    required this.active,
    required this.size,
    this.count = 3,
    this.growth = .9,
    this.opacity = .55,
    this.filled = false,
    this.duration = AppMotion.characterPulse,
    super.key,
  });

  final bool active;
  final double size;
  final int count;

  /// How much bigger a wave ends, 0.9 being 90%.
  final double growth;

  /// How strong a wave starts.
  final double opacity;
  final bool filled;
  final Duration duration;

  static const _stroke = 2.0;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.info.fill;
    if (!active || AppMotion.reduceMotion(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: _Loop(
        active: active,
        duration: duration,
        builder: (_, progress) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < count; i++)
              _wave((progress + i / count) % 1, color),
          ],
        ),
      ),
    );
  }

  Widget _wave(double phase, Color color) => Transform.scale(
    scale: 1 + growth * AppMotion.smoothOut.transform(phase),
    child: Opacity(
      opacity: opacity * (1 - phase),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : null,
          border: filled ? null : Border.all(color: color, width: _stroke),
        ),
      ),
    ),
  );
}
