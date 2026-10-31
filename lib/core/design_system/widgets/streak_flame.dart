import 'dart:math' as math;

import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The streak's flame, in the one color that means the streak. With
/// [celebrateAfter] it swells once and two sparks jump from it, for the moment
/// the day's goal is reached. Decorative: the words beside it say the same.
class StreakFlame extends StatelessWidget {
  const StreakFlame({
    required this.size,
    this.celebrateAfter,
    this.inner = true,
    super.key,
  });

  final double size;
  final Duration? celebrateAfter;

  /// The light heart of the flame, too fine to draw when it is small.
  final bool inner;

  static const _sparksAfter = Duration(milliseconds: 120);
  static const _sparksApart = Duration(milliseconds: 90);
  static const _swell = .3;
  static const _big = 10.0;
  static const _small = 7.0;
  static const _sparkAbove = 4.0;
  static const _sparkSide = 6.0;

  String _svg(Color flame, Color heart) {
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="${hex(flame)}" d="M12 2.5c.8 3.3 4.8 5.6 4.8 10.6a4.8 4.8 0 0 1-9.6 0c0-2 .9-3.4 1.9-4.4.1 1.8.9 2.8 1.9 3-1-2.9 0-6 1-9.2z"/>'
        '${inner ? '<path fill="${hex(heart)}" fill-opacity=".55" d="M12 13.2c.6 1.4 1.9 2 1.9 3.6a1.9 1.9 0 0 1-3.8 0c0-.9.4-1.5 1-2"/>' : ''}'
        '</svg>';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final flame = SvgPicture.string(
      _svg(colors.streak.fill, colors.surface),
      width: size,
      height: size,
    );
    final after = celebrateAfter;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: after == null
            ? flame
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  TimedValue(
                    delay: after,
                    duration: AppMotion.characterNod ~/ 2,
                    builder: (_, value) => Transform.scale(
                      scale: 1 + _swell * math.sin(math.pi * value),
                      child: flame,
                    ),
                  ),
                  PositionedDirectional(
                    top: -_sparkAbove,
                    end: -_sparkSide,
                    child: _Spark(size: _big, after: after + _sparksAfter),
                  ),
                  PositionedDirectional(
                    top: _sparkSide,
                    start: -_small,
                    child: _Spark(
                      size: _small,
                      after: after + _sparksAfter + _sparksApart,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.size, required this.after});

  final double size;
  final Duration after;

  static const _duration = Duration(milliseconds: 380);
  static const _peak = 1.2;
  static const _rest = .9;

  @override
  Widget build(BuildContext context) => TimedValue(
    delay: after,
    duration: _duration,
    builder: (_, value) {
      final scale = value < .5
          ? _peak * value * 2
          : _peak + (_rest - _peak) * (value - .5) * 2;
      return Transform.scale(
        scale: scale,
        child: Icon(
          Icons.auto_awesome,
          size: size,
          color: context.colors.streak.fill,
        ),
      );
    },
  );
}
