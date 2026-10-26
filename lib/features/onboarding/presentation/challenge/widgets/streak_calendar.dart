import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/pulse.dart';
import 'package:englizia/core/design_system/motion/swap.dart';
import 'package:flutter/material.dart';

/// A desk calendar showing the chosen number of days beside the streak
/// flame (design "Streak Challenge"). The number swaps and the flame beats
/// when the choice changes. Shrinks with short screens and hides when it
/// would be too small to read; decorative, the answers say the same.
class StreakCalendar extends StatelessWidget {
  const StreakCalendar({required this.days, super.key});

  final int days;

  static const _width = 136.0;
  static const _height = 128.0;
  static const _topGap = AppSpacing.sm;

  /// At most a quarter of the screen's height.
  static const _screenShare = .25;

  /// Below this scale the calendar is left out.
  static const _minScale = .4;

  static const _bandHeight = 28.0;
  static const _holeSize = 8.0;
  static const _holesGap = 48.0;
  static const _flameSize = 32.0;
  static const _numberWidth = 66.0;
  static const _numberHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final height = (_height + _topGap).clamp(
      0.0,
      MediaQuery.sizeOf(context).height * _screenShare,
    );
    if ((height - _topGap) / _height < _minScale) return const SizedBox();

    final colors = context.colors;
    final streak = colors.streak;
    final card = Container(
      width: _width,
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
        boxShadow: [
          if (Theme.of(context).brightness == Brightness.light)
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: .06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: _bandHeight,
            color: streak.fill,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _hole(colors.surface),
                const SizedBox(width: _holesGap),
                _hole(colors.surface),
              ],
            ),
          ),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Pulse(
                    trigger: days,
                    alignment: const Alignment(0, .8),
                    child: AppIconView(
                      AppIcon.flame,
                      size: _flameSize,
                      color: streak.text,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: _numberWidth,
                    height: _numberHeight,
                    child: Swap(
                      // A fixed box, so the number scales up to fill it.
                      child: SizedBox(
                        key: ValueKey(days),
                        width: _numberWidth,
                        height: _numberHeight,
                        child: FittedBox(
                          child: Text(
                            '$days',
                            style: context.texts.display.copyWith(
                              color: streak.text,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final full = height >= _height + _topGap;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: _topGap),
          // Scaled only when it must shrink.
          child: full
              ? Center(child: card)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.topCenter,
                  child: card,
                ),
        ),
      ),
    );
  }

  static Widget _hole(Color color) => Container(
    width: _holeSize,
    height: _holeSize,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
