import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_card.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/lesson_picture.dart';
import 'package:flutter/material.dart';

/// A word with its sound, and four square pictures, two by two.
class ImageChoiceBody extends StatelessWidget {
  const ImageChoiceBody({
    required this.exercise,
    required this.answer,
    required this.clip,
    super.key,
  });

  final ImageChoiceExercise exercise;
  final BodyAnswer answer;
  final BodyClip clip;

  static const _columns = 2;
  static const _badgeInset = 8.0;
  static const _badge = 24.0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SpokenWord(
        word: exercise.word,
        playing: clip.status == ClipStatus.playing,
        onTap: clip.onToggle,
      ),
      const SizedBox(height: AppSpacing.xl),
      GridView.count(
        crossAxisCount: _columns,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final option in exercise.options)
            AnswerCard(
              look: answer.lookOf(option.id),
              radius: AppRadius.lg,
              semanticLabel: option.alt,
              onTap: answer.chooser(option.id),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: LessonPicture(url: option.image),
                  ),
                  PositionedDirectional(
                    top: _badgeInset,
                    end: _badgeInset,
                    child: AnswerMark(
                      look: answer.lookOf(option.id),
                      showRing: false,
                      size: _badge,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}

class _SpokenWord extends StatelessWidget {
  const _SpokenWord({
    required this.word,
    required this.playing,
    required this.onTap,
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
              locale: const Locale('en'),
              style: context.texts.title.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
