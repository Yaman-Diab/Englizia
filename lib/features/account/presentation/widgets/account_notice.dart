import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:flutter/material.dart';

/// A card in an account screen: a refused sign-in ([error]), the wait after
/// too many tries, a tip. Read out as soon as it appears; [announcement]
/// (the minutes left) is its spoken value, read out each time it changes
/// and never shown.
class AccountNotice extends StatelessWidget {
  const AccountNotice({
    required this.icon,
    required this.title,
    this.detail,
    this.error = false,
    this.announcement,
    super.key,
  });

  final AppIcon icon;
  final String title;
  final String? detail;
  final bool error;
  final String? announcement;

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final tone = error ? colors.error : colors.info;
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
                      style: texts.bodyStrong.copyWith(color: tone.text),
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
