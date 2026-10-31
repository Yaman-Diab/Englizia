import 'package:flutter/widgets.dart';

/// The line under a word of a sentence: solid, or dotted.
class WordLine extends CustomPainter {
  const WordLine({required this.color, required this.dotted});

  final Color color;
  final bool dotted;

  static const _dot = 2.0;
  static const _gap = 3.0;
  static const _stroke = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - _stroke / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = _stroke;
    if (!dotted) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (var x = 0.0; x < size.width; x += _dot + _gap) {
      canvas.drawLine(Offset(x, y), Offset(x + _dot, y), paint);
    }
  }

  @override
  bool shouldRepaint(WordLine oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dotted != dotted;
}
