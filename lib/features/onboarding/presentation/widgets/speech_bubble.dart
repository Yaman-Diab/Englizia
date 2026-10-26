import 'dart:math' as math;

import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// What the guide says, in a bubble whose tail points back to the guide at
/// the start side. Screen readers announce changes to [text].
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({required this.text, super.key});

  final String text;

  static const _radius = 18.0;
  static const _tailSize = 12.0;

  /// The tail's center sits on the bubble edge, this far above the bottom.
  static const _tailFromBottom = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final edge = BorderSide(color: context.scheme.outlineVariant);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.fromBorderSide(edge),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md + AppSpacing.xxs,
            ),
            child: Semantics(
              liveRegion: true,
              child: SizedBox(
                width: double.infinity,
                child: Text(text, style: context.texts.bodyStrong),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: -_tailSize / 2 - 1,
          bottom: _tailFromBottom,
          child: Transform.rotate(
            // Turns the square so its two bordered sides face the guide.
            angle: (isRtl ? -1 : 1) * math.pi / 4,
            child: Container(
              width: _tailSize,
              height: _tailSize,
              decoration: BoxDecoration(
                color: colors.surface,
                border: BorderDirectional(start: edge, bottom: edge),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
