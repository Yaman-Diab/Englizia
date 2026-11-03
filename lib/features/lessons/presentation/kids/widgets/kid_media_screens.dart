import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/listening_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/features/lessons/domain/entities/kid_lesson.dart';
import 'package:englizia/features/lessons/presentation/kids/cubit/kid_lesson_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A sentence of a kids' screen, in Andika, its current word on the karaoke
/// color and strong; [marked] words are dotted, and open their card.
class _KidSentence extends StatelessWidget {
  const _KidSentence({
    required this.words,
    required this.current,
    this.marked,
    this.onMarked,
    this.center = true,
  });

  final List<String> words;
  final int current;
  final KidWord? Function(String text)? marked;
  final ValueChanged<KidWord>? onMarked;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final plain = texts.kidsCard.copyWith(
      color: colors.textPrimary,
      height: 44 / 28,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Wrap(
        alignment: center ? WrapAlignment.center : WrapAlignment.start,
        spacing: AppSpacing.xxs,
        children: [
          for (final (index, text) in words.indexed)
            _word(context, text, index == current, plain, marked?.call(text)),
        ],
      ),
    );
  }

  Widget _word(
    BuildContext context,
    String text,
    bool on,
    TextStyle plain,
    KidWord? card,
  ) {
    final colors = context.colors;
    final style = on
        ? context.texts.kidsWord.copyWith(
            color: colors.textPrimary,
            fontSize: plain.fontSize,
            height: plain.height,
          )
        : plain;
    final shown = AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.quick),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: on ? colors.reader.karaokeBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: card == null
            ? style
            : style.copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: colors.reader.tappableUnderline,
                decorationThickness: 3,
              ),
      ),
    );
    if (card == null) return shown;
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(onTap: () => onMarked?.call(card), child: shown),
    );
  }
}

