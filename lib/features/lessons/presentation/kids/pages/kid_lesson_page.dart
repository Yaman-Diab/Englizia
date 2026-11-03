import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/shake.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/kid_lesson.dart';
import 'package:englizia/features/lessons/presentation/kids/cubit/kid_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/kids/widgets/kid_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A kids' lesson (requirements v3.0 §13.2, design "Kid Lesson"): big touch
/// targets, Andika for English, icons instead of words on buttons, the guide
/// saying each instruction, and no violet, red screen, cross or points.
class KidLessonPage extends StatefulWidget {
  const KidLessonPage({required this.onExit, required this.onNext, super.key});

  final VoidCallback onExit;

  /// «التالي» at the end.
  final VoidCallback onNext;

  @override
  State<KidLessonPage> createState() => _KidLessonPageState();
}

class _KidLessonPageState extends State<KidLessonPage>
    with TickerProviderStateMixin {
  late final _cubit = context.read<KidLessonCubit>();
  final _barStar = GlobalKey();

  /// The cards a star can fly from, by option or pair.
  final _cards = <String, GlobalKey>{};

  GlobalKey _cardKey(String id) => _cards.putIfAbsent(id, GlobalKey.new);

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _fly(String from) async {
    await Future<void>.delayed(
      AppMotion.resolve(context, AppMotion.kidStarFlightDelay),
    );
    if (!mounted) return;
    final start = _rectOf(_cardKey(from));
    final end = _rectOf(_barStar);
    if (start == null || end == null) return _cubit.landed();
    await flyKidStar(
      context,
      vsync: this,
      from: start,
      to: end,
      onLanded: () {
        if (mounted) _cubit.landed();
      },
    );
  }

  Future<void> _askToLeave() async {
    _cubit.askToLeave();
    final leave = await showKidExitSheet(context);
    if (!mounted) return;
    if (leave) {
      widget.onExit();
    } else {
      _cubit.stay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocConsumer<KidLessonCubit, KidLessonState>(
      listenWhen: (previous, current) => current.won > previous.won,
      listener: (context, state) => unawaited(_fly(state.wonFrom!)),
      builder: (context, state) => switch (state.stage) {
        KidStage.loading => const Scaffold(body: AppStateView.loading()),
        KidStage.failed => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: widget.onExit,
              tooltip: 'common_close'.tr(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          body: AppStateView.error(
            message: state.failure!.localizedMessage,
            onRetry: _cubit.start,
          ),
        ),
        KidStage.playing || KidStage.done => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (state.stage == KidStage.done) {
              widget.onExit();
            } else {
              unawaited(_askToLeave());
            }
          },
          child: Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: state.stage == KidStage.done
                  ? _Done(state: state, onNext: widget.onNext)
                  : Column(
                      children: [
                        KidTopBar(
                          state: state,
                          starKey: _barStar,
                          onExit: _askToLeave,
                          onGuide: _cubit.replayInstruction,
                        ),
                        Expanded(
                          child: _Arrival(
                            key: ValueKey(state.step),
                            child: _screen(state),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      },
    );
  }

  Widget _screen(KidLessonState state) => switch (state.current) {
    KidWordStep(:final word) => _WordCard(word: word, state: state),
    final KidLetterStep step => _LetterCard(step: step, state: state),
    KidQuestionStep() => switch (state.question) {
      final MatchingExercise question => _Match(
        question: question,
        state: state,
        cardKey: _cardKey,
      ),
      final ChoiceExercise question => _Choose(
        question: question,
        state: state,
        cardKey: _cardKey,
      ),
      _ => const SizedBox.shrink(),
    },
    null => const SizedBox.shrink(),
  };
}

/// Each screen slides in from where the lesson goes.
class _Arrival extends StatelessWidget {
  const _Arrival({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return child;
    final from = Directionality.of(context) == TextDirection.rtl ? -32.0 : 32.0;
    return child
        .animate()
        .fadeIn(duration: AppMotion.kidScreenIn, curve: AppMotion.smoothOut)
        .moveX(begin: from, end: 0, curve: AppMotion.smoothOut);
  }
}

/// A screen that fills the height, and scrolls only where it can't.
class _Screen extends StatelessWidget {
  const _Screen({required this.children, this.top = AppSpacing.sm});

  final List<Widget> children;
  final double top;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl - AppSpacing.xs,
            top,
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.lg,
          ),
          child: Column(children: children),
        ),
      ),
    ],
  );
}

