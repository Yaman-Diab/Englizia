import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// One grade in the grade grid: the number large, its name below, a check
/// in the corner when chosen. A radio in the grid's group.
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
  static const _selectedTint = .08;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final selection = colors.primary.text;

    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected
              ? Color.alphaBlend(
                  selection.withValues(alpha: _selectedTint),
                  colors.surface,
                )
              : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: selected
                ? BorderSide(color: selection, width: 2)
                : BorderSide(color: context.scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
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
                                    ? selection
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
                  if (selected)
                    PositionedDirectional(
                      top: _checkInset,
                      start: _checkInset,
                      child: Container(
                        width: _checkSize,
                        height: _checkSize,
                        decoration: BoxDecoration(
                          color: selection,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: AppSizes.iconSm - 4,
                          color: colors.surface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
