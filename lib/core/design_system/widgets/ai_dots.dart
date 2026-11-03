import 'dart:async';

import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// Three dots that pulse while the AI judges or a character thinks, still
/// under reduce motion.
class AiDots extends StatefulWidget {
  const AiDots({this.dot = defaultDot, super.key});

  final double dot;
  static const defaultDot = 7.0;

  @override
  State<AiDots> createState() => _AiDotsState();
}

class _AiDotsState extends State<AiDots> with SingleTickerProviderStateMixin {
  static const _dots = 3;
  static const _dimmest = .3;

  late final _round = AnimationController(
    vsync: this,
    duration: AppMotion.aiDots,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _round.stop();
    } else if (!_round.isAnimating) {
      unawaited(_round.repeat());
    }
  }

  @override
  void dispose() {
    _round.dispose();
    super.dispose();
  }

  double _strength(int dot) {
    final offset =
        AppMotion.aiDotsOffset.inMilliseconds /
        AppMotion.aiDots.inMilliseconds *
        dot;
    final t = (_round.value - offset) % 1;
    return _dimmest + (1 - _dimmest) * (1 - (2 * t - 1).abs());
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.ai.fill;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _round,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dots; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              Container(
                width: widget.dot,
                height: widget.dot,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: _strength(i)),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
