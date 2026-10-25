import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:flutter/material.dart';

/// Temporary destination for buttons whose screen is not built yet, so the
/// flow can be walked on a device. Each use is a row in docs/STATUS.md.
class PendingPage extends StatelessWidget {
  const PendingPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.screenGutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mascot(expression: MascotExpression.focused, size: 120),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'pending_body'.tr(),
                textAlign: TextAlign.center,
                style: context.texts.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
