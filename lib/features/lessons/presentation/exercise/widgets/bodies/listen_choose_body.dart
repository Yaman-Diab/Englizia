import 'dart:math' as math;

import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/widgets/clip_failed_view.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_card.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/clip_button.dart';
import 'package:flutter/material.dart';

/// A clip that plays once by itself and repeats at will, and the sentences it
/// might have said.
class ListenChooseBody extends StatelessWidget {
  const ListenChooseBody({
    required this.exercise,
    required this.answer,
    required this.clip,
    super.key,
  });

  final ListenChooseExercise exercise;
  final BodyAnswer answer;
  final BodyClip clip;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Player(clip: clip),
      const SizedBox(height: AppSpacing.xl),
      TextAnswers(options: exercise.options, answer: answer),
    ],
  );
}

/// A listening question's player: the big button with its ring and waves, and
/// «أبطأ» beside it. A failure offers a retry, and never stops the answer.
class _Player extends StatelessWidget {
  const _Player({required this.clip});

  final BodyClip clip;

  static const _height = 128.0;
  static const _ring = 112.0;
  static const _button = 96.0;
  static const _playIcon = 44.0;
  static const _failed = 72.0;
  static const _failedIcon = 34.0;

  @override
  Widget build(BuildContext context) {
    if (clip.status == ClipStatus.failed) {
      return ClipFailedView(
        circle: _failed,
        iconSize: _failedIcon,
        gap: AppSpacing.sm,
        onRetry: clip.onToggle,
      );
    }
    return SizedBox(
      height: _height,
      child: CustomMultiChildLayout(
        delegate: _PlayerLayout(Directionality.of(context)),
        children: [
          LayoutId(
            id: _PlayerSlot.play,
            child: ClipButton(
              clip: clip,
              box: _ring,
              button: _button,
              icon: _playIcon,
              waves: true,
            ),
          ),
          LayoutId(
            id: _PlayerSlot.slow,
            child: SlowButton(on: clip.playingSlow, onTap: clip.onSlow),
          ),
        ],
      ),
    );
  }
}

enum _PlayerSlot { play, slow }

/// The button in the middle and the slower one at the end. Where they would
/// touch, as on a narrow phone or with large text, the big button moves over.
class _PlayerLayout extends MultiChildLayoutDelegate {
  _PlayerLayout(this.direction);

  final TextDirection direction;

  static const _gap = AppSpacing.xs;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);
    final play = layoutChild(_PlayerSlot.play, loose);
    final slow = layoutChild(_PlayerSlot.slow, loose);
    final middle = (size.width - play.width) / 2;
    final rtl = direction == TextDirection.rtl;
    final playLeft = rtl
        ? math.max(middle, slow.width + _gap)
        : math.min(middle, size.width - slow.width - _gap - play.width);
    positionChild(
      _PlayerSlot.play,
      Offset(playLeft, (size.height - play.height) / 2),
    );
    positionChild(
      _PlayerSlot.slow,
      Offset(
        rtl ? 0 : size.width - slow.width,
        (size.height - slow.height) / 2,
      ),
    );
  }

  @override
  bool shouldRelayout(_PlayerLayout oldDelegate) =>
      oldDelegate.direction != direction;
}
