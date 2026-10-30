import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// The guide in its soft circle, a little above the middle (designs "Placement
/// Intro" and "Placement Question").
class GuideCircle extends StatelessWidget {
  const GuideCircle({required this.child, super.key});

  final Widget child;

  static const guideSize = 120.0;
  static const _circle = 136.0;
  static const _lift = 8.0;

  @override
  Widget build(BuildContext context) => Container(
    width: _circle,
    height: _circle,
    padding: const EdgeInsetsDirectional.only(bottom: _lift),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.colors.primary.surface,
      shape: BoxShape.circle,
    ),
    child: child,
  );
}
