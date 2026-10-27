import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:flutter/material.dart';

/// Shows why an action failed in the error band (designs "Save Progress",
/// "Create Account"), replacing any bar already shown, with a retry when
/// [onRetry] is given. What the learner typed stays where it was.
void showFailureSnackBar(
  BuildContext context,
  Failure failure, {
  VoidCallback? onRetry,
}) {
  final error = context.colors.error;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error.surface,
        content: Row(
          children: [
            AppIconView(
              failure is NetworkFailure ? AppIcon.wifiOff : AppIcon.errorCircle,
              size: _iconSize,
              color: error.text,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                failure.localizedMessage,
                style: context.texts.bodyStrong.copyWith(color: error.text),
              ),
            ),
          ],
        ),
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: 'common_retry'.tr(),
                textColor: error.text,
                onPressed: onRetry,
              ),
      ),
    );
}

const _iconSize = 20.0;
