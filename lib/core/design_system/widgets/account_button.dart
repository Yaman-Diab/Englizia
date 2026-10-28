import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// One way into an account (Google, Apple, email): a full-width outlined
/// button with the provider's mark at its start and the label in the
/// middle, as the designs draw them. No option looks primary: they are
/// equal choices. [badge] marks the way used last time («آخر دخول لك»), on
/// the button's edge.
class AccountButton extends StatelessWidget {
  const AccountButton({
    required this.label,
    required this.mark,
    required this.onPressed,
    this.badge,
    super.key,
  });

  final String label;
  final Widget mark;

  /// Null disables the button (offline, or another way is in progress).
  final VoidCallback? onPressed;
  final String? badge;

  static const _height = 56.0;
  static const _markInset = 18.0;
  static const _markSize = 22.0;

  /// The badge sits half over the button's top border.
  static const _badgeLift = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = OutlinedButton(
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
    final badge = this.badge;
    if (badge == null) return button;
    return Semantics(
      // Read with the button: "Continue with Google, last used".
      hint: badge,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: _badgeLift),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            button,
            PositionedDirectional(
              top: -_badgeLift,
              end: AppSpacing.lg,
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    // A ring in the page color parts it from the border.
                    border: Border.all(color: colors.background, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Text(
                      badge,
                      style: context.texts.captionStrong.copyWith(
                        color: colors.primary.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