class _NextButton extends StatelessWidget {
  const _NextButton();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: KidRoundButton(
      icon: const Icon(Icons.arrow_forward_rounded),
      label: 'kid_next'.tr(),
      primary: true,
      onPressed: context.read<KidLessonCubit>().next,
    ),
  );
}

/// «بطاقة الكلمة»: the picture, the word and its voice, each saying it again.
class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.state});

  final KidWord word;
  final KidLessonState state;

  static const _picture = 340.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<KidLessonCubit>();
    return _Screen(
      children: [
        Semantics(
          button: true,
          label: word.arabic.isEmpty
              ? word.word
              : 'kid_word_label'.tr(
                  namedArgs: {'word': word.word, 'arabic': word.arabic},
                ),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => cubit.sayWord(word),
            child: Container(
              height: _picture,
              width: double.infinity,
              padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.primary.surface,
                borderRadius: BorderRadius.circular(kidRadius),
              ),
              child: KidPicture(url: word.image, size: _picture),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: () => cubit.sayWord(word),
          child: Text(
            word.word,
            textDirection: TextDirection.ltr,
            style: texts.kidsCard.copyWith(
              color: colors.textPrimary,
              fontSize: 40,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        KidRoundButton(
          icon: const Icon(Icons.volume_up_rounded),
          label: 'kid_listen'.tr(),
          info: true,
          onPressed: () => cubit.sayWord(word),
        ),
        const Spacer(),
        const SizedBox(height: AppSpacing.lg),
        const _NextButton(),
      ],
    );
  }
}

/// «بطاقة الحرف»: the video, the letter big in both cases, and two words that
/// start with it, each saying itself.
class _LetterCard extends StatelessWidget {
  const _LetterCard({required this.step, required this.state});

  final KidLetterStep step;
  final KidLessonState state;

  static const _side = 68.0;
  static const _play = 72.0;
  static const _replay = 56.0;
  static const _bar = 6.0;
  static const _picture = 112.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<KidLessonCubit>();
    final pair = '${step.letter} ${step.letter.toLowerCase()}';
    final playing = state.video == KidVideoStatus.playing;
    final letters = Text(
      pair,
      textDirection: TextDirection.ltr,
      style: texts.kidsWord.copyWith(
        color: colors.primaryStrong,
        fontSize: 64,
        height: 1,
      ),
    );
    return _Screen(
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
                      if (step.words.isNotEmpty)
                        KidPicture(url: step.words.first.image, size: _side),
                      const SizedBox(width: AppSpacing.xs),
                      if (playing && !AppMotion.reduceMotion(context))
                        letters
                            .animate(
                              onPlay: (loop) => loop.repeat(reverse: true),
                            )
                            .moveY(
                              begin: 0,
                              end: -10,
                              duration: AppMotion.characterNod * .4,
                              curve: AppMotion.inOut,
                            )
                            .scaleXY(begin: 1, end: 1.08)
                      else
                        letters,
                      const SizedBox(width: AppSpacing.xs),
                      if (step.words.length > 1)
                        KidPicture(url: step.words[1].image, size: _side),
                    ],
                  ),
                  if (state.video != KidVideoStatus.idle)
                    ExcludeSemantics(child: _VideoPicture(cubit: cubit)),
                  if (state.video == KidVideoStatus.idle)
                    Semantics(
                      button: true,
                      label: 'kid_play_video'.tr(),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: cubit.playVideo,
                        child: ColoredBox(
                          color: colors.textPrimary.withValues(alpha: .18),
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
                  if (playing)
                    PositionedDirectional(
                      start: AppSpacing.md,
                      end: AppSpacing.md,
                      bottom: AppSpacing.sm + AppSpacing.xxs,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_bar / 2),
                        child: LinearProgressIndicator(
                          value: state.videoProgress,
                          minHeight: _bar,
                          color: colors.primaryStrong,
                          backgroundColor: colors.surface.withValues(alpha: .6),
                        ),
                      ),
                    ),
                  if (state.video == KidVideoStatus.done)
                    PositionedDirectional(
                      end: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: KidRoundButton(
                        icon: const Icon(Icons.replay_rounded),
                        label: 'kid_replay_video'.tr(),
                        size: _replay,
                        onPressed: cubit.playVideo,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: cubit.sayLetter,
              child: Semantics(
                button: true,
                label: step.letter,
                excludeSemantics: true,
                child: Text(
                  pair,
                  textDirection: TextDirection.ltr,
                  style: texts.kidsCard.copyWith(
                    color: colors.primary.fill,
                    fontSize: 96,
                    height: 112 / 96,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            KidRoundButton(
              icon: const Icon(Icons.volume_up_rounded),
              label: 'kid_listen_letter'.tr(),
              info: true,
              size: 56,
              onPressed: cubit.sayLetter,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final (index, word) in step.words.take(2).indexed) ...[
              if (index > 0) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _WordTile(word: word, picture: _picture),
              ),
            ],
          ],
        ),
        const Spacer(),
        const SizedBox(height: AppSpacing.lg),
        const _NextButton(),
      ],
    );
  }
}

