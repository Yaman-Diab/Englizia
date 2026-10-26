import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:flutter/material.dart';

/// One grade in the grade grid: the number large, its name below, a check
/// in the corner when chosen.
class GradeCell extends StatelessWidget {
  const GradeCell({
    required this.number,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final int number;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _height = 88.0;
  static const _checkSize = 18.0;
  static const _checkInset = 7.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;

    return ChoiceSurface(
      selected: selected,
      onTap: onTap,
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        '$number',
                        style: texts.display.copyWith(
                          color: selected
                              ? colors.selection
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              top: _checkInset,
              start: _checkInset,
              child: ChoiceCheck(
                selected: selected,
                size: _checkSize,
                showRing: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
