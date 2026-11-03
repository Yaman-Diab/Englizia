import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ✦, the mark of what the AI does (designs "Talk", "Explain Me").
class AiSpark extends StatelessWidget {
  const AiSpark({required this.size, this.color, super.key});

  final double size;
  final Color? color;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M12 2.5c.6 4.6 2.9 6.9 7.5 7.5-4.6.6-6.9 2.9-7.5 7.5'
      '-.6-4.6-2.9-6.9-7.5-7.5 4.6-.6 6.9-2.9 7.5-7.5z" fill="#000000"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.string(
      _svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? context.colors.ai.text,
        BlendMode.srcIn,
      ),
    ),
  );
}
