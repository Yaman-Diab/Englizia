import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// The app's mark: the welcome badge, a notification preview. Decorative;
/// the app name beside it is what screen readers hear.
// ASSUMPTION(design): a letter in a circle until the final logo is approved
// (requirements v3.0 §26); the designs use a placeholder "A".
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({this.size = 36, super.key});

  final double size;

  /// Below this the letter uses the caption role.
  static const _smallSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = size < _smallSize
        ? context.texts.captionStrong
        : context.texts.bodyStrong;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryStrong,
          shape: BoxShape.circle,
        ),
        child: Text(
          'app_logo_mark'.tr(),
          style: style.copyWith(color: colors.onPrimaryStrong, height: 1),
        ),
      ),
    );
  }
}
