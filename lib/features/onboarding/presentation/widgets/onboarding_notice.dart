import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:flutter/material.dart';

/// How a notice reads: [info] for a state that blocks an action ("the test
/// needs a connection"), [neutral] for a quiet fact ("notifications are
/// off").
enum NoticeTone { info, neutral }

/// An icon and a line in a soft band, under or above an onboarding
/// question's answers. Announced to screen readers when it appears.
class OnboardingNotice extends StatelessWidget {
  const OnboardingNotice({
    required this.icon,
    required this.text,
    this.tone = NoticeTone.info,
    super.key,
  });

  final AppIcon icon;
  final String text;
  final NoticeTone tone;

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, style) = switch (tone) {
      NoticeTone.info => (
        colors.info.surface,
        colors.info.text,
        context.texts.captionStrong,
      ),
      NoticeTone.neutral => (
        colors.tiles.of(TileTone.neutral).background,
        colors.textSecondary,
        context.texts.caption,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xxs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
                child: AppIconView(icon, size: _iconSize, color: foreground),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(text, style: style.copyWith(color: foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
