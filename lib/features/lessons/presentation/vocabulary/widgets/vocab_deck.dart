import 'dart:math' as math;

import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/widgets/vocab_card.dart';
import 'package:flutter/material.dart';

/// The cards one over the other, the next one's edge showing behind (design
/// "Vocab Lesson"). The next card lies towards the end of the app's direction, so
/// in Arabic «التالي» sends the top card off to the right and dragging it there
/// does the same; dragging the other way brings the previous one back. A drag
/// short of a third of the width springs back. The buttons stay the main way.
class VocabDeck extends StatefulWidget {
  const VocabDeck({
    required this.index,
    required this.count,
    required this.cardAt,
    required this.onNext,
    required this.onPrevious,
    super.key,
  });

  final int index;
  final int count;

  /// The top card for its index; behind it, a card is only seen.
  final Widget Function(int index, {required bool top}) cardAt;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  State<VocabDeck> createState() => _VocabDeckState();
}

enum _Move { forward, back }

class _VocabDeckState extends State<VocabDeck> with TickerProviderStateMixin {
  static const _behindScale = AppMotion.scaleLarge;
  static const _behindDrop = AppMotion.distanceBase;
  static const _flyShare = 1.3;
  static const _returnShare = 1.2;
  static const _flyTurn = 6 * math.pi / 180;

  /// Degrees of turn for each pixel dragged.
  static const _dragTurn = math.pi / 180 / 25;
  static const _threshold = 1 / 3;

  late final _swap = AnimationController(
    vsync: this,
    duration: AppMotion.cardSwap,
  );
  late final _settle = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
  );
  _Move? _move;
  int? _outgoing;
  double _outFrom = 0;
  double _dx = 0;
  double _settleFrom = 0;

  @override
  void didUpdateWidget(VocabDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final forward = widget.index > oldWidget.index;
    _move = forward ? _Move.forward : _Move.back;
    _outgoing = forward ? oldWidget.index : null;
    _outFrom = _dx;
    _dx = 0;
    _settle.stop();
    _swap
      ..duration = AppMotion.reduceMotion(context)
          ? AppMotion.quick
          : AppMotion.cardSwap
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _swap.dispose();
    _settle.dispose();
    super.dispose();
  }

  /// Towards the next card: right in Arabic, left in English.
  double get _side =>
      Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;

  void _dragEnd(double width) {
    final towardsNext = _dx * _side;
    if (towardsNext > width * _threshold) {
      widget.onNext();
    } else if (-towardsNext > width * _threshold && widget.index > 0) {
      widget.onPrevious();
    } else {
      _settleFrom = _dx;
      _dx = 0;
      _settle.forward(from: 0);
    }
  }

  /// Where a card springing back is now.
  double get _springing =>
      _settleFrom * (1 - AppMotion.smoothOut.transform(_settle.value));

  Matrix4 _pose(double x, double turn, {double y = 0, double scale = 1}) =>
      Matrix4.translationValues(x, y, 0)
        ..rotateZ(turn)
        ..scaleByDouble(scale, scale, 1, 1);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      return AnimatedBuilder(
        animation: Listenable.merge([_swap, _settle]),
        builder: (context, _) {
          final reduce = AppMotion.reduceMotion(context);
          final moving = _swap.isAnimating ? _move : null;
          final t = _swap.value;
          final dragged = _settle.isAnimating ? _springing : _dx;
          final next = widget.index + 1;
          final outgoing = moving == _Move.forward ? _outgoing : null;

          Widget behind(int index, double opacity) => Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: _behindScale,
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: const Offset(0, _behindDrop),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(VocabCard.radius),
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: double.infinity,
                          child: widget.cardAt(index, top: false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          final Matrix4 topPose;
          var topOpacity = 1.0;
          if (reduce && moving != null) {
            topPose = Matrix4.identity();
            topOpacity = t;
          } else if (moving == _Move.forward) {
            final e = AppMotion.smoothOut.transform(t);
            topPose = Matrix4.translationValues(0, _behindDrop * (1 - e), 0)
              ..scaleByDouble(
                _behindScale + (1 - _behindScale) * e,
                _behindScale + (1 - _behindScale) * e,
                1,
                1,
              );
          } else if (moving == _Move.back) {
            final e = 1 - AppMotion.smoothOut.transform(t);
            topPose = _pose(
              _side * width * _returnShare * e,
              _side * _flyTurn * e,
            );
          } else {
            topPose = _pose(dragged, dragged * _dragTurn);
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (next < widget.count)
                behind(
                  next,
                  moving == _Move.forward && !reduce
                      ? const Interval(.4, 1).transform(t)
                      : 1,
                ),
              GestureDetector(
                onHorizontalDragUpdate: moving != null
                    ? null
                    : (details) => setState(() {
                        if (_settle.isAnimating) {
                          _dx = _springing;
                          _settle.stop();
                        }
                        _dx += details.delta.dx;
                      }),
                onHorizontalDragEnd: moving != null
                    ? null
                    : (_) => _dragEnd(width),
                child: Opacity(
                  opacity: topOpacity,
                  child: Transform(
                    transform: topPose,
                    alignment: moving == _Move.forward
                        ? Alignment.bottomCenter
                        : Alignment.center,
                    child: widget.cardAt(widget.index, top: true),
                  ),
                ),
              ),
              if (outgoing != null)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: reduce
                          ? Opacity(
                              opacity: 1 - t,
                              child: widget.cardAt(outgoing, top: false),
                            )
                          : Transform(
                              alignment: Alignment.center,
                              transform: () {
                                final e = AppMotion.inOut.transform(t);
                                final x =
                                    _outFrom +
                                    (_side * width * _flyShare - _outFrom) * e;
                                final from = _outFrom * _dragTurn;
                                return _pose(
                                  x,
                                  from + (_side * _flyTurn - from) * e,
                                );
                              }(),
                              child: widget.cardAt(outgoing, top: false),
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}
