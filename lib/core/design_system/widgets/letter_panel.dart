import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// A word with no picture: its first letter, large, on a soft panel.
class LetterPanel extends StatelessWidget {
  const LetterPanel({required this.word, this.size = 96, super.key});

  final String word;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final display = context.texts.display;
    return ColoredBox(
      color: colors.primary.surface,
      child: Center(
        child: Text(
          word.characters.first,
          textDirection: TextDirection.ltr,
          style: display.copyWith(
            fontSize: display.fontSize! * size / 28,
            height: 1,
            color: colors.primary.fill,
          ),
        ),
      ),
    );
  }
}