/// The video's own picture, made once: it covers the letter while it plays,
/// and leaves it seen where there is none (the mock's).
class _VideoPicture extends StatefulWidget {
  const _VideoPicture({required this.cubit});

  final KidLessonCubit cubit;

  @override
  State<_VideoPicture> createState() => _VideoPictureState();
}

class _VideoPictureState extends State<_VideoPicture> {
  late final Widget _picture = widget.cubit.engine.view();

  @override
  Widget build(BuildContext context) => _picture;
}

/// A word that starts with the letter: its picture, and the word with its
/// first letter in the letter's color.
class _WordTile extends StatelessWidget {
  const _WordTile({required this.word, required this.picture});

  final KidWord word;
  final double picture;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final style = texts.kidsCard.copyWith(color: colors.textPrimary);
    return Semantics(
      button: true,
      label: word.word,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          onTap: () => context.read<KidLessonCubit>().sayWord(word),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs + AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(kidRadius),
              border: Border.all(color: colors.border, width: 2),
            ),
            child: Column(
              children: [
                KidPicture(url: word.image, size: picture),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: word.word.characters.first,
                        style: texts.kidsWord.copyWith(
                          color: colors.primary.fill,
                          fontSize: style.fontSize,
                          height: style.height,
                        ),
                      ),
                      TextSpan(text: word.word.characters.skip(1).string),
                    ],
                  ),
                  textDirection: TextDirection.ltr,
                  style: style,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «اسمع واختر الحرف» and «اسمع واختر الصورة»: pressing is answering.
class _Choose extends StatelessWidget {
  const _Choose({
    required this.question,
    required this.state,
    required this.cardKey,
  });

  final ChoiceExercise question;
  final KidLessonState state;
  final GlobalKey Function(String id) cardKey;

