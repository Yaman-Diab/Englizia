import 'dart:math' as math;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/material.dart';

/// [role] at the design's [size] and [line] height. Arabic running text keeps
/// the role's own height when it is taller (the theme's 1.7 minimum for
/// diacritics), so a wrapped line never clips (plan §5.4).
TextStyle headerText(
  BuildContext context,
  TextStyle role, {
  required double size,
  required double line,
}) {
  final design = line / size;
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  return role.copyWith(
    fontSize: size,
    height: arabic ? math.max(design, role.height ?? design) : design,
  );
}

/// A tap target of the header: at least 48 with [margin] around a smaller
/// drawing, so the drawing keeps the design's size. [builder] draws it,
/// pressed or not; [pressScale] shrinks it while pressed (not under reduce
/// motion).
class HeaderTap extends StatefulWidget {
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
  State<HeaderTap> createState() => _HeaderTapState();
}

class _HeaderTapState extends State<HeaderTap> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (pressed != _pressed && mounted) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed && !AppMotion.reduceMotion(context)
        ? widget.pressScale
        : 1.0;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: Padding(
          padding: widget.margin,
          child: AnimatedScale(
            scale: scale,
            duration: AppMotion.homePress,
            curve: AppMotion.out,
            child: widget.builder(context, _pressed),
          ),
        ),
      ),
    );
  }
}
