import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/play_sound.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:flutter/material.dart';

/// The star that keeps a word in the word bank: amber once saved, swelling with
/// four sparks flying from it. [raised] sits it on a picture, on a white circle
/// with a light shadow instead of a ring.
class SaveStar extends StatefulWidget {
  const SaveStar({
    required this.saved,
    required this.onTap,
    this.raised = false,
    super.key,
  });

  final bool saved;
  final VoidCallback onTap;
  final bool raised;

  @override
  State<SaveStar> createState() => _SaveStarState();
}

class _SaveStarState extends State<SaveStar> {
  static const _circle = 40.0;
  static const _spark = 6.0;
  static const _reach = 22.0;
  static const _swell = .3;
  static const _sparks = 4;
  static const _shadow = .18;

  var _saves = 0;

  void _tap() {
    if (!widget.saved) {
      setState(() => _saves++);
      AppHaptics.lightImpact();
      playSound(AppSound.saveWord);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final saved = widget.saved;
    final reward = colors.reward.fill;
    return Semantics(
      container: true,
      button: true,
      selected: saved,
      label: saved ? 'reader_saved'.tr() : 'reader_save'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: SizedBox.square(
          dimension: AppSizes.minTapTarget,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (_saves > 0 && !AppMotion.reduceMotion(context))
                TimedValue(
                  key: ValueKey(_saves),
                  delay: Duration.zero,
                  duration: AppMotion.pairLock,
                  builder: (_, value) => Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < _sparks; i++)
                        Transform.translate(
                          offset: Offset.fromDirection(
                            (i * 90 + 45) * math.pi / 180,
                            _reach * value,
                          ),
                          child: Opacity(
                            opacity: 1 - value,
                            child: Container(
                              width: _spark,
                              height: _spark,
                              decoration: BoxDecoration(
                                color: reward,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Container(
                width: _circle,
                height: _circle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.raised ? colors.surface : null,
                  border: widget.raised
                      ? null
                      : Border.all(color: context.scheme.outline),
                  boxShadow: widget.raised
                      ? [
                          BoxShadow(
                            color: context.scheme.shadow.withValues(
                              alpha: _shadow,
                            ),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: TimedValue(
                  key: ValueKey('star:$_saves'),
                  delay: Duration.zero,
                  duration: AppMotion.fast,
                  builder: (_, value) => Transform.scale(
                    scale: 1 + _swell * math.sin(math.pi * value),
                    child: Icon(
                      saved ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: AppSizes.iconMd,
                      color: saved ? reward : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
