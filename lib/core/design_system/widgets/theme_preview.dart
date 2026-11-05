import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

/// A tiny screen drawn in a theme's own colors, whatever the app's is now:
/// light, dark, or both halves for "as the phone is" (design "Settings").
class ThemePreview extends StatelessWidget {
  const ThemePreview({required this.mode, super.key});

  final ThemeMode mode;

  static Widget _screen(AppSemanticColors palette) => ColoredBox(
    color: palette.background,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final short in [false, true, false]) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: short ? .7 : 1,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: palette.border.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
          const Spacer(),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: palette.primaryStrong,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => switch (mode) {
    ThemeMode.light => _screen(AppSemanticColors.light),
    ThemeMode.dark => _screen(AppSemanticColors.dark),
    ThemeMode.system => Row(
      children: [
        Expanded(child: ClipRect(child: _screen(AppSemanticColors.light))),
        Expanded(child: ClipRect(child: _screen(AppSemanticColors.dark))),
      ],
    ),
  };
}
