import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

/// The app button, built on Material buttons for semantics, focus and ripple.
/// Disabled while [isLoading] or when [onPressed] is null.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final callback = isLoading ? null : onPressed;
    final Widget content = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    final iconWidget = icon == null || isLoading ? null : Icon(icon);

    final button = switch (variant) {
      AppButtonVariant.primary =>
        iconWidget == null
            ? FilledButton(onPressed: callback, child: content)
            : FilledButton.icon(
                onPressed: callback,
                icon: iconWidget,
                label: content,
              ),
      AppButtonVariant.secondary =>
        iconWidget == null
            ? OutlinedButton(onPressed: callback, child: content)
            : OutlinedButton.icon(
                onPressed: callback,
                icon: iconWidget,
                label: content,
              ),
      AppButtonVariant.text =>
        iconWidget == null
            ? TextButton(onPressed: callback, child: content)
            : TextButton.icon(
                onPressed: callback,
                icon: iconWidget,
                label: content,
              ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
