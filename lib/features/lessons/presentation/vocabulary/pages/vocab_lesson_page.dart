import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/vocabulary.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/exercise_top_bar.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_controls.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/cubit/vocab_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/widgets/vocab_card.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/widgets/vocab_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A vocabulary lesson's cards (requirements v3.0 §8.5, design "Vocab Lesson"),
/// then the lesson's words together, before its exercises.
class VocabLessonPage extends StatefulWidget {
  const VocabLessonPage({
    required this.onExit,
    required this.onStartExercises,
    required this.onShowWords,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onStartExercises;
  final VoidCallback onShowWords;

  @override
  State<VocabLessonPage> createState() => _VocabLessonPageState();
}

class _VocabLessonPageState extends State<VocabLessonPage> {
  /// Cards whose pictures load before they show (S §8.5).
  static const _ahead = 2;

  late final _cubit = context.read<VocabLessonCubit>();

  /// The next cards' pictures, so a slow connection doesn't hold them up.
  void _loadAhead(VocabLessonState state) {
    for (var i = state.index + 1; i <= state.index + _ahead; i++) {
      if (i >= state.words.length) break;
      final url = state.words[i].imageUrl;
      if (url != null && url.startsWith('http')) {
        unawaited(precacheImage(NetworkImage(url), context));
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<VocabLessonCubit, VocabLessonState>(
        listenWhen: (before, now) =>
            before.index != now.index || before.load != now.load,
        listener: (_, state) {
          if (state.load == LoadStatus.ready) _loadAhead(state);
        },
        child: Scaffold(
          body: SafeArea(
            child: BlocBuilder<VocabLessonCubit, VocabLessonState>(
              buildWhen: (before, now) =>
                  before.load != now.load ||
                  before.index != now.index ||
                  before.review != now.review ||
                  before.words != now.words,
              builder: (context, state) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(state: state, onExit: widget.onExit),
                  Expanded(
                    child: switch (state.load) {
                      LoadStatus.loading => const AppStateView.loading(),
                      LoadStatus.failure => AppStateView.error(
                        message: state.failure!.localizedMessage,
                        onRetry: _cubit.start,
                      ),
                      LoadStatus.ready => _ready(state),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _ready(VocabLessonState loaded) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (loaded.review)
              _Review(onSay: _cubit.sayWordAt)
            else
              SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.xl - AppSpacing.xs,
                ),
                child: VocabDeck(
                  index: loaded.index,
                  count: loaded.words.length,
                  onNext: _cubit.next,
                  onPrevious: _cubit.previous,
                  cardAt: (index, {required top}) => top
                      ? _TopCard(index: index)
                      : VocabCard(word: loaded.words[index]),
                ),
              ),
            PositionedDirectional(
              start: AppSpacing.xl - AppSpacing.xs,
              end: AppSpacing.xl - AppSpacing.xs,
              bottom: AppSpacing.sm,
              child: _Notices(onShowWords: widget.onShowWords),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.md,
        ),
        child: loaded.review
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'vocab_start_exercises'.tr(),
                    size: AppButtonSize.large,
                    onPressed: widget.onStartExercises,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: 'vocab_again'.tr(),
                    variant: AppButtonVariant.text,
                    onPressed: _cubit.again,
                  ),
                ],
              )
            : Row(
                children: [
                  _PreviousButton(
                    onTap: loaded.index == 0 ? null : _cubit.previous,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'vocab_next'.tr(),
                      size: AppButtonSize.large,
                      onPressed: _cubit.next,
                    ),
                  ),
                ],
              ),
      ),
    ],
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onExit});

  final VocabLessonState state;
  final VoidCallback onExit;

  static const _height = 56.0;
  static const _counter = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = state.words.length;
    return SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.xl - AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onExit,
              tooltip: 'lesson_gv_exit'.tr(),
              color: colors.textSecondary,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (count > 0) ...[
              Expanded(
                child: LessonProgressBar(
                  position: state.review ? count : state.index + 1,
                  total: count,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _counter),
                child: Text(
                  state.review
                      ? 'vocab_review_counter'.tr()
                      : 'vocab_counter'.tr(
                          namedArgs: {
                            'at': '${state.index + 1}',
                            'of': '$count',
                          },
                        ),
                  textAlign: TextAlign.end,
                  style: context.texts.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The top card, following what is said and saved on it.
class _TopCard extends StatelessWidget {
  const _TopCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VocabLessonCubit>();
    return BlocSelector<VocabLessonCubit, VocabLessonState, VocabCardView>(
      selector: (state) => VocabCardView(
        saved: state.saved.contains(state.words[index].id),
        revealed: state.revealed.contains(index),
        wordRun: state.index == index ? state.wordRun : null,
        exampleRun: state.index == index ? state.exampleRun : null,
        audioFailed: state.audioFailed,
      ),
      builder: (context, view) => VocabCard(
        word: cubit.state.words[index],
        view: view,
        onSave: cubit.toggleSaved,
        onSayWord: cubit.sayWord,
        onSayExample: cubit.sayExample,
        onReveal: cubit.reveal,
      ),
    );
  }
}

class _PreviousButton extends StatelessWidget {
  const _PreviousButton({required this.onTap});

  final VoidCallback? onTap;

  static const _size = 56.0;
  static const _dimmed = .38;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Opacity(
      opacity: onTap == null ? _dimmed : 1,
      child: PressScale(
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: 'vocab_previous'.tr(),
          excludeSemantics: true,
          child: Material(
            color: colors.surface,
            shape: CircleBorder(side: BorderSide(color: colors.border)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(
                dimension: _size,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Over the buttons: the sound's trouble, and that a word was saved.
class _Notices extends StatelessWidget {
  const _Notices({required this.onShowWords});

  final VoidCallback onShowWords;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<VocabLessonCubit, VocabLessonState>(
        buildWhen: (before, now) =>
            before.audioFailed != now.audioFailed ||
            before.muted != now.muted ||
            before.index != now.index ||
            before.review != now.review ||
            before.savedNotice != now.savedNotice,
        builder: (context, state) {
          final cubit = context.read<VocabLessonCubit>();
          final cards = !state.review;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cards && state.audioFailed)
                _SoundNote(
                  text: 'vocab_audio_failed'.tr(),
                  onRetry: cubit.retryAudio,
                )
              else if (cards && state.muted && state.index == 0)
                _SoundNote(text: 'vocab_muted'.tr()),
              if (state.savedNotice) ...[
                const SizedBox(height: AppSpacing.sm),
                ReaderSavedNotice(
                  text: 'reader_saved_notice'.tr(),
                  onShow: onShowWords,
                ),
              ],
            ],
          );
        },
      );
}

class _SoundNote extends StatelessWidget {
  const _SoundNote({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onRetry = this.onRetry;
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: _height),
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md + AppSpacing.xxs,
          end: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            AppIconView(
              onRetry == null ? AppIcon.volume : AppIcon.volumeOff,
              size: AppSizes.iconSm + AppSpacing.xs,
              color: colors.info.fill,
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            Expanded(
              child: Text(
                text,
                style: context.texts.caption.copyWith(color: colors.info.text),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text('vocab_retry'.tr())),
          ],
        ),
      ),
    );
  }
}

/// «كلمات هذا الدرس»: each card's picture, word and meaning, and a star on those
/// saved. Pressing one says it.
class _Review extends StatelessWidget {
  const _Review({required this.onSay});

  final ValueChanged<int> onSay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return BlocBuilder<VocabLessonCubit, VocabLessonState>(
      buildWhen: (before, now) => before.saved != now.saved,
      builder: (context, state) => CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.xl - AppSpacing.xs,
            ),
            sliver: SliverList.list(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'vocab_review_title'.tr(),
                    style: texts.title.copyWith(color: colors.textPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'vocab_review_hint'.tr(),
                  style: texts.caption.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, box) {
                    final width = (box.maxWidth - AppSpacing.md) / 2;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        for (final (i, word) in state.words.indexed)
                          SizedBox(
                            width: width,
                            child: _ReviewTile(
                              word: word,
                              saved: state.saved.contains(word.id),
                              onTap: () => onSay(i),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.word,
    required this.saved,
    required this.onTap,
  });

  final VocabWord word;
  final bool saved;
  final VoidCallback onTap;

  static const _letter = 48.0;
  static const _star = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final url = word.imageUrl;
    return PressScale(
      child: Semantics(
        button: true,
        label: 'vocab_review_tile_said'.tr(
          namedArgs: {'word': word.word, 'meaning': word.arabic},
        ),
        excludeSemantics: true,
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(
                AppSpacing.sm + AppSpacing.xxs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppRadius.md - AppSpacing.xxs,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (url == null)
                            VocabLetter(word: word.word, size: _letter)
                          else
                            ColoredBox(
                              color: colors.tiles.neutral.background,
                              child: url.startsWith('http')
                                  ? Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => VocabLetter(
                                        word: word.word,
                                        size: _letter,
                                      ),
                                    )
                                  : SvgPicture.asset(url),
                            ),
                          PositionedDirectional(
                            end: AppSpacing.sm,
                            top: AppSpacing.sm,
                            child: AnimatedOpacity(
                              opacity: saved ? 1 : 0,
                              duration: AppMotion.resolve(
                                context,
                                AppMotion.quick,
                              ),
                              child: Icon(
                                Icons.star_rounded,
                                size: _star,
                                color: colors.reward.fill,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word,
                          textDirection: TextDirection.ltr,
                          locale: const Locale('en'),
                          style: texts.bodyStrong.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          word.arabic,
                          textDirection: TextDirection.rtl,
                          style: texts.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
