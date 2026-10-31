import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/fading_scroll.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:flutter/material.dart';

/// The text of a reading, pinned over its questions: its sound, its title, and a
/// way to read it on the whole screen. It scrolls inside itself, and keeps where
/// the learner left it from one question to the next.
class PassageCard extends StatefulWidget {
  const PassageCard({required this.exercise, required this.clip, super.key});

  final ReadingExercise exercise;
  final BodyClip clip;

  static const _screenShare = .4;
  static const _maxHeight = 320.0;

  /// A share of the screen, so the question under it always has room.
  static double heightOn(double screenHeight) =>
      (screenHeight * _screenShare).clamp(0, _maxHeight);

  @override
  State<PassageCard> createState() => _PassageCardState();
}

class _PassageCardState extends State<PassageCard> {
  static const _headerHeight = 52.0;
  static const _circle = 36.0;
  static const _iconSize = 18.0;
  static const _ring = 4.0;

  /// The whole-screen sheet follows the clip too, though it is on its own route.
  late final _clip = ValueNotifier(widget.clip);

  @override
  void didUpdateWidget(PassageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sheet is another route, and can't be told during this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _clip.value = widget.clip;
    });
  }

  @override
  void dispose() {
    _clip.dispose();
    super.dispose();
  }

  void _openWhole() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: sheetAnimation(context),
    shape: const RoundedRectangleBorder(),
    builder: (_) => _WholePassage(exercise: widget.exercise, clip: _clip),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final passage = widget.exercise.passage;
    final clip = widget.clip;
    final playing = clip.status == ClipStatus.playing;
    return Semantics(
      container: true,
      label: 'lesson_reading_text'.tr(),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: context.scheme.outline),
        ),
        child: Column(
          children: [
            Container(
              height: _headerHeight,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  if (passage.audioUrl != null)
                    IconButton(
                      onPressed: clip.onToggle,
                      tooltip: playing
                          ? 'lesson_reading_stop'.tr()
                          : 'lesson_reading_listen'.tr(),
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
                              color: playing
                                  ? colors.info.surface
                                  : Colors.transparent,
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
                    )
                  else
                    const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      passage.title,
                      locale: const Locale('en'),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.captionStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openWhole,
                    tooltip: 'lesson_reading_expand'.tr(),
                    color: colors.textSecondary,
                    icon: const Icon(Icons.open_in_full_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: FadingScroll(
                  fade: AppSpacing.xxxl,
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: _PassageText(
                    text: passage.text,
                    clip: clip,
                    style: context.texts.body.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The text, its sentence marked while the clip plays. ASSUMPTION(design): the
/// contract has no timings, so a sentence's turn goes by its share of the length.
class _PassageText extends StatelessWidget {
  const _PassageText({
    required this.text,
    required this.clip,
    required this.style,
  });

  final String text;
  final BodyClip clip;
  final TextStyle style;

  static final _sentence = RegExp(r'[^.!?]+[.!?]*\s*');

  Widget _marked(BuildContext context, List<String> sentences, double share) {
    var reached = share * text.length;
    final band = context.colors.reader.sentenceBand;
    var marked = false;
    return Text.rich(
      locale: const Locale('en'),
      TextSpan(
        style: style,
        children: [
          for (final sentence in sentences)
            () {
              reached -= sentence.length;
              final here = !marked && reached <= 0;
              marked = marked || here;
              return TextSpan(
                text: sentence,
                style: here ? TextStyle(backgroundColor: band) : null,
              );
            }(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (clip.status != ClipStatus.playing || clip.length == Duration.zero) {
      return Text(text, locale: const Locale('en'), style: style);
    }
    final sentences = [
      for (final match in _sentence.allMatches(text)) match.group(0)!,
    ];
    return TweenAnimationBuilder<double>(
      key: ValueKey(clip.playCount),
      tween: Tween(begin: 0, end: 1),
      duration: clip.length,
      builder: (context, share, _) => _marked(context, sentences, share),
    );
  }
}

/// The text on the whole screen, in reading size, with the question at the foot.
class _WholePassage extends StatelessWidget {
  const _WholePassage({required this.exercise, required this.clip});

  final ReadingExercise exercise;
  final ValueNotifier<BodyClip> clip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final passage = exercise.passage;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.md,
              end: AppSpacing.xl,
              top: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'lesson_reading_close'.tr(),
                  color: colors.textSecondary,
                  icon: const Icon(Icons.close_rounded),
                ),
                if (passage.audioUrl != null)
                  ValueListenableBuilder(
                    valueListenable: clip,
                    builder: (context, clip, _) => AppButton(
                      label: clip.status == ClipStatus.playing
                          ? 'lesson_reading_stop'.tr()
                          : 'lesson_reading_listen'.tr(),
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      onPressed: clip.onToggle,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        passage.title,
                        locale: const Locale('en'),
                        style: texts.title,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ValueListenableBuilder(
                      valueListenable: clip,
                      builder: (context, clip, _) => _PassageText(
                        text: passage.text,
                        clip: clip,
                        style: texts.reading.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.md + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'lesson_reading_step'.tr(
                      namedArgs: {
                        'step': '${exercise.step}',
                        'steps': '${exercise.steps}',
                      },
                    ),
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    exercise.ask,
                    locale: const Locale('en'),
                    textDirection: TextDirection.ltr,
                    style: texts.bodyStrong.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'lesson_reading_back'.tr(),
                    size: AppButtonSize.large,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