/// The big microphone of a kids' screen: one press to start, its ring while
/// the child speaks.
class KidMicButton extends StatelessWidget {
  const KidMicButton({
    required this.recording,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final bool recording;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  static const _size = 96.0;
  static const _halo = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: recording,
      label: label,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            ListeningWaves(
              active: recording,
              size: _size,
              count: 1,
              growth: .5,
              opacity: .3,
              filled: true,
              duration: AppMotion.micRing,
              color: colors.primary.fill,
            ),
            GestureDetector(
              onTap: enabled ? onPressed : null,
              child: AnimatedOpacity(
                duration: AppMotion.resolve(context, AppMotion.fast),
                opacity: enabled ? 1 : .4,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: colors.primaryStrong,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.surface,
                        spreadRadius: _halo,
                      ),
                    ],
                  ),
                  child: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                    size: AppSizes.iconLg + AppSpacing.sm,
                    color: colors.onPrimaryStrong,
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

/// «قصة مصوّرة»: a page for each sentence, told with its words marked, its
/// dotted words opening a card, and pages turned by hand or by themselves.
class KidStoryScreen extends StatelessWidget {
  const KidStoryScreen({
    required this.step,
    required this.state,
    required this.cardKey,
    super.key,
  });

  final KidStoryStep step;
  final KidLessonState state;
  final GlobalKey Function(String id) cardKey;

  static const _turn = 64.0;
  static const _dot = 12.0;
  static const _dotOn = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<KidLessonCubit>();
    final story = state.story;
    final turnedFrom = story.turnedFrom;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              key: cardKey(KidLessonCubit.storyCard),
              children: [
                Positioned.fill(
                  child: _StoryPage(
                    page: step.pages[story.page],
                    word: turnedFrom == null ? story.word : -1,
                    arriving: turnedFrom != null,
                  ),
                ),
                if (turnedFrom != null)
                  Positioned.fill(
                    child: _TurningPage(
                      page: step.pages[turnedFrom],
                      forward: story.forward,
                    ),
                  ),
                PositionedDirectional(
                  top: AppSpacing.sm + AppSpacing.xxs,
                  start: AppSpacing.sm + AppSpacing.xxs,
                  child: _AutoTurn(on: story.auto),
                ),
                if (story.opened case final word?)
                  Positioned.fill(child: _MarkedCard(word: word)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Opacity(
                opacity: story.page == 0 ? .4 : 1,
                child: KidRoundButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: 'kid_previous'.tr(),
                  size: _turn,
                  onPressed: story.page == 0 ? null : () => cubit.turnPage(-1),
                ),
              ),
              Expanded(
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < step.pages.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        AnimatedContainer(
                          duration: AppMotion.resolve(
                            context,
                            AppMotion.medium,
                          ),
                          width: i == story.page ? _dotOn : _dot,
                          height: _dot,
                          decoration: BoxDecoration(
                            color: i == story.page
                                ? colors.primaryStrong
                                : colors.border,
                            borderRadius: BorderRadius.circular(_dot / 2),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              KidRoundButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                label: 'kid_next'.tr(),
                primary: true,
                size: _turn,
                onPressed: () => cubit.turnPage(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({
    required this.page,
    required this.word,
    required this.arriving,
  });

  final KidStoryPage page;
  final int word;

  /// Under the page turning away: it grows into place.
  final bool arriving;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<KidLessonCubit>();
    final shown = ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.primary.surface,
                borderRadius: BorderRadius.circular(kidRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: KidPicture(
                    url: page.image,
                    size: constraints.biggest.shortestSide,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          _KidSentence(
            words: [for (final word in page.words) word.text],
            current: word,
            marked: page.markedFor,
            onMarked: cubit.openMarked,
          ),
        ],
      ),
    );
    if (!arriving || AppMotion.reduceMotion(context)) return shown;
    return shown
        .animate()
        .fadeIn(begin: .5, duration: KidMediaSteps.pageTurn)
        .scaleXY(begin: .95, end: 1, curve: AppMotion.out);
  }
}

/// The page turned from, swinging away; under reduce motion it only fades.
class _TurningPage extends StatelessWidget {
  const _TurningPage({required this.page, required this.forward});

  final KidStoryPage page;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final shown = IgnorePointer(
      child: _StoryPage(page: page, word: -1, arriving: false),
    );
    final away = forward ? -1.12 : 1.12;
    final toStart = Directionality.of(context) == TextDirection.rtl
        ? -away
        : away;
    if (AppMotion.reduceMotion(context)) {
      return shown.animate().fadeOut(duration: KidMediaSteps.pageTurn);
    }
    return shown
        .animate()
        .slideX(
          begin: 0,
          end: toStart,
          duration: KidMediaSteps.pageTurn,
          curve: AppMotion.inOut,
        )
        .rotate(
          begin: 0,
          end: toStart * .025,
          alignment: Alignment.bottomCenter,
        )
        .fade(begin: 1, end: .85);
  }
}

/// «اقلب الصفحات وحدها»: ringed, with a check, while on.
class _AutoTurn extends StatelessWidget {
  const _AutoTurn({required this.on});

  final bool on;

  static const _size = 56.0;
  static const _badge = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      toggled: on,
      label: 'kid_auto_turn'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: context.read<KidLessonCubit>().toggleAutoTurn,
        child: SizedBox.square(
          dimension: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.closeUp),
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: on ? colors.primary.surface : colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: on ? colors.primaryStrong : colors.border,
                    width: on ? 3 : 2,
                  ),
                ),
                child: Center(
                  child: AppIconView(
                    AppIcon.book,
                    size: AppSizes.iconMd + AppSpacing.xxs,
                    color: on ? colors.primaryStrong : colors.textSecondary,
                  ),
                ),
              ),
              if (on)
                PositionedDirectional(
                  bottom: AppSpacing.xxs,
                  end: AppSpacing.xxs,
                  child: Container(
                    width: _badge,
                    height: _badge,
                    decoration: BoxDecoration(
                      color: colors.primaryStrong,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: AppSizes.iconSm * .8,
                      color: colors.onPrimaryStrong,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A marked word's card: its picture and voice only, no text. Outside it
/// closes it.
class _MarkedCard extends StatelessWidget {
  const _MarkedCard({required this.word});

  final KidWord word;

  static const _width = 236.0;
  static const _picture = 140.0;
  static const _top = 150.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<KidLessonCubit>();
    final card = Container(
      width: _width,
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(kidRadius),
        border: Border.all(color: colors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: .22),
            blurRadius: AppSpacing.xl,
            offset: const Offset(0, AppSpacing.md),
          ),
        ],
      ),
      child: Row(
        children: [
          KidPicture(url: word.image, size: _picture),
          const SizedBox(width: AppSpacing.md),
          KidRoundButton(
            icon: const Icon(Icons.volume_up_rounded),
            label: 'kid_listen'.tr(),
            info: true,
            size: 56,
            onPressed: () => cubit.openMarked(word),
          ),
        ],
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: cubit.closeMarked,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.topCenter,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(top: _top),
            child: Semantics(
              label: word.word,
              child: AppMotion.reduceMotion(context)
                  ? card
                  : card
                        .animate()
                        .fadeIn(duration: AppMotion.fast)
                        .scaleXY(begin: .8, end: 1, curve: AppMotion.overshoot)
                        .moveY(begin: AppSpacing.md, end: 0),
            ),
          ),
        ),
      ],
    );
  }
}

