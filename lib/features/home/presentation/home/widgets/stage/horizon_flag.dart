import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:flutter/material.dart';

/// «المستوى التالي: B1» on the horizon (design "Home Archipelago", map §11): a
/// pill on a short pole standing on the horizon line. One item of the map's
/// list for screen readers.
///
/// ASSUMPTION(design): a solid 1 frame, as the markup draws it; the board's
/// checklist says dashed (D10).
class HorizonFlag extends StatelessWidget {
  const HorizonFlag({required this.text, super.key});

  final String text;

  /// The pill, and the pole under it down to the horizon and past it.
  static const pill = 36.0;
  static const pole = 22.0;

  /// The flag's top stands this far above the horizon line.
  static const rise = pill;

  static const _icon = 16.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outline = context.scheme.outline;
    return Semantics(
      label: text,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: pill,
              padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(pill / 2),
                border: Border.all(color: outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconView(
                    AppIcon.unitFlag,
                    color: colors.textSecondary,
                    size: _icon,
                  ),
                  const SizedBox(width: _gap),
                  Text(
                    text,
                    style: context.texts.captionStrong.copyWith(
                      height: 1,
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 2,
              height: pole,
              child: ColoredBox(color: outline),
            ),
          ],
        ),
      ),
    );
  }
}
