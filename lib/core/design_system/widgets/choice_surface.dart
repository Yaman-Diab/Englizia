import 'dart:ui' show PathMetric;

import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

enum ChoiceShape {
  /// Rounded card: selection is a 2px border over a faint tint.
  card,

  /// Stadium pill: selection fills it with the button color.
  pill,
}

/// One answer of a mutually exclusive group (a radio): the selected look,
/// press feedback and screen-reader semantics, around the caller's content.
/// Disabled when [onTap] is null; [dashed] marks a choice that is not
/// offered yet.
class ChoiceSurface extends StatelessWidget {
  const ChoiceSurface({
    required this.selected,
    required this.onTap,
    required this.child,
    this.shape = ChoiceShape.card,
    this.dashed = false,
    this.multiple = false,
    this.semanticLabel,
    super.key,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;
  final ChoiceShape shape;
  final bool dashed;

  /// One of several answers that can all be chosen (a checkbox), instead of
  /// one of a mutually exclusive group (a radio).
  final bool multiple;

  /// Replaces what screen readers would read from [child].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outline = context.scheme.outlineVariant;
    final pill = shape == ChoiceShape.pill;
    final side = switch ((selected, pill, dashed)) {
      (true, true, _) => BorderSide.none,
      (true, false, _) => BorderSide(color: colors.selection, width: 2),
      (false, _, true) => BorderSide.none,
      (false, _, false) => BorderSide(color: outline),
    };
    final ShapeBorder border = pill
        ? StadiumBorder(side: side)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: side,
          );

    Widget content = semanticLabel == null
        ? child
        : ExcludeSemantics(child: child);
    content = Material(
      color: switch ((selected, pill)) {
        (true, true) => colors.primaryStrong,
        (true, false) => colors.selectionSurface,
        (false, _) => colors.surface,
      },
      shape: border,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
    if (dashed) {
      content = CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: outline,
          radius: AppRadius.lg,
        ),
        child: content,
      );
    }
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: !multiple,
        label: semanticLabel,
        child: content,
      ),
    );
  }
}

/// The selection mark of a [ChoiceSurface]: a filled check when [selected],
/// otherwise an empty ring (or nothing without [showRing]); a thinner ring
/// marks a [multiple] choice. Pops in.
class ChoiceCheck extends StatelessWidget {
  const ChoiceCheck({
    required this.selected,
    this.size = defaultSize,
    this.showRing = true,
    this.multiple = false,
    super.key,
  });

  final bool selected;
  final double size;
  final bool showRing;
  final bool multiple;

  static const defaultSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: AppMotion.resolve(context, AppMotion.medium),
        switchInCurve: AppMotion.bounce,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: selected
            ? DecoratedBox(
                key: const ValueKey(true),
                decoration: BoxDecoration(
                  color: colors.selection,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: size * 2 / 3,
                  color: colors.surface,
                ),
              )
            : showRing
            ? DecoratedBox(
                key: const ValueKey(false),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.scheme.outlineVariant,
                    width: multiple ? 1.5 : 2,
                  ),
                ),
                child: const SizedBox.expand(),
              )
            : const SizedBox.shrink(key: ValueKey(false)),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    for (final PathMetric metric in border.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
