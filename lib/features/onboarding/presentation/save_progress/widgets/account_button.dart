import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// One way to create the account (Google, Apple, email): a full-width
/// outlined button with the provider's mark at its start and the label in
/// the middle, as the designs draw them. No option looks primary: they are
/// equal choices.
class AccountButton extends StatelessWidget {
  const AccountButton({
    required this.label,
    required this.mark,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Widget mark;

  /// Null disables the button (offline, or another way is in progress).
  final VoidCallback? onPressed;

  static const _height = 56.0;
  static const _markInset = 18.0;
  static const _markSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(_height),
        padding: EdgeInsets.zero,
        foregroundColor: colors.textPrimary,
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: context.texts.bodyStrong,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            start: _markInset,
            child: SizedBox.square(
              dimension: _markSize,
              child: Opacity(
                opacity: onPressed == null ? .4 : 1,
                child: Center(child: mark),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: _markInset + _markSize + AppSpacing.sm,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