/// «أنشودة»: its video at 0.75 by default, its lines with the one sung on a
/// band and its word marked, then «غنِّ مرة أخرى».
class KidSongScreen extends StatelessWidget {
  const KidSongScreen({
    required this.step,
    required this.state,
    required this.cardKey,
    required this.video,
    super.key,
  });

  final KidSongStep step;
  final KidLessonState state;
  final GlobalKey Function(String id) cardKey;

  /// The video's own picture.
  final Widget video;

  static const _play = 72.0;
  static const _picture = 84.0;
  static const _bar = 6.0;
  static const _chip = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<KidLessonCubit>();
    final song = state.song;
    final playing = song.status == KidVideoStatus.playing;
    final reduce = AppMotion.reduceMotion(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(kidRadius),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(
                      color: colors.primary.surface,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final (i, image) in step.pictures.indexed)
                                if (playing && !reduce)
                                  KidPicture(url: image, size: _picture)
                                      .animate(
                                        delay: AppMotion.stagger * 4 * i,
                                        onPlay: (bob) =>
                                            bob.repeat(reverse: true),
                                      )
                                      .moveY(
                                        begin: 0,
                                        end: -10,
                                        duration: AppMotion.characterNod * .5,
                                        curve: AppMotion.inOut,
                                      )
                                      .rotate(begin: 0, end: .017)
                                else
                                  KidPicture(url: image, size: _picture),
                            ],
                          ),
                          if (song.status != KidVideoStatus.idle)
                            ExcludeSemantics(child: video),
                          if (song.status == KidVideoStatus.idle)
                            Semantics(
                              button: true,
                              label: 'kid_play_song'.tr(),
                              excludeSemantics: true,
                              child: GestureDetector(
                                onTap: cubit.playSong,
                                child: ColoredBox(
                                  color: colors.textPrimary.withValues(
                                    alpha: .18,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: _play,
                                      height: _play,
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        size: AppSizes.iconLg + AppSpacing.xxs,
                                        color: colors.primaryStrong,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          PositionedDirectional(
                            top: AppSpacing.xs + AppSpacing.xxs,
                            end: AppSpacing.xs + AppSpacing.xxs,
                            child: Semantics(
                              button: true,
                              label: song.speed == KidSongStep.slow
                                  ? 'kid_speed_slow'.tr()
                                  : 'kid_speed_normal'.tr(),
                              excludeSemantics: true,
                              child: GestureDetector(
                                onTap: cubit.toggleSongSpeed,
                                child: SizedBox(
                                  height: AppSizes.minTapTarget,
                                  child: Center(
                                    child: Container(
                                      height: _chip,
                                      padding:
                                          const EdgeInsetsDirectional.symmetric(
                                            horizontal: AppSpacing.md,
                                          ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius: BorderRadius.circular(
                                          _chip / 2,
                                        ),
                                      ),
                                      child: Text(
                                        song.speed == KidSongStep.slow
                                            ? '0.75×'
                                            : '1×',
                                        textDirection: TextDirection.ltr,
                                        style: texts.bodyStrong.copyWith(
                                          color: colors.textPrimary,
                                          fontSize: texts.body.fontSize! * .94,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (playing)
                            PositionedDirectional(
                              start: AppSpacing.md,
                              end: AppSpacing.md,
                              bottom: AppSpacing.sm + AppSpacing.xxs,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(_bar / 2),
                                child: LinearProgressIndicator(
                                  value: song.progress,
                                  minHeight: _bar,
                                  color: colors.primaryStrong,
                                  backgroundColor: colors.surface.withValues(
                                    alpha: .6,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final (index, line) in step.lines.indexed) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.xs),
                  AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.closeUp),
                    width: double.infinity,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: index == song.line
                          ? colors.reader.sentenceBand
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md + 2),
                    ),
                    child: _KidSentence(
                      words: [for (final word in line) word.text],
                      current: index == song.line ? song.word : -1,
                      center: false,
                    ),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: AppSpacing.lg),
                if (song.status == KidVideoStatus.done)
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'kid_sing_again'.tr(),
                          excludeSemantics: true,
                          child: PressScale(
                            child: GestureDetector(
                              onTap: cubit.playSong,
                              child: Container(
                                height: 72,
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(36),
                                  border: Border.all(
                                    color: colors.border,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.replay_rounded,
                                      size: AppSizes.iconLg - AppSpacing.xs,
                                      color: colors.primaryStrong,
                                    ),
                                    const SizedBox(
                                      width: AppSpacing.sm + AppSpacing.xxs,
                                    ),
                                    Flexible(
                                      child: Text(
                                        'kid_sing_again'.tr(),
                                        style: texts.title.copyWith(
                                          color: colors.primaryStrong,
                                          fontSize: 20,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      KidRoundButton(
                        key: cardKey(KidLessonCubit.songNext),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: 'kid_next'.tr(),
                        primary: true,
                        onPressed: cubit.songDone,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// «حوار مكتوب»: the character asks, the child picks a reply by its picture,
/// repeats its sentence for a star, and the character says goodbye.
class KidDialogueScreen extends StatelessWidget {
  const KidDialogueScreen({
    required this.step,
    required this.state,
    required this.cardKey,
    required this.recording,
    required this.onMic,
    super.key,
  });

  final KidDialogueStep step;
  final KidLessonState state;
  final GlobalKey Function(String id) cardKey;
  final bool recording;
  final VoidCallback onMic;

  static const _character = 120.0;
  static const _choice = 196.0;
  static const _choicePicture = 112.0;
  static const _mine = 56.0;
  static const _star = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<KidLessonCubit>();
    final talk = state.dialogue;
    final picked = talk.picked == null ? null : step.replies[talk.picked!];
    final andika = texts.kidsCard.copyWith(
      color: colors.textPrimary,
      height: 40 / 28,
    );
    final reduce = AppMotion.reduceMotion(context);
    final character = Semantics(
      label: step.character.word,
      child: KidPicture(url: step.character.image, size: _character),
    );
    final echoing =
        talk.phase == KidTalkPhase.echo ||
        talk.phase == KidTalkPhase.recording ||
        talk.phase == KidTalkPhase.echoed;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl - AppSpacing.xs,
              0,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                if (reduce || talk.lines == 0)
                  character
                else
                  KeyedSubtree(
                    key: ValueKey(talk.lines),
                    child: character
                        .animate()
                        .moveY(
                          begin: 0,
                          end: -14,
                          duration: AppMotion.characterPose * .5,
                          curve: AppMotion.out,
                        )
                        .then()
                        .moveY(begin: 0, end: 14),
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (talk.line.isNotEmpty)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        AppSpacing.sm + AppSpacing.xxs,
                        AppSpacing.sm + AppSpacing.xxs,
                        AppSpacing.sm + AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(kidRadius),
                        border: Border.all(color: colors.border, width: 2),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(talk.line, style: andika)),
                          const SizedBox(width: AppSpacing.sm),
                          KidRoundButton(
                            icon: const Icon(Icons.volume_up_rounded),
                            label: 'kid_listen'.tr(),
                            info: true,
                            size: 56,
                            onPressed: () => cubit.replayCharacter(),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (picked != null && talk.phase == KidTalkPhase.reply) ...[
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _Picked(reply: picked, size: _mine),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: AppSpacing.lg),
                if (talk.phase == KidTalkPhase.choose ||
                    talk.phase == KidTalkPhase.opening)
                  Row(
                    children: [
                      for (final (index, reply) in step.replies.indexed) ...[
                        if (index > 0) const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ReplyCard(
                            reply: reply,
                            height: _choice,
                            picture: _choicePicture,
                            enabled: talk.phase == KidTalkPhase.choose,
                            onPick: () => cubit.pickReply(index),
                          ),
                        ),
                      ],
                    ],
                  ),
                if (echoing && picked != null) ...[
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Stack(
                      key: cardKey(KidLessonCubit.echoCard),
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: AppMotion.resolve(
                            context,
                            AppMotion.closeUp,
                          ),
                          padding: const EdgeInsetsDirectional.all(
                            AppSpacing.sm + AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(kidRadius),
                            border: Border.all(
                              color: talk.phase == KidTalkPhase.echoed
                                  ? colors.reward.fill
                                  : colors.border,
                              width: talk.phase == KidTalkPhase.echoed ? 3 : 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              KidPicture(url: picked.word.image, size: _mine),
                              const SizedBox(
                                width: AppSpacing.sm + AppSpacing.xxs,
                              ),
                              Expanded(
                                child: Text(picked.echo.text, style: andika),
                              ),
                              KidRoundButton(
                                icon: const Icon(Icons.volume_up_rounded),
                                label: 'kid_listen'.tr(),
                                info: true,
                                size: 56,
                                onPressed: cubit.playEcho,
                              ),
                            ],
                          ),
                        ),
                        if (talk.phase == KidTalkPhase.echoed)
                          PositionedDirectional(
                            top: -AppSpacing.md - AppSpacing.xxs,
                            start: -AppSpacing.xs - AppSpacing.xxs,
                            child: Semantics(
                              label: 'kid_star'.tr(),
                              child: reduce
                                  ? const KidStar(size: _star, outlined: true)
                                  : const KidStar(size: _star, outlined: true)
                                        .animate()
                                        .scaleXY(
                                          begin: 0,
                                          end: 1,
                                          duration: AppMotion.kidStarFill,
                                          curve: AppMotion.overshoot,
                                        )
                                        .rotate(begin: -.11, end: 0),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                  KidMicButton(
                    recording: recording,
                    label: 'kid_say_sentence'.tr(),
                    enabled: talk.phase != KidTalkPhase.echoed,
                    onPressed: onMic,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The reply picked, going up as the child's bubble.
class _Picked extends StatelessWidget {
  const _Picked({required this.reply, required this.size});

  final KidReply reply;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bubble = Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.lg + AppSpacing.xxs,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.primary.surface,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(kidRadius),
            topEnd: Radius.circular(AppSpacing.xs + AppSpacing.xxs),
            bottomStart: Radius.circular(kidRadius),
            bottomEnd: Radius.circular(kidRadius),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KidPicture(url: reply.word.image, size: size),
            const SizedBox(width: AppSpacing.sm),
            Text(
              reply.word.word,
              style: context.texts.kidsCard.copyWith(
                color: colors.textPrimary,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
    if (AppMotion.reduceMotion(context)) return bubble;
    return bubble
        .animate()
        .fadeIn(duration: AppMotion.kidScreenIn)
        .moveY(begin: 40, end: 0, curve: AppMotion.overshoot)
        .scaleXY(begin: .8, end: 1);
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.reply,
    required this.height,
    required this.picture,
    required this.enabled,
    required this.onPick,
  });

  final KidReply reply;
  final double height;
  final double picture;
  final bool enabled;
  final VoidCallback onPick;

  static const _speaker = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              enabled: enabled,
              label: reply.word.word,
              excludeSemantics: true,
              child: PressScale(
                enabled: enabled,
                child: GestureDetector(
                  onTap: enabled ? onPick : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(kidRadius),
                      border: Border.all(color: colors.border, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        KidPicture(url: reply.word.image, size: picture),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          reply.word.word,
                          textDirection: TextDirection.ltr,
                          style: context.texts.kidsCard.copyWith(
                            color: colors.textPrimary,
                            height: 40 / 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: AppSpacing.xs + AppSpacing.xxs,
            end: AppSpacing.xs + AppSpacing.xxs,
            child: Semantics(
              button: true,
              label: 'kid_listen_to'.tr(namedArgs: {'word': reply.word.word}),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => context.read<KidLessonCubit>().sayWord(reply.word),
                child: Container(
                  width: _speaker,
                  height: _speaker,
                  decoration: BoxDecoration(
                    color: colors.info.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: AppSizes.iconMd - AppSpacing.xxs,
                    color: colors.info.fill,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «كرّر بعدي»: the picture and the word with its model, then the child says
/// it; any try earns the star.
class KidSpeakScreen extends StatelessWidget {
  const KidSpeakScreen({
    required this.step,
    required this.state,
    required this.cardKey,
    required this.recording,
    required this.onMic,
    super.key,
  });

  final KidSpeakStep step;
  final KidLessonState state;
  final GlobalKey Function(String id) cardKey;
  final bool recording;
  final VoidCallback onMic;

  static const _picture = 270.0;
  static const _bars = [14.0, 26.0, 38.0, 22.0, 44.0, 30.0, 18.0, 34.0, 16.0];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<KidLessonCubit>();
    final reduce = AppMotion.reduceMotion(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.xl - AppSpacing.xs,
            ),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: step.word.word,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: cubit.playModel,
                    child: Container(
                      height: _picture,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.primary.surface,
                        borderRadius: BorderRadius.circular(kidRadius),
                      ),
                      child: Center(
                        child: KidPicture(
                          url: step.word.image,
                          size: _picture - AppSpacing.xl,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      step.word.word,
                      textDirection: TextDirection.ltr,
                      style: context.texts.kidsCard.copyWith(
                        color: colors.textPrimary,
                        fontSize: 40,
                        height: 56 / 40,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    KidRoundButton(
                      icon: const Icon(Icons.volume_up_rounded),
                      label: 'kid_listen_model'.tr(),
                      info: true,
                      ringed: state.questionPlaying,
                      onPressed: cubit.playModel,
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: AppSpacing.lg),
                ExcludeSemantics(
                  child: AnimatedOpacity(
                    duration: AppMotion.resolve(context, AppMotion.closeUp),
                    opacity: recording ? 1 : 0,
                    child: SizedBox(
                      height: 44,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (i, height) in _bars.indexed) ...[
                              if (i > 0) const SizedBox(width: 6),
                              _Bar(
                                height: height,
                                index: i,
                                moving: recording && !reduce,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KidMicButton(
                  key: cardKey(KidLessonCubit.micButton),
                  recording: recording,
                  label: 'kid_speak'.tr(),
                  enabled: state.speak != KidSpeakPhase.done,
                  onPressed: onMic,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A bar of the voice while the child speaks.
class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.index, required this.moving});

  final double height;
  final int index;
  final bool moving;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.primary.fill,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    if (!moving) return bar;
    return bar
        .animate(
          delay: AppMotion.stagger * 1.5 * index,
          onPlay: (loop) => loop.repeat(reverse: true),
        )
        .scaleY(
          begin: .35,
          end: 1,
          duration: AppMotion.characterNod * (.55 + .15 * (index % 3)),
          curve: AppMotion.inOut,
        );
  }
}
