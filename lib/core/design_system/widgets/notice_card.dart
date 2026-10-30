import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:flutter/material.dart';

/// A card with something to know: a refused sign-in ([error]), a wait, a
/// tip, what is left of a test ([primary]). Information unless told otherwise.
/// Read out as soon as it appears; [announcement] (the minutes left) is its
/// spoken value, read out each time it changes and never shown.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    required this.icon,
    required this.title,
    this.detail,
    this.error = false,
    this.primary = false,
    this.announcement,
    super.key,
  });

  final AppIcon icon;
  final String title;
  final String? detail;
  final bool error;
  final bool primary;
  final String? announcement;

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final tone = error
        ? colors.error
        : primary
        ? colors.primary
        : colors.info;
    return Semantics(
      container: true,
      liveRegion: true,
      value: announcement,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                child: AppIconView(icon, size: _iconSize, color: tone.fill),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: texts.bodyStrong.copyWith(
                        color: primary ? colors.textPrimary : tone.text,
                      ),
                    ),
                    if (detail case final detail?)
                      Text(
                        detail,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
