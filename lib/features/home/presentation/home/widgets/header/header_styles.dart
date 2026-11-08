import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:flutter/material.dart';

/// A tap target of the header: at least 48 with [margin] around a smaller
/// drawing, so the drawing keeps the design's size. [builder] draws it,
/// pressed or not; [pressScale] shrinks it while pressed (not under reduce
/// motion).
class HeaderTap extends StatelessWidget {
  const HeaderTap({
    required this.label,
    required this.onTap,
    required this.builder,
    this.margin = EdgeInsets.zero,
    this.pressScale = 1,
    super.key,
  });

  /// What a screen reader says: the button's text or purpose.
  final String label;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool pressed) builder;
  final EdgeInsetsGeometry margin;
  final double pressScale;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // Pressed from anywhere in the target, the margin as well.
      child: PressScale.builder(
        scale: pressScale,
        duration: AppMotion.homePress,
        builder: (context, pressed) =>
            Padding(padding: margin, child: builder(context, pressed)),
      ),
    ),
  );
}
