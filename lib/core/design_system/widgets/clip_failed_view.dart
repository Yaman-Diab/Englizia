import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:flutter/material.dart';

/// A clip that couldn't play: says so, and offers a retry. It never stops the
/// answer, so it is information, not an error.
class ClipFailedView extends StatelessWidget {
  const ClipFailedView({
    required this.circle,
    required this.iconSize,
    required this.gap,
    required this.onRetry,
    super.key,
  });

  final double circle;
  final double iconSize;

  /// Between the icon and the text.
  final double gap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          width: circle,
          height: circle,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.info.surface,
            shape: BoxShape.circle,
          ),
          child: AppIconView(
            AppIcon.volumeOff,
            size: iconSize,
            color: colors.info.fill,
          ),
        ),
        SizedBox(height: gap),
        Semantics(
          liveRegion: true,
          child: Text(
            'audio_failed'.tr(),
            style: context.texts.bodyStrong.copyWith(color: colors.textPrimary),
          ),
        ),
        TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
      ],
    );
  }
}
