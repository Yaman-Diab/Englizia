import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

/// [large] is the main call to action of a hero screen (welcome, onboarding).
enum AppButtonSize { regular, large }

/// The app button, built on Material buttons for semantics, focus and ripple.
/// Disabled while [isLoading] or when [onPressed] is null.
///
/// Every button in the app waits the same way: while [isLoading] it keeps
/// its size and full color, takes no taps, and its label crossfades into an
/// [AppSpinner] in the label's color. Buttons outside this widget wrap their
/// label in [ButtonLoadingLabel] to match.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.size = AppButtonSize.regular,
    this.focusNode,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final AppButtonSize size;

  /// To move the focus to the button, e.g. when it appears.
  final FocusNode? focusNode;

  static const _largeHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final callback = isLoading ? null : onPressed;
    final content = ButtonLoadingLabel(
      isLoading: isLoading,
      spinnerSize: size == AppButtonSize.large
          ? AppSpinner.buttonSize
          : AppSpinner.compactSize,
      child: Text(label),
    );
    // While loading, the button may hide its icon but not change size.
    final iconWidget = icon == null
        ? null
        : Opacity(opacity: isLoading ? 0 : 1, child: Icon(icon));
    final sizeStyle = size == AppButtonSize.large
        ? ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
              Size(AppSizes.minTapTarget, _largeHeight),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          )
        : null;
    final style = isLoading
        ? _enabledLook(context).merge(sizeStyle)
        : sizeStyle;

    final button = switch (variant) {
      AppButtonVariant.primary =>
        iconWidget == null
            ? FilledButton(
                onPressed: callback,
                focusNode: focusNode,
                style: style,
                child: content,
              )
            : FilledButton.icon(
                onPressed: callback,
                focusNode: focusNode,
                style: style,
                icon: iconWidget,
                label: content,
              ),
      AppButtonVariant.secondary =>
        iconWidget == null
            ? OutlinedButton(
                onPressed: callback,
                focusNode: focusNode,
                style: style,
                child: content,
              )
            : OutlinedButton.icon(
                onPressed: callback,
                focusNode: focusNode,
                style: style,
                icon: iconWidget,
                label: content,
              ),
      AppButtonVariant.text =>
        iconWidget == null
            ? TextButton(
                onPressed: callback,
                focusNode: focusNode,
                style: style,
                child: content,
              )
            : TextButton.icon(
                onPressed: callback,
                focusNode: focusNode,
                style: style,
                icon: iconWidget,
                label: content,
              ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  /// The variant's enabled colors, so a loading button does not fade like a
  /// disabled one.
  ButtonStyle _enabledLook(BuildContext context) {
    final theme = Theme.of(context);
    final themed = switch (variant) {
      AppButtonVariant.primary => theme.filledButtonTheme.style,
      AppButtonVariant.secondary => theme.outlinedButtonTheme.style,
      AppButtonVariant.text => theme.textButtonTheme.style,
    };
    const enabled = <WidgetState>{};
    return ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(
        themed?.backgroundColor?.resolve(enabled),
      ),
      foregroundColor: WidgetStatePropertyAll(
        themed?.foregroundColor?.resolve(enabled),
      ),
      side: WidgetStatePropertyAll(themed?.side?.resolve(enabled)),
    );
  }
}

/// A button's label that becomes an [AppSpinner] while [isLoading], without
/// changing the button's size: the label keeps its space, hidden, and the
/// spinner takes the label's color.
class ButtonLoadingLabel extends StatelessWidget {
  const ButtonLoadingLabel({
    required this.isLoading,
    required this.child,
    this.spinnerSize = AppSpinner.buttonSize,
    super.key,
  });

  final bool isLoading;
  final Widget child;
  final double spinnerSize;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.resolve(context, AppMotion.quick);
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: isLoading ? 0 : 1,
          duration: duration,
          curve: AppMotion.out,
          child: ExcludeSemantics(excluding: isLoading, child: child),
        ),
        // Laid out only while needed: a spinner taller than the label must
        // not grow the button.
        if (isLoading)
          Positioned.fill(
            child: OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxHeight: spinnerSize,
              maxWidth: spinnerSize,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: duration,
                curve: AppMotion.out,
                builder: (context, value, spinner) =>
                    Opacity(opacity: value, child: spinner),
                child: AppSpinner(
                  size: spinnerSize,
                  semanticLabel: 'common_loading'.tr(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
