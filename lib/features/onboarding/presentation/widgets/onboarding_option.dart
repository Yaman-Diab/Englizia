import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:flutter/material.dart';

/// One answer card of an onboarding question (design "Onboarding Option"):
/// a leading [art] (56) or [mark] (40) in a circle or an [icon] in a tile,
/// a title, an optional description and the check (radio, or checkbox when
/// [multiple]).
///
/// Disabled when [onTap] is null. With [soonLabel] the card is "coming soon":
/// dashed, faded, badged and never selectable.
class OnboardingOption extends StatelessWidget {
  const OnboardingOption({
    required this.title,
    required this.selected,
    required this.onTap,
    this.mark,
    this.art,
    this.icon,
    this.iconTone = TileTone.blue,
    this.description,
    this.soonLabel,
    this.multiple = false,
    super.key,
  }) : assert(
         mark != null || art != null || icon != null,
         'Give a mark, an art or an icon',
       );

  final String? mark;
  final Widget? art;
  final AppIcon? icon;

  /// Color of the icon tile; only used with [icon].
  final TileTone iconTone;
  final bool multiple;
  final String title;
  final String? description;
  final bool selected;
  final VoidCallback? onTap;
  final String? soonLabel;

  static const _minHeight = 64.0;
  static const _markSize = 40.0;
  static const _artSize = 56.0;
  static const _tileRadius = 10.0;
  static const _iconSize = 22.0;
  static const _disabledOpacity = .45;
  static const _soonContentOpacity = .55;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final soon = soonLabel != null;

    final content = Row(
      children: [
        ExcludeSemantics(child: _leading(context)),
        const SizedBox(width: AppSpacing.md + AppSpacing.xxs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: texts.bodyStrong),
              if (description case final description?)
                Text(
                  description,
                  style: texts.caption.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );

    return Opacity(
      opacity: onTap == null && !soon ? _disabledOpacity : 1,
      child: ChoiceSurface(
        selected: selected && !soon,
        onTap: soon ? null : onTap,
        dashed: soon,
        multiple: multiple,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: soon
                      ? Opacity(opacity: _soonContentOpacity, child: content)
                      : content,
                ),
                const SizedBox(width: AppSpacing.md),
                if (soonLabel case final label?)
                  _SoonBadge(label: label)
                else
                  ChoiceCheck(selected: selected, multiple: multiple),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(BuildContext context) {
    final background = context.scheme.surfaceContainerHigh;
    if (icon case final icon?) {
      final tile = context.colors.tiles.of(iconTone);
      return Container(
        width: _markSize,
        height: _markSize,
        decoration: BoxDecoration(
          color: tile.background,
          borderRadius: BorderRadius.circular(_tileRadius),
        ),
        alignment: Alignment.center,
        child: AppIconView(icon, size: _iconSize, color: tile.icon),
      );
    }
    if (art case final art?) {
      return Container(
        width: _artSize,
        height: _artSize,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: art,
      );
    }
    return Container(
      width: _markSize,
      height: _markSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        mark!,
        style: context.texts.bodyStrong.copyWith(
          color: context.colors.selection,
          height: 1,
        ),
      ),
    );
  }
}

/// «قريبًا»: amber pill, as in the designs.
class _SoonBadge extends StatelessWidget {
  const _SoonBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final badge = context.colors.soonBadge;
    return Align(
      alignment: AlignmentDirectional.topEnd,
      widthFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: badge.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xxs,
            vertical: AppSpacing.xxs,
          ),
          child: Text(
            label,
            style: context.texts.captionStrong.copyWith(color: badge.text),
          ),
        ),
      ),
    );
  }
}
