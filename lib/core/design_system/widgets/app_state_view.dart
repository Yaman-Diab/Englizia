import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:flutter/material.dart';

enum _StateKind { loading, error, empty }

/// Loading / error / empty placeholder for a screen or a section.
/// A section announces its state; it never silently disappears.
class AppStateView extends StatelessWidget {
  const AppStateView.loading({super.key})
    : _kind = _StateKind.loading,
      message = null,
      onRetry = null,
      icon = null;

  const AppStateView.error({
    required String this.message,
    required VoidCallback this.onRetry,
    super.key,
  }) : _kind = _StateKind.error,
       icon = Icons.error_outline;

  const AppStateView.empty({
    required String this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  }) : _kind = _StateKind.empty,
       onRetry = null;

  final _StateKind _kind;
  final String? message;
  final VoidCallback? onRetry;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (_kind == _StateKind.loading) {
      return Center(
        child: AppSpinner(
          size: AppSpinner.pageSize,
          color: context.colors.primary.fill,
          semanticLabel: 'common_loading'.tr(),
        ),
      );
    }

    final colors = context.colors;
    final iconColor = _kind == _StateKind.error
        ? colors.error.text
        : colors.textSecondary;
    final retry = onRetry;

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconLg, color: iconColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? '',
              textAlign: TextAlign.center,
              style: context.texts.body.copyWith(color: colors.textSecondary),
            ),
            if (retry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'common_retry'.tr(),
                onPressed: retry,
                variant: AppButtonVariant.secondary,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
