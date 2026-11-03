import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An open, empty cardboard box (design "Kid Media"), drawn in its own colors
/// in both themes, as a picture is. Decorative.
class EmptyBox extends StatelessWidget {
  const EmptyBox({this.width = 140, super.key});

  final double width;

  static const _aspect = 116 / 140;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 116">'
      '<path d="M18 40h104v70H18z" fill="#D9A066"/>'
      '<path d="M18 40h104l-8-8H26z" fill="#B57A3E"/>'
      '<path d="M18 40L4 22h44l14 18zM122 40l14-18H92l-14 18z" fill="#E8B97A"/>'
      '<path d="M52 62h36" stroke="#B57A3E" stroke-width="4" '
      'stroke-linecap="round"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.string(_svg, width: width, height: width * _aspect),
  );
}
