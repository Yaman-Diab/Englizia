import 'package:englizia/core/design_system/app_motion.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// One answer card of an onboarding question (design "Onboarding Option"):
/// a mark in a circle, a title, an optional description and a radio
/// indicator. Disabled when [onTap] is null.
class OnboardingOption extends StatelessWidget {
  const OnboardingOption({
    required this.mark,
    required this.title,
    required this.selected,
    required this.onTap,
    this.description,
    super.key,
  });

  final String mark;
  final String title;
  final String? description;
  final bool selected;
  final VoidCallback? onTap;

  static const _minHeight = 64.0;
  static const _markSize = 40.0;
  static const _indicatorSize = 24.0;
  static const _selectedTint = .08;
  static const _disabledOpacity = .45;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final selection = colors.primary.text;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: selected
          ? BorderSide(color: selection, width: 2)
          : BorderSide(color: context.scheme.outlineVariant),
    );

    return Opacity(
      opacity: onTap == null ? _disabledOpacity : 1,
      child: MergeSemantics(
        child: Semantics(
          checked: selected,
          inMutuallyExclusiveGroup: true,
          child: Material(
            color: selected
                ? Color.alphaBlend(
                    selection.withValues(alpha: _selectedTint),
                    colors.surface,
                  )
                : colors.surface,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minHeight),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Container(
                          width: _markSize,
                          height: _markSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.scheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            mark,
                            style: texts.bodyStrong.copyWith(
                              color: selection,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
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
                                style: texts.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _Indicator(selected: selected, color: selection),
                    ],
                  ),
                ),
              ),
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
