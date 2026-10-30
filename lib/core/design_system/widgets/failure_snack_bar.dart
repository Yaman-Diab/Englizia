import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:flutter/material.dart';

/// Shows why an action failed in the error band (designs "Save Progress",
/// "Create Account"), replacing any bar already shown, with a retry when
/// [onRetry] is given (it then stays until used). What the learner typed
/// stays where it was.
void showFailureSnackBar(
  BuildContext context,
  Failure failure, {
  VoidCallback? onRetry,
}) => showNoticeSnackBar(
  context,
  icon: failure is NetworkFailure ? AppIcon.wifiOff : AppIcon.errorCircle,
  text: failure.localizedMessage,
  tone: context.colors.error,
  action: onRetry == null ? null : ('common_retry'.tr(), onRetry),
);

/// A short message in a [tone]'s band, replacing any bar already shown:
/// something done, or something to know.
void showNoticeSnackBar(
  BuildContext context, {
  required AppIcon icon,
  required String text,
  required ToneColors tone,
  Duration duration = const Duration(seconds: 4),
  (String, VoidCallback)? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tone.surface,
        duration: duration,
        content: Row(
          children: [
            AppIconView(icon, size: _iconSize, color: tone.text),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                style: context.texts.bodyStrong.copyWith(color: tone.text),
              ),
            ),
          ],
        ),
        action: switch (action) {
          (final label, final onPressed) => SnackBarAction(
            label: label,
            textColor: tone.text,
            onPressed: onPressed,
          ),
          null => null,
        },
      ),
    );
}

const _iconSize = 20.0;
