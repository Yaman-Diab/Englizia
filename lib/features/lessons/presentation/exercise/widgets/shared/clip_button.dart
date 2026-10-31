import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/listening_motion.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/clip_progress_ring.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:flutter/material.dart';

/// The question's clip: a round button in a [box] that holds its progress ring
/// while it plays, with [waves] where the clip is the whole question.
class ClipButton extends StatelessWidget {
  const ClipButton({
    required this.clip,
    required this.box,
    required this.button,
    required this.icon,
    this.waves = false,
    super.key,
  });

  final BodyClip clip;
  final double box;
  final double button;
  final double icon;
  final bool waves;

  static const _spinnerShare = .72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final playing = clip.status == ClipStatus.playing;
    final loading = clip.status == ClipStatus.loading;
    return SizedBox.square(
      dimension: box,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (waves)
            ListeningWaves(
              active: playing,
              size: button,
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
              size: box,
            ),
          IconButton(
            onPressed: loading ? null : clip.onToggle,
            tooltip: playing ? 'lesson_stop_audio'.tr() : 'lesson_listen'.tr(),
            isSelected: playing,
            style: IconButton.styleFrom(
              padding: EdgeInsetsDirectional.zero,
              backgroundColor: colors.info.fill,
              disabledBackgroundColor: colors.info.fill,
              foregroundColor: colors.surface,
              fixedSize: Size.square(button),
            ),
            iconSize: icon,
            icon: loading
                ? AppSpinner(size: icon * _spinnerShare, color: colors.surface)
                : Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

/// Plays the same clip slower: tinted while it does, and said to be on.
class SlowButton extends StatelessWidget {
  const SlowButton({required this.on, required this.onTap, super.key});

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
