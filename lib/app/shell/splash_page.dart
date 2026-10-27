import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:flutter/material.dart';

/// Shown while the session bootstraps; the router leaves it automatically.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'app_name'.tr(),
              style: context.texts.display.copyWith(
                color: context.colors.primary.text,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppSpinner(
              size: AppSpinner.pageSize,
              color: context.colors.primary.fill,
              semanticLabel: 'common_loading'.tr(),
            ),
          ],
        ),
      ),
    );
  }
}
