import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/dashed_border.dart';
import 'package:flutter/material.dart';

enum ChoiceShape {
  /// Rounded card: selection is a 2px border over a faint tint.
  card,

  /// Stadium pill: selection fills it with the button color.
  pill,
}

/// What checking found, shown by color and the mark's icon together.
enum ChoiceMark { correct, wrong }

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
    this.mark,
    this.radius = AppRadius.lg,
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

  /// Overrides the selected look once the answer is checked.
  final ChoiceMark? mark;

  /// Of a card.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outline = context.scheme.outlineVariant;
    final tone = switch (mark) {
      ChoiceMark.correct => colors.success,
      ChoiceMark.wrong => colors.error,
      null => null,
    };
    final pill = shape == ChoiceShape.pill;
    final side = switch ((selected, pill, dashed)) {
      _ when tone != null => BorderSide(color: tone.fill, width: 2),
      (true, true, _) => BorderSide.none,
      (true, false, _) => BorderSide(color: colors.selection, width: 2),
      (false, _, true) => BorderSide.none,
      (false, _, false) => BorderSide(color: outline),
    };
    final ShapeBorder border = pill
        ? StadiumBorder(side: side)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: side,
          );

    Widget content = semanticLabel == null
        ? child
        : ExcludeSemantics(child: child);
    content = Material(
      color: switch ((selected, pill)) {
        _ when tone != null => tone.surface,
        (true, true) => colors.primaryStrong,
        (true, false) => colors.selectionSurface,
        (false, _) => colors.surface,
      },
      shape: border,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
    if (dashed) {
      content = DashedBorder(color: outline, radius: radius, child: content);
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
/// marks a [multiple] choice. A [mark] shows what checking found. Pops in.
class ChoiceCheck extends StatelessWidget {
  const ChoiceCheck({
    required this.selected,
    this.size = defaultSize,
    this.showRing = true,
    this.multiple = false,
    this.mark,
    super.key,
  });

  final bool selected;
  final double size;
  final bool showRing;
  final bool multiple;
  final ChoiceMark? mark;

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
        child: selected || mark != null
            ? DecoratedBox(
                key: ValueKey(mark ?? true),
                decoration: BoxDecoration(
                  color: switch (mark) {
                    ChoiceMark.correct => colors.success.fill,
                    ChoiceMark.wrong => colors.error.fill,
                    null => colors.selection,
                  },
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  mark == ChoiceMark.wrong
                      ? Icons.close_rounded
                      : Icons.check_rounded,
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

/// The mark of one choice among several: a ring, with a dot when [selected].
class ChoiceRadio extends StatelessWidget {
  const ChoiceRadio({required this.selected, super.key});

  final bool selected;

  static const _size = 20.0;
  static const _dot = 10.0;
  static const _stroke = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = AppMotion.resolve(context, AppMotion.quick);
    return AnimatedContainer(
      duration: duration,
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.selection : colors.border,
          width: _stroke,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: duration,
        curve: AppMotion.bounce,
        child: Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(
            color: colors.selection,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
