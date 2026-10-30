import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/swap.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/clip_progress_ring.dart';
import 'package:englizia/features/placement/presentation/test/cubit/placement_test_cubit.dart';
import 'package:flutter/material.dart';

/// A listening question's player: a big button, a ring that fills for the
/// clip's length, and how many listens are left, in words as well as dots. When
/// the clip can't play, a failure with a retry that doesn't use up a listen.
class ListeningBlock extends StatelessWidget {
  const ListeningBlock({
    required this.audio,
    required this.playsLeft,
    required this.maxPlays,
    required this.clipLength,
    required this.playCount,
    required this.onToggle,
    super.key,
  });

  final PlacementAudio audio;
  final int playsLeft;
  final int maxPlays;
  final Duration clipLength;
  final int playCount;
  final VoidCallback onToggle;

  static const _button = 96.0;
  static const _ring = 108.0;
  static const _failedIcon = 40.0;
  static const _exhaustedOpacity = .38;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    if (audio == PlacementAudio.failed) {
      return Column(
        children: [
          Container(
            width: _button,
            height: _button,
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
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              'placement_audio_failed'.tr(),
              style: texts.bodyStrong.copyWith(color: colors.textPrimary),
            ),
          ),
          TextButton(onPressed: onToggle, child: Text('common_retry'.tr())),
        ],
      );
    }
    final playing = audio == PlacementAudio.playing;
    final exhausted = playsLeft <= 0;
    final status = exhausted
        ? 'placement_plays_done'.plural(maxPlays)
        : 'placement_plays_left'.plural(playsLeft);
    return Column(
      children: [
        SizedBox.square(
          dimension: _button,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (playing)
                PositionedDirectional(
                  start: (_button - _ring) / 2,
                  top: (_button - _ring) / 2,
                  child: ClipProgressRing(
                    key: ValueKey(playCount),
                    length: clipLength,
                    size: _ring,
                  ),
                ),
              AnimatedOpacity(
                opacity: exhausted ? _exhaustedOpacity : 1,
                duration: AppMotion.resolve(context, AppMotion.quick),
                child: IconButton(
                  onPressed: exhausted || audio == PlacementAudio.loading
                      ? null
                      : onToggle,
                  tooltip: playing
                      ? 'placement_play_stop'.tr()
                      : exhausted
                      ? status
                      : 'placement_play'.tr(),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.info.fill,
                    disabledBackgroundColor: colors.info.fill,
                    foregroundColor: colors.surface,
                    disabledForegroundColor: colors.surface,
                    fixedSize: const Size.square(_button),
                  ),
                  iconSize: AppSizes.iconLg,
                  icon: audio == PlacementAudio.loading
                      ? AppSpinner(size: 32, color: colors.surface)
                      : Icon(
                          playing
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Swap(
                  child: Text(
                    status,
                    key: ValueKey(status),
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            for (var i = 0; i < maxPlays; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              _Dot(on: i < playsLeft),
            ],
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.on});

  final bool on;

  static const _size = 8.0;
  static const _stroke = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.quick),
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? colors.info.fill : Colors.transparent,
          border: Border.all(
            color: on ? colors.info.fill : colors.border,
            width: _stroke,
          ),
        ),
      ),
    );
  }
}
