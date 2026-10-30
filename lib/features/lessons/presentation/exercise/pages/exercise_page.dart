import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/slide_swap.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/answer_card.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/question_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The container of a lesson's exercises (requirements v3.0 §7.1, design
/// "Exercise"): the top bar, the instruction, the hint and «تحقق» belong here;
/// each template brings only its question and answers. No hearts, timer or
/// points. The right and wrong marks are the feedback sheet's forerunner.
class ExercisePage extends StatelessWidget {
  const ExercisePage({
    required this.onExit,
    required this.onFinished,
    super.key,
  });

  final VoidCallback onExit;

  /// The last question is done.
  final VoidCallback onFinished;

  static const _topBarHeight = 56.0;
  static const _sheetGuide = 96.0;

  Future<void> _askToLeave(BuildContext context) async {
    final cubit = context.read<ExerciseCubit>();
    await cubit.stopAudio();
    if (!context.mounted) return;
    final choice = await showActionSheet(
      context,
      illustration: const Mascot(
        expression: MascotExpression.encourage,
        size: _sheetGuide,
      ),
      title: 'lesson_exit_title'.tr(),
      body: 'lesson_exit_body'.tr(),
      primaryLabel: 'lesson_exit_stay'.tr(),
      secondaryLabel: 'lesson_exit_leave'.tr(),
      outlinedSecondary: true,
    );
    if (choice == SheetAction.secondary) onExit();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ExerciseCubit, ExerciseState>(
        listenWhen: (before, now) => now.finished && !before.finished,
        listener: (_, _) => onFinished(),
        child: BlocBuilder<ExerciseCubit, ExerciseState>(
          builder: (context, state) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _askToLeave(context);
            },
            child: Scaffold(
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _topBarHeight,
                      child: _TopBar(
                        state: state,
                        onExit: () => _askToLeave(context),
                      ),
                    ),
                    AnimatedSize(
                      duration: AppMotion.resolve(context, AppMotion.fast),
                      curve: AppMotion.out,
                      alignment: AlignmentDirectional.topStart,
                      child: state.online
                          ? const SizedBox(width: double.infinity)
                          : const _OfflineBand(),
                    ),
                    Expanded(child: _body(context, state)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _body(BuildContext context, ExerciseState state) {
    final cubit = context.read<ExerciseCubit>();
    final question = state.question;
    return switch (state.load) {
      LoadStatus.loading => const AppStateView.loading(),
      LoadStatus.failure => AppStateView.error(
        message: state.failure!.localizedMessage,
        onRetry: cubit.start,
      ),
      LoadStatus.ready when question == null => const SizedBox.shrink(),
      LoadStatus.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SlideSwap(
              child: KeyedSubtree(
                key: ValueKey(state.index),
                child: _Question(state: state, question: question!),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: AppButton(
              label: state.checked ? 'lesson_next'.tr() : 'lesson_check'.tr(),
              size: AppButtonSize.large,
              onPressed: state.checked
                  ? cubit.next
                  : state.canCheck
                  ? cubit.check
                  : null,
            ),
          ),
        ],
      ),
    };
  }
}

/// Leaving, the lesson's progress, and the hint. With no hint the button is
/// gone but keeps its space, so the bar doesn't change width.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onExit});

  final ExerciseState state;
  final VoidCallback onExit;

  static const _endInset = 20.0;
  static const _hintCircle = 40.0;
  static const _hintIcon = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasHint = state.question?.hint != null;
    final used = state.hintUsed;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md,
        end: _endInset,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            tooltip: 'lesson_exit'.tr(),
            color: colors.textSecondary,
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _ProgressBar(
              done: state.done,
              total: state.questions.length,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Visibility(
            visible: hasHint,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: IconButton(
              onPressed: hasHint
                  ? context.read<ExerciseCubit>().toggleHint
                  : null,
              tooltip: state.hintOpen
                  ? 'lesson_hint_hide'.tr()
                  : 'lesson_hint_show'.tr(),
              style: IconButton.styleFrom(
                padding: EdgeInsetsDirectional.zero,
                fixedSize: const Size.square(AppSizes.minTapTarget),
              ),
              icon: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.quick),
                width: _hintCircle,
                height: _hintCircle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: used ? colors.info.surface : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: used ? Colors.transparent : colors.info.fill,
                    width: 1.5,
                  ),
                ),
                child: AppIconView(
                  AppIcon.lightbulb,
                  size: _hintIcon,
                  color: colors.info.fill,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The lesson's progress: it starts as a dot, so it reads as a bar and not an
/// empty line, and stretches with a small overshoot.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.done, required this.total});

  final int done;
  final int total;

  static const _height = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final share = total == 0 ? 0.0 : done / total;
    return Semantics(
      label: 'lesson_progress'.tr(),
      value: '$done / $total',
      child: ExcludeSemantics(
        child: Container(
          height: _height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedContainer(
                duration: AppMotion.resolve(context, AppMotion.slow),
                curve: AppMotion.bounce,
                width: _height + (constraints.maxWidth - _height) * share,
                height: _height,
                decoration: BoxDecoration(
                  color: colors.primary.fill,
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin band, not an error: it isn't the learner's mistake, and «تحقق» works.
class _OfflineBand extends StatelessWidget {
  const _OfflineBand();

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        color: colors.info.surface,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm - AppSpacing.xxs,
          ),
          child: Row(
            children: [
              AppIconView(
                AppIcon.wifiOff,
                size: _iconSize,
                color: colors.info.fill,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'lesson_offline'.tr(),
                  style: context.texts.caption.copyWith(
                    color: colors.info.text,
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

class _Question extends StatelessWidget {
  const _Question({required this.state, required this.question});

  final ExerciseState state;
  final Exercise question;

  AnswerLook _lookOf(ExerciseOption option) {
    final chosen = option.id == state.selectedId;
    if (!state.checked) return chosen ? AnswerLook.selected : AnswerLook.idle;
    if (option.correct) return AnswerLook.correct;
    return chosen ? AnswerLook.wrong : AnswerLook.dimmed;
  }

  void _select(BuildContext context, ExerciseOption option) {
    HapticFeedback.selectionClick();
    context.read<ExerciseCubit>().select(option.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final language = context.locale.languageCode;
    final cubit = context.read<ExerciseCubit>();
    final reference = question.bookReference;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              question.instruction.of(language),
              style: texts.bodyStrong.copyWith(color: colors.textPrimary),
            ),
          ),
          if (reference != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _BookBadge(text: reference.of(language)),
            ),
          ],
          if (question.hint case final hint?)
            _HintCard(hint: hint, open: state.hintOpen),
          const SizedBox(height: AppSpacing.lg),
          switch (question.kind) {
            ExerciseKind.multipleChoice => BlankSentence(
              question: question,
              word: state.selected?.text,
            ),
            ExerciseKind.imageChoice => SpokenWord(
              word: question.word,
              playing: state.audio == ExerciseAudio.playing,
              onTap: cubit.togglePlay,
            ),
            ExerciseKind.listeningChoice => ListeningPlayer(state: state),
          },
          const SizedBox(height: AppSpacing.xl),
          if (question.kind == ExerciseKind.imageChoice)
            _PictureGrid(
              options: question.options,
              lookOf: _lookOf,
              onSelect: state.checked ? null : (o) => _select(context, o),
            )
          else
            for (final (i, option) in question.options.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              TextAnswer(
                text: option.text,
                look: _lookOf(option),
                onTap: state.checked ? null : () => _select(context, option),
              ),
            ],
        ],
      ),
    );
  }
}

class _BookBadge extends StatelessWidget {
  const _BookBadge({required this.text});

  final String text;

  static const _height = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: _height,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconView(
            AppIcon.book,
            size: AppSizes.iconSm,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens under the instruction, pushing down what is under it.
class _HintCard extends StatelessWidget {
  const _HintCard({required this.hint, required this.open});

  final ExerciseHint hint;
  final bool open;

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final duration = AppMotion.resolve(context, AppMotion.fast);
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.out,
      alignment: AlignmentDirectional.topStart,
      child: !open
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
              child: Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.info.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIconView(
                          AppIcon.lightbulb,
                          size: _iconSize,
                          color: colors.info.fill,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: texts.body.copyWith(
                                color: colors.info.text,
                              ),
                              children: [
                                TextSpan(
                                  text: hint.text.of(
                                    context.locale.languageCode,
                                  ),
                                ),
                                TextSpan(
                                  text: hint.term,
                                  locale: const Locale('en'),
                                  style: texts.bodyStrong.copyWith(
                                    color: colors.info.text,
                                  ),
                                ),
                              ],
                            ),
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

/// Square pictures, two by two. Each has a name for screen readers.
class _PictureGrid extends StatelessWidget {
  const _PictureGrid({
    required this.options,
    required this.lookOf,
    required this.onSelect,
  });

  final List<ExerciseOption> options;
  final AnswerLook Function(ExerciseOption) lookOf;
  final ValueChanged<ExerciseOption>? onSelect;

  static const _columns = 2;
  static const _badgeInset = 8.0;
  static const _badge = 24.0;

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    return GridView.count(
      crossAxisCount: _columns,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final option in options)
          AnswerCard(
            look: lookOf(option),
            radius: AppRadius.lg,
            semanticLabel: option.imageAlt?.of(language),
            onTap: onSelect == null ? null : () => onSelect!(option),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.all(AppSpacing.md),
                  child: _Picture(url: option.imageUrl),
                ),
                PositionedDirectional(
                  top: _badgeInset,
                  end: _badgeInset,
                  child: AnswerMark(
                    look: lookOf(option),
                    showRing: false,
                    size: _badge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A picture from the server, on a soft circle. Mock lessons name bundled files.
class _Picture extends StatelessWidget {
  const _Picture({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSvg = url.toLowerCase().endsWith('.svg');
    final isRemote = url.startsWith('http');
    final Widget picture = switch ((isRemote, isSvg)) {
      (false, _) => SvgPicture.asset(url),
      (true, true) => SvgPicture.network(
        url,
        placeholderBuilder: (_) => const AppSpinner(),
      ),
      (true, false) => Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, image, progress) =>
            progress == null ? image : const AppSpinner(),
        errorBuilder: (context, _, _) => Center(
          child: AppIconView(AppIcon.infoCircle, color: colors.textSecondary),
        ),
      ),
    };
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary.surface,
          shape: BoxShape.circle,
        ),
        child: picture,
      ),
    );
  }
}
