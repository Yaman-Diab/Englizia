import 'package:englizia/core/design_system/app_semantic_colors.dart';
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
    this.success = false,
    this.emphasis,
    this.trailing,
    this.announcement,
    super.key,
  });

  final AppIcon icon;
  final String title;
  final String? detail;
  final bool error;
  final bool primary;
  final bool success;

  /// The part of [title] that matters most (a level): the rest of the title
  /// turns lighter so that it stands out.
  final String? emphasis;

  /// An action at its end, such as a retry.
  final Widget? trailing;
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
        : success
        ? colors.success
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
                    _title(context, tone),
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
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context, ToneColors tone) {
    final texts = context.texts;
    final color = primary ? context.colors.textPrimary : tone.text;
    final strong = texts.bodyStrong.copyWith(color: color);
    final parts = emphasis == null ? [title] : title.split(emphasis!);
    if (parts.length != 2) return Text(title, style: strong);
    return Text.rich(
      TextSpan(
        style: texts.body.copyWith(color: color),
        children: [
          TextSpan(text: parts.first),
          TextSpan(text: emphasis, style: strong),
          TextSpan(text: parts.last),
        ],
      ),
    );
  }
}
