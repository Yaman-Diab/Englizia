import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's own line icons, drawn exactly as in the approved designs (Claude
/// Design "Onboarding Option"): 24×24, 2px stroke, round caps and joins.
/// Material icons stay for generic controls (back, check); anything the
/// designs draw themselves lives here, so a designer's icon is one entry.
///
/// An icon is added when the screen that uses it is built.
enum AppIcon {
  chat(
    '<path d="M4 4h9a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2H8.5L5 16v-3H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z"/>'
    '<path d="M18.5 8.5H20a2 2 0 0 1 2 2V15a2 2 0 0 1-2 2h-1v3l-3.5-3H12a2 2 0 0 1-2-2v-.5"/>',
  ),
  sparkle(
    '<path d="M11 4.5l1.9 4.8 4.8 1.9-4.8 1.9L11 18l-1.9-4.9-4.8-1.9 4.8-1.9z"/>'
    '<path d="M19 2.5v4M17 4.5h4M19 16.5v3M17.5 18h3"/>',
  ),
  graduationCap(
    '<path d="M2 9l10-5 10 5-10 5z"/>'
    '<path d="M6 11.2V16c0 1.4 2.7 3 6 3s6-1.6 6-3v-4.8"/>'
    '<path d="M22 9v5.5"/>',
  ),
  plane(
    '<path d="M17.8 19.2L16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z"/>',
  ),
  briefcase(
    '<rect x="3" y="7" width="18" height="13" rx="2.5"/>'
    '<path d="M8.5 7V5.5A2.5 2.5 0 0 1 11 3h2a2.5 2.5 0 0 1 2.5 2.5V7"/>'
    '<path d="M3 12.5h18M12 11.5v2"/>',
  ),
  examSheet(
    '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/>'
    '<path d="M14 3v5h5"/>'
    '<path d="M9 14.5l2 2 4-4.5"/>',
  );

  const AppIcon(this._shapes);

  final String _shapes;

  /// The SVG document; strokes are black and tinted when drawn.
  String get svg =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="#000000" stroke-width="2" '
      'stroke-linecap="round" stroke-linejoin="round">$_shapes</svg>';
}

/// Draws an [AppIcon] in [color]. Decorative: screen readers skip it, so the
/// label next to it carries the meaning.
class AppIconView extends StatelessWidget {
  const AppIconView(
    this.icon, {
    required this.color,
    this.size = defaultSize,
    super.key,
  });

  final AppIcon icon;
  final Color color;
  final double size;

  static const defaultSize = 24.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.string(
        icon.svg,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
