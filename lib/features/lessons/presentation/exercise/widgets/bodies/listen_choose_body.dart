import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/listening_motion.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/clip_failed_view.dart';
import 'package:englizia/core/design_system/widgets/clip_progress_ring.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_card.dart';
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
  static const _spinner = 32.0;
  static const _failed = 72.0;
  static const _failedIcon = 34.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (clip.status == ClipStatus.failed) {
      return ClipFailedView(
        circle: _failed,
        iconSize: _failedIcon,
        gap: AppSpacing.sm,
        onRetry: clip.onToggle,
      );
    }
    final playing = clip.status == ClipStatus.playing;
    return SizedBox(
      height: _height,
      child: CustomMultiChildLayout(
        delegate: _PlayerLayout(Directionality.of(context)),
        children: [
          LayoutId(
            id: _PlayerSlot.play,
            child: SizedBox.square(
              dimension: _ring,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  ListeningWaves(
                    active: playing,
                    size: _button,
                    count: 2,
                    growth: .55,
                    opacity: .32,
                    filled: true,
                    duration: AppMotion.characterFloatLively,
                  ),
                  if (playing)
                    ClipProgressRing(
                      key: ValueKey(clip.playCount),
                      length: clip.length,
                      size: _ring,
                    ),
                  IconButton(
                    onPressed: clip.status == ClipStatus.loading
                        ? null
                        : clip.onToggle,
                    tooltip: playing
                        ? 'lesson_stop_audio'.tr()
                        : 'lesson_listen'.tr(),
                    isSelected: playing,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.info.fill,
                      disabledBackgroundColor: colors.info.fill,
                      foregroundColor: colors.surface,
                      fixedSize: const Size.square(_button),
                    ),
                    iconSize: _playIcon,
                    icon: clip.status == ClipStatus.loading
                        ? AppSpinner(size: _spinner, color: colors.surface)
                        : Icon(
                            playing
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  ),
                ],
              ),
            ),
          ),
          LayoutId(
            id: _PlayerSlot.slow,
            child: _SlowButton(on: playing && clip.slow, onTap: clip.onSlow),
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

/// Plays the same clip slower: tinted while it does, and said to be on.
class _SlowButton extends StatelessWidget {
  const _SlowButton({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  static const _minHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'lesson_listen_slow'.tr(),
      selected: on,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.quick),
                constraints: const BoxConstraints(minHeight: _minHeight),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: on ? colors.info.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: colors.info.fill, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconView(
                      AppIcon.stopwatch,
                      size: AppSizes.iconSm,
                      color: colors.info.text,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'lesson_slower'.tr(),
                      style: context.texts.captionStrong.copyWith(
                        color: colors.info.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
