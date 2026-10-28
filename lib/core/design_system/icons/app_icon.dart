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
  ),
  seedling(
    '<path d="M12 20.5v-8"/>'
    '<path d="M12 13c0-3.6-2.6-6.2-6.6-6.2 0 3.6 2.6 6.2 6.6 6.2z"/>'
    '<path d="M12 11c0-3.2 2.2-5.8 6.2-5.8 0 3.2-2.2 5.8-6.2 5.8z"/>'
    '<path d="M6.5 20.5h11"/>',
  ),
  wifiOff(
    '<path d="M3 3l18 18"/>'
    '<path d="M8.5 16.2a5 5 0 0 1 6.6-.4"/>'
    '<path d="M5 12.6a10 10 0 0 1 4.6-2.5"/>'
    '<path d="M14.6 10.3A10 10 0 0 1 19 12.6"/>'
    '<path d="M2 8.9a15 15 0 0 1 3.7-2.5"/>'
    '<path d="M10.4 5.1A15 15 0 0 1 22 8.9"/>'
    '<path d="M12 20h.01"/>',
  ),
  clock(
    '<circle cx="12" cy="12" r="9"/>'
    '<path d="M12 7.5V12l3 2"/>',
  ),
  steps(
    '<path d="M21 20h-5.5v-5h-5v-5H5V5H3"/>'
    '<path d="M3 20h18"/>',
  ),
  sunrise(
    '<path d="M12 2v7"/>'
    '<path d="M8.5 5.5L12 2l3.5 3.5"/>'
    '<path d="M4.9 10.9l1.4 1.4M19.1 10.9l-1.4 1.4M2 18h2M20 18h2M22 22H2"/>'
    '<path d="M16 18a4 4 0 0 0-8 0"/>',
  ),
  sun(
    '<circle cx="12" cy="12" r="4"/>'
    '<path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2'
    'M20 12h2M6.3 17.7l-1.4 1.4M19.1 4.9l-1.4 1.4"/>',
  ),
  moon('<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9z"/>'),
  bellOff(
    '<path d="M8.7 3A6 6 0 0 1 18 8a21.3 21.3 0 0 0 .6 5"/>'
    '<path d="M17 17H3s3-2 3-9a4.7 4.7 0 0 1 .3-1.7"/>'
    '<path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>'
    '<path d="M2 2l20 20"/>',
  ),
  chevronDown('<path d="M6 9l6 6 6-6"/>'),
  flame(
    '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 '
    '2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 '
    '1-3a2.5 2.5 0 0 0 2.5 2.5z"/>',
  ),
  target(
    '<circle cx="12" cy="12" r="9"/>'
    '<circle cx="12" cy="12" r="5"/>'
    '<path d="M12 12h.01"/>',
  ),
  child(
    '<circle cx="12" cy="12" r="9"/>'
    '<path d="M8.5 14a4 4 0 0 0 7 0"/>'
    '<path d="M9 9.5h.01M15 9.5h.01"/>',
  ),
  route(
    '<circle cx="6" cy="19" r="2.5"/>'
    '<path d="M8.5 19H17a3.5 3.5 0 0 0 0-7H7a3.5 3.5 0 0 1 0-7h8.5"/>'
    '<circle cx="18" cy="5" r="2.5"/>',
  ),
  mail(
    '<rect x="2.5" y="5" width="19" height="14" rx="2.5"/>'
    '<path d="M3 7l9 6 9-6"/>',
  ),
  person(
    '<circle cx="12" cy="8" r="4"/>'
    '<path d="M4 21a8 8 0 0 1 16 0"/>',
  ),
  phone(
    '<rect x="6" y="2.5" width="12" height="19" rx="2.5"/>'
    '<path d="M11 18h2"/>',
  ),
  check('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  cross('<path d="M7 7l10 10M17 7L7 17"/>'),
  lock(
    '<rect x="4.5" y="10.5" width="15" height="10.5" rx="2.5"/>'
    '<path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
  ),
  eye(
    '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/>'
    '<circle cx="12" cy="12" r="3"/>',
  ),
  eyeOff(
    '<path d="M10.7 5.1A10.7 10.7 0 0 1 12 5c6.4 0 10 7 10 7a17.6 17.6 0 0 1-2.6 3.5"/>'
    '<path d="M6.6 6.6C3.8 8.4 2 12 2 12s3.6 7 10 7a9.7 9.7 0 0 0 5.4-1.6"/>'
    '<path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>'
    '<path d="M2 2l20 20"/>',
  ),
  personCheck(
    '<circle cx="12" cy="8" r="4"/>'
    '<path d="M4 21a8 8 0 0 1 13.5-5.8"/>'
    '<path d="M16.5 19.5l2 2 3.5-4"/>',
  ),

  /// The three marks of a field's message: wrong, right, not yet.
  errorCircle(
    '<circle cx="12" cy="12" r="9"/>'
    '<path d="M9 9l6 6M15 9l-6 6"/>',
  ),
  checkCircle(
    '<circle cx="12" cy="12" r="9"/>'
    '<path d="M8 12.5l2.8 2.8L16.5 9.5"/>',
  ),
  circle('<circle cx="12" cy="12" r="8.5"/>'),
  questionCircle(
    '<circle cx="12" cy="12" r="9"/>'
    '<path d="M9.6 9.3a2.5 2.5 0 0 1 4.8.9c0 1.7-2.4 2.2-2.4 3.6"/>'
    '<path d="M12 17.2v.1"/>',
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
