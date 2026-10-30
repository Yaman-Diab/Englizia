import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/listening_motion.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/clip_progress_ring.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _english = Locale('en');

/// A sentence with its blank. The chosen word takes the blank's place, so the
/// whole sentence reads before checking; a long one wraps inside it.
class BlankSentence extends StatelessWidget {
  const BlankSentence({required this.question, this.word, super.key});

  final Exercise question;

  /// The option chosen, if any.
  final String? word;

  static const _blankWidth = 64.0;
  static const _blankHeight = 24.0;
  static const _line = 2.0;
  static final _punctuation = RegExp(r'^[.,?!;:]');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final word = this.word;
    // Punctuation sits against a chosen word, but leaves the blank room.
    final gap = word != null && _punctuation.hasMatch(question.after)
        ? ''
        : ' ';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text.rich(
        locale: _english,
        TextSpan(
          style: texts.reading.copyWith(color: colors.textPrimary),
          children: [
            TextSpan(text: '${question.before} '),
            if (word == null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Semantics(
                  label: 'placement_blank'.tr(),
                  child: Container(
                    width: _blankWidth,
                    height: _blankHeight,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colors.border, width: _line),
                      ),
                    ),
                  ),
                ),
              )
            else
              TextSpan(
                text: word,
                style: texts.reading.copyWith(
                  // The strong weight of the same size: each weight has its
                  // own family (ADR 5).
                  fontFamily: texts.bodyStrong.fontFamily,
                  color: colors.primary.text,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.primaryStrong,
                  decorationThickness: _line,
                ),
              ),
            TextSpan(text: '$gap${question.after}'),
          ],
        ),
      ),
    );
  }
}

/// The word of an image choice, with the button that says it.
class SpokenWord extends StatelessWidget {
  const SpokenWord({
    required this.word,
    required this.playing,
    required this.onTap,
    super.key,
  });

  final String word;
  final bool playing;
  final VoidCallback onTap;

  static const _circle = 40.0;
  static const _iconSize = 20.0;
  static const _ring = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          IconButton(
            onPressed: onTap,
            tooltip: 'lesson_listen'.tr(),
            style: IconButton.styleFrom(
              padding: EdgeInsetsDirectional.zero,
              fixedSize: const Size.square(AppSizes.minTapTarget),
            ),
            icon: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.quick),
              width: _circle,
              height: _circle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.info.fill,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: playing ? colors.info.surface : Colors.transparent,
                    spreadRadius: _ring,
                  ),
                ],
              ),
              child: AppIconView(
                AppIcon.volume,
                size: _iconSize,
                color: colors.surface,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              word,
              locale: _english,
              style: context.texts.title.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A listening question's player: the big button with its ring and waves, and
/// «أبطأ» beside it. A failure offers a retry, and never stops the answer.
class ListeningPlayer extends StatelessWidget {
  const ListeningPlayer({required this.state, super.key});

  final ExerciseState state;

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
    final cubit = context.read<ExerciseCubit>();
    if (state.audio == ExerciseAudio.failed) {
      return Column(
        children: [
          Container(
            width: _failed,
            height: _failed,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.info.surface,
              shape: BoxShape.circle,
            ),
            child: AppIconView(
              AppIcon.volumeOff,
              size: _failedIcon,
              color: colors.info.fill,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              'placement_audio_failed'.tr(),
              style: context.texts.bodyStrong.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: cubit.togglePlay,
            child: Text('common_retry'.tr()),
          ),
        ],
      );
    }
    final playing = state.audio == ExerciseAudio.playing;
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
                      key: ValueKey(state.playCount),
                      length: state.clipLength,
                      size: _ring,
                    ),
                  IconButton(
                    onPressed: state.audio == ExerciseAudio.loading
                        ? null
                        : cubit.togglePlay,
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
                    icon: state.audio == ExerciseAudio.loading
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
            child: _SlowButton(
              on: playing && state.slow,
              onTap: cubit.playSlow,
            ),
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
