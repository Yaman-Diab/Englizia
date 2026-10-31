import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/count_up.dart';
import 'package:flutter/material.dart';

/// Points earned, everywhere the app shows them: a star and `+15 XP`, counting up
/// to the amount, and the star turning once as the count lands. Amber, as amber
/// means XP. The width stays that of the final amount, so nothing beside it moves
/// while it counts, and a screen reader only hears the amount.
class XpAmount extends StatefulWidget {
  const XpAmount({
    required this.xp,
    required this.style,
    this.starSize = AppSizes.iconSm + AppSpacing.xs,
    this.delay = Duration.zero,
    this.duration = AppMotion.countUp,
    super.key,
  });

  final int xp;

  /// The role to write it in; the color is set here.
  final TextStyle style;
  final double starSize;
  final Duration delay;
  final Duration duration;

  @override
  State<XpAmount> createState() => _XpAmountState();
}

class _XpAmountState extends State<XpAmount>
    with SingleTickerProviderStateMixin {
  static const _growth = .35;
  static const _turn = 18 * math.pi / 180;

  late final _landing = AnimationController(
    vsync: this,
    duration: AppMotion.xpLanding,
  );

  @override
  void dispose() {
    _landing.dispose();
    super.dispose();
  }

  String _label(int xp) => 'xp_gain'.tr(namedArgs: {'xp': '$xp'});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = widget.style.copyWith(
      color: colors.reward.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label: _label(widget.xp),
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _landing,
              builder: (_, star) {
                final lift = math.sin(math.pi * _landing.value);
                return Transform.rotate(
                  angle: _turn * lift,
                  child: Transform.scale(
                    scale: 1 + _growth * lift,
                    child: star,
                  ),
                );
              },
              child: Icon(
                Icons.star_rounded,
                size: widget.starSize,
                color: colors.reward.fill,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Stack(
              children: [
                Opacity(
                  opacity: 0,
                  child: Text(_label(widget.xp), style: style),
                ),
                CountUp(
                  value: widget.xp,
                  delay: widget.delay,
                  duration: widget.duration,
                  onDone: () => _landing.forward(from: 0),
                  builder: (_, shown) => Text(_label(shown), style: style),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
