import 'dart:ui' show PathMetric;

import 'package:englizia/core/design_system/app_motion.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// One answer card of an onboarding question (design "Onboarding Option"):
/// a leading [art] (56) or [mark] (40) in a circle, a title, an optional
/// description and a radio indicator.
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
  static const _indicatorSize = 24.0;
  static const _selectedTint = .08;
  static const _disabledOpacity = .45;
  static const _soonContentOpacity = .55;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final soon = soonLabel != null;
    final isSelected = selected && !soon;
    final selection = colors.primary.text;
    final outline = context.scheme.outlineVariant;
    final radius = BorderRadius.circular(AppRadius.lg);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: isSelected
          ? BorderSide(color: selection, width: 2)
          : soon
          ? BorderSide.none
          : BorderSide(color: outline),
    );

    final content = Row(
      children: [
        ExcludeSemantics(child: _leading(context, selection)),
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
      child: MergeSemantics(
        child: Semantics(
          checked: isSelected,
          inMutuallyExclusiveGroup: true,
          child: CustomPaint(
            foregroundPainter: soon
                ? _DashedBorderPainter(color: outline, radius: AppRadius.lg)
                : null,
            child: Material(
              color: isSelected
                  ? Color.alphaBlend(
                      selection.withValues(alpha: _selectedTint),
                      colors.surface,
                    )
                  : colors.surface,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: soon ? null : onTap,
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
                              ? Opacity(
                                  opacity: _soonContentOpacity,
                                  child: content,
                                )
                              : content,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        if (soonLabel case final label?)
                          _SoonBadge(label: label)
                        else
                          _Indicator(selected: isSelected, color: selection),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(BuildContext context, Color selection) {
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
        style: context.texts.bodyStrong.copyWith(color: selection, height: 1),
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

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = OnboardingOption._indicatorSize;
    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: AppMotion.resolve(context, AppMotion.medium),
        switchInCurve: AppMotion.bounce,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: selected
            ? DecoratedBox(
                key: const ValueKey(true),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  Icons.check_rounded,
                  size: AppSizes.iconSm,
                  color: context.colors.surface,
                ),
              )
            : DecoratedBox(
                key: const ValueKey(false),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.scheme.outlineVariant,
                    width: 2,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    for (final PathMetric metric in border.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
