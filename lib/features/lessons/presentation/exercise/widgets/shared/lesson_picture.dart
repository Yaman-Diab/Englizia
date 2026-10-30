import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A picture from the server, on a soft circle. Mock lessons name bundled files.
class LessonPicture extends StatelessWidget {
  const LessonPicture({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary.surface,
          shape: BoxShape.circle,
        ),
        child: url.startsWith('http')
            ? Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, image, progress) =>
                    progress == null ? image : const AppSpinner(),
                errorBuilder: (context, _, _) => Center(
                  child: AppIconView(
                    AppIcon.infoCircle,
                    color: colors.textSecondary,
                  ),
                ),
              )
            : SvgPicture.asset(url),
      ),
    );
  }
}
