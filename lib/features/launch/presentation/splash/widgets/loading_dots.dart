import 'dart:async';
import 'dart:math' as math;

import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:flutter/material.dart';

/// Three dots that hop in turn while a slow load goes on; still under
/// reduce motion.
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  static const _dots = 3;
  static const _dot = 8.0;
  static const _rest = .45;

  /// The share of a round each dot spends rising and falling (design).
  static const _hop = .6;

  late final _round = AnimationController(
    vsync: this,
    duration: SplashIntro.dotsRound,
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

  /// 0 at rest, 1 at the top of the hop.
  double _height(int dot) {
    final offset =
        SplashIntro.dotsStagger.inMicroseconds /
        SplashIntro.dotsRound.inMicroseconds *
        dot;
    final t = (_round.value - offset) % 1;
    return t >= _hop ? 0 : math.sin(math.pi * t / _hop);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary.fill;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _round,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dots; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
              Transform.translate(
                offset: Offset(0, -AppMotion.distanceMicro * _height(i)),
                child: Container(
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    color: color.withValues(
                      alpha: _rest + (1 - _rest) * _height(i),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