  static const _speaker = 96.0;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<KidLessonCubit>();
    return _Screen(
      top: AppSpacing.md,
      children: [
        KidRoundButton(
          icon: const Icon(Icons.volume_up_rounded),
          label: 'kid_listen_again'.tr(),
          info: true,
          size: _speaker,
          ringed: state.questionPlaying,
          onPressed: cubit.playQuestion,
        ),
        const SizedBox(height: AppSpacing.xxl - AppSpacing.xs),
        Semantics(
          container: true,
          label: 'kid_options'.tr(),
          child: Column(
            children: [
              for (var row = 0; row < question.options.length; row += 2) ...[
                if (row > 0) const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    for (var i = row; i < row + 2; i++) ...[
                      if (i > row) const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: i < question.options.length
                              ? _ChoiceCard(
                                  key: cardKey(question.options[i].id),
                                  option: question.options[i],
                                  state: state,
                                  isAnswer:
                                      question.options[i].id ==
                                      question.answerId,
                                  onTap: () =>
                                      cubit.pick(question.options[i].id),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.option,
    required this.state,
    required this.isAnswer,
    required this.onTap,
    super.key,
  });

  final ExerciseOption option;
  final KidLessonState state;
  final bool isAnswer;
  final VoidCallback onTap;

  static const _badge = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduce = AppMotion.reduceMotion(context);
    final right = state.right == option.id;
    final wrong = state.wrong.contains(option.id);
    final flashing = state.flash == option.id;
    final hinted = state.hint && isAnswer && state.right == null;
    final locked = wrong || state.right != null;
    final card = AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      decoration: BoxDecoration(
        color: flashing ? colors.error.surface : colors.surface,
        borderRadius: BorderRadius.circular(kidRadius),
        border: Border.all(
          color: right
              ? colors.success.fill
              : hinted
              ? colors.primary.fill
              : colors.border,
          width: right
              ? 4
              : hinted
              ? 3
              : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: hinted ? colors.primary.surface : Colors.transparent,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (option.image.isEmpty)
            Text(
              option.text,
              textDirection: TextDirection.ltr,
              style: context.texts.kidsCard.copyWith(
                color: colors.textPrimary,
                fontSize: 56,
                height: 1,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => KidPicture(
                url: option.image,
                size: constraints.maxWidth * .8,
              ),
            ),
          if (right)
            const PositionedDirectional(
              top: AppSpacing.sm,
              end: AppSpacing.sm,
              child: KidStar(size: _badge),
            ),
        ],
      ),
    );
    Widget shown = AnimatedOpacity(
      duration: AppMotion.resolve(context, AppMotion.medium),
      opacity: wrong && !flashing ? .5 : 1,
      child: AnimatedScale(
        duration: AppMotion.resolve(context, AppMotion.medium),
        curve: AppMotion.overshoot,
        scale: right && !reduce ? 1.08 : 1,
        child: Shake(trigger: wrong, child: card),
      ),
    );
    if (hinted && !reduce) {
      shown = shown
          .animate(
            delay: AppMotion.kidHintDelay,
            onPlay: (pulse) => pulse.repeat(reverse: true, count: 4),
          )
          .scaleXY(
            begin: 1,
            end: 1.07,
            duration: AppMotion.kidHintPulse * .5,
            curve: AppMotion.inOut,
          );
    }
    return Semantics(
      button: true,
      enabled: !locked,
      selected: right,
      label: option.image.isEmpty ? option.text : option.alt,
      excludeSemantics: true,
      child: GestureDetector(onTap: locked ? null : onTap, child: shown),
    );
  }
}

/// «طابق»: a picture, then its word; a word alone is only heard.
class _Match extends StatelessWidget {
  const _Match({
    required this.question,
    required this.state,
    required this.cardKey,
  });

  final MatchingExercise question;
  final KidLessonState state;
  final GlobalKey Function(String id) cardKey;

  static const _height = 80.0;
  static const _picture = 64.0;
  static const _badge = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<KidLessonCubit>();
    Widget card({
      required String id,
      required bool done,
      required bool selected,
      required bool flashing,
      required Widget child,
      required VoidCallback onTap,
      required String label,
      Key? key,
    }) => Semantics(
      key: key,
      button: true,
      selected: selected,
      enabled: !done,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        enabled: !done,
        child: GestureDetector(
          onTap: done ? null : onTap,
          child: Shake(
            trigger: flashing,
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.fast),
              height: _height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: flashing
                    ? colors.error.surface
                    : selected
                    ? colors.primary.surface
                    : colors.surface,
                borderRadius: BorderRadius.circular(kidRadius),
                border: Border.all(
                  color: done
                      ? colors.success.fill
                      : selected
                      ? colors.primaryStrong
                      : colors.border,
                  width: done || selected ? 4 : 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  child,
                  if (done)
                    const PositionedDirectional(
                      top: AppSpacing.xs + AppSpacing.xxs,
                      end: AppSpacing.xs + AppSpacing.xxs,
                      child: KidStar(size: _badge),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return _Screen(
      top: AppSpacing.xl,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                container: true,
                label: 'kid_pictures'.tr(),
                child: Column(
                  children: [
                    for (final pair in question.meaningsShown) ...[
                      card(
                        id: pair.id,
                        done: state.matched.contains(pair.id),
                        selected: state.picked == pair.id,
                        flashing: false,
                        label: pair.alt.isEmpty ? pair.id : pair.alt,
                        onTap: () => cubit.pickPicture(pair.id),
                        child: KidPicture(url: pair.image, size: _picture),
                      ),
                      const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Semantics(
                container: true,
                label: 'kid_words'.tr(),
                child: Column(
                  children: [
                    for (final pair in question.wordsShown) ...[
                      card(
                        key: cardKey(pair.id),
                        id: pair.id,
                        done: state.matched.contains(pair.id),
                        selected: false,
                        flashing: state.wordFlash == pair.id,
                        label: pair.id,
                        onTap: () => cubit.pickWord(pair.id),
                        child: Text(
                          pair.id,
                          textDirection: TextDirection.ltr,
                          style: context.texts.kidsCard.copyWith(
                            color: colors.textPrimary,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The lesson's end: the guide dancing, five stars filling one by one, the
/// lesson's words, and «العب مرة أخرى» and «التالي» as icons.
class _Done extends StatelessWidget {
  const _Done({required this.state, required this.onNext});

  final KidLessonState state;
  final VoidCallback onNext;

  static const _guide = 180.0;
  static const _star = 52.0;
  static const _thumb = 48.0;
  static const _sway = .12;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<KidLessonCubit>();
    final reduce = AppMotion.reduceMotion(context);
    const guide = Mascot(expression: MascotExpression.happy, size: _guide);
    return _Screen(
      top: AppSpacing.xxxl - AppSpacing.sm,
      children: [
        if (reduce)
          guide
        else
          const RepaintBoundary(child: guide)
              .animate(onPlay: (dance) => dance.repeat(reverse: true))
              .rotate(
                begin: -_sway / 2,
                end: _sway / 2,
                alignment: const Alignment(0, .8),
                duration: AppMotion.kidDance,
                curve: AppMotion.inOut,
              )
              .moveX(begin: -AppSpacing.sm, end: AppSpacing.sm),
        const SizedBox(height: AppSpacing.xxl - AppSpacing.xs),
        Semantics(
          label: 'kid_stars'.plural(
            state.stars,
            namedArgs: {'total': '${KidLessonCubit.starCount}'},
          ),
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var star = 0; star < KidLessonCubit.starCount; star++) ...[
                  if (star > 0) const SizedBox(width: AppSpacing.sm),
                  if (star < state.stars && !reduce)
                    const KidStar(size: _star).animate().scaleXY(
                      begin: .4,
                      end: 1,
                      duration: AppMotion.kidStarFill,
                      curve: AppMotion.overshoot,
                    )
                  else
                    KidStar(size: _star, filled: star < state.stars),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Semantics(
          container: true,
          label: 'kid_lesson_words'.tr(),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs + AppSpacing.xxs,
            runSpacing: AppSpacing.xs + AppSpacing.xxs,
            children: [
              for (final word in state.kids!.words)
                Semantics(
                  label: word.word,
                  child: KidPicture(url: word.image, size: _thumb),
                ),
            ],
          ),
        ),
        const Spacer(),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KidRoundButton(
              icon: const Icon(Icons.replay_rounded),
              label: 'kid_again'.tr(),
              onPressed: cubit.again,
            ),
            const SizedBox(width: AppSpacing.xxl - AppSpacing.xs),
            KidRoundButton(
              icon: const Icon(Icons.arrow_forward_rounded),
              label: 'kid_next'.tr(),
              primary: true,
              onPressed: onNext,
            ),
          ],
        ),
      ],
    );
  }
}
