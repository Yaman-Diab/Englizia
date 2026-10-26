import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:flutter/material.dart';

/// One answer card of an onboarding question (design "Onboarding Option"):
/// a leading [art] (56) or [mark] (40) in a circle, a title, an optional
/// description and a radio check.
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
    this.description,
    this.soonLabel,
    super.key,
  }) : assert(mark != null || art != null, 'Give a mark or an art');

  final String? mark;
  final Widget? art;
  final String title;
  final String? description;
  final bool selected;
  final VoidCallback? onTap;
  final String? soonLabel;

  static const _minHeight = 64.0;
  static const _markSize = 40.0;
  static const _artSize = 56.0;
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
                  ChoiceCheck(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(BuildContext context) {
    final background = context.scheme.surfaceContainerHigh;
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

/// «قريبًا»: neutral on purpose, because amber is reserved for rewards.
class _SoonBadge extends StatelessWidget {
  const _SoonBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topEnd,
      widthFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xxs,
            vertical: AppSpacing.xxs,
          ),
          child: Text(
            label,
            style: context.texts.captionStrong.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
