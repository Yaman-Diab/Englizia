import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

/// The way back over a cover picture: it sits on the picture, not the page,
/// so it stays light in both themes (design "Unit").
class PictureBackButton extends StatelessWidget {
  const PictureBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    const colors = AppSemanticColors.light;
    return Semantics(
      button: true,
      label: 'common_back'.tr(),
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: _size,
            child: Icon(
              Icons.arrow_back_rounded,
              size: AppSizes.iconMd - 2,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
