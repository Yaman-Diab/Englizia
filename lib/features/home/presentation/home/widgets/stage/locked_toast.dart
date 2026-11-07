import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// «تُفتح بعد الوحدة 3» over a locked island, for a moment (design "Home
/// Archipelago", M9, map §12): its small corner at the bottom end points at
/// the island. A status for screen readers.
class LockedToast extends StatelessWidget {
  const LockedToast({required this.text, super.key});

  final String text;

  /// From the island's end edge, and above its top.
  static const inset = 20.0;
  static const lift = 30.0;

  static const _radius = Radius.circular(14);
  static const _corner = Radius.circular(4);
  static const _shadow = .1;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: const BorderRadiusDirectional.only(
            topStart: _radius,
            topEnd: _radius,
            bottomStart: _radius,
            bottomEnd: _corner,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: _shadow),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          text,
          style: context.texts
              .sized(
                context.texts.captionStrong,
                size: 13,
                line: 20,
                running: false,
              )
              .copyWith(color: colors.textPrimary),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}
