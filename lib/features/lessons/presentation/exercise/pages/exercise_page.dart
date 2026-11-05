import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/slide_swap.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/exercise_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/exercise_top_bar.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/feedback_sheet.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/session_notes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The container of a lesson's exercises (requirements v3.0 §7.1, design
/// "Exercise"): the top bar, the instruction, the hint and «تحقق» belong here;
/// each template brings only its question and answers (`exerciseBody`), and the
/// feedback takes «تحقق»'s place. No hearts, timer or points on the screen.
class ExercisePage extends StatelessWidget {
  const ExercisePage({
    required this.onExit,
    required this.onFinished,
    required this.onExplain,
    super.key,
  });

  final VoidCallback onExit;

  /// The last question is done.
  final ValueChanged<LessonSummary> onFinished;

  /// «اشرح لي».
  final ValueChanged<ExplainRequest> onExplain;

  static const _topBarHeight = 56.0;
  static const _sheetGuide = 96.0;

  /// A light touch for right, a stronger one for wrong (S §7.2).
  void _feel(Evaluation? evaluation) {
    switch (evaluation) {
      case null ||
          ReviewPending() ||
          ReviewLater() ||
          SpokenOffTopic() ||
          ReviewQuotaOut():
        return;
      case _ when evaluation.correct:
        AppHaptics.lightImpact();
      default:
        AppHaptics.mediumImpact();
    }
  }

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
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<ExerciseCubit, ExerciseState>(
        listenWhen: (before, now) => now.finished && !before.finished,
        listener: (context, _) =>
            onFinished(context.read<ExerciseCubit>().summary),
      ),
      BlocListener<ExerciseCubit, ExerciseState>(
        listenWhen: (before, now) => before.evaluation != now.evaluation,
        listener: (_, state) => _feel(state.evaluation),
      ),
    ],
    child: BlocBuilder<ExerciseCubit, ExerciseState>(
      builder: (context, state) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _askToLeave(context);
        },
        child: Scaffold(
          body: SafeArea(
            // The sheet's color reaches the phone's edge; each footer
            // keeps its own distance from it.
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _topBarHeight,
                  child: ExerciseTopBar(
                    position: state.position,
                    total: state.questions.length,
                    hasHint: state.question?.hint != null,
                    hintOpen: state.hintOpen,
                    hintUsed: state.hintUsed,
                    onExit: () => _askToLeave(context),
                    onHint: context.read<ExerciseCubit>().toggleHint,
                  ),
                ),
                SmoothSize(
                  duration: AppMotion.fast,
                  curve: AppMotion.out,
                  alignment: AlignmentDirectional.topStart,
                  child: state.online
                      ? const SizedBox(width: double.infinity)
                      : const OfflineBand(),
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
                key: ValueKey(question!.stayKey),
                child: _Question(state: state, question: question),
              ),
            ),
          ),
          _Footer(state: state, question: question, onExplain: onExplain),
        ],
      ),
    };
  }
}

/// «تحقق», and then the feedback in its place: the button fades as the sheet
/// comes up. Matching checks itself, so it has nothing here until it ends.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.question,
    required this.onExplain,
  });

  final ExerciseState state;
  final Exercise question;
  final ValueChanged<ExplainRequest> onExplain;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExerciseCubit>();
    final inset = MediaQuery.paddingOf(context).bottom;
    final evaluation = state.evaluation;
    final Widget child;
    if (evaluation != null) {
      child = FeedbackSheet(
        key: ValueKey('feedback:${question.id}'),
        exercise: question,
        evaluation: evaluation,
        draft: state.draft,
        hinted: state.hintUsed,
        xp: state.xpPerAnswer,
        explainEnabled: state.explainEnabled,
        clip: FeedbackClip(
          playing: state.audio == ClipStatus.playing,
          onToggle: cubit.toggleAnswerClip,
        ),
        onNext: cubit.next,
        onExplain: () => onExplain(
          ExplainRequest(
            questionId: question.id,
            lessonId: cubit.lessonId,
            draft: state.draft!,
            lessonExplanation: question.explanation,
          ),
        ),
        onReport: cubit.report,
        onRetry: cubit.retrySpeech,
        onSkip: cubit.skipQuestion,
      );
    } else if (!state.showsCheck) {
      child = SizedBox(key: const ValueKey('none'), height: inset);
    } else {
      child = Padding(
        key: const ValueKey('check'),
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.md + inset,
        ),
        child: AppButton(
          label: 'lesson_check'.tr(),
          size: AppButtonSize.large,
          onPressed: state.canCheck ? cubit.check : null,
        ),
      );
    }
    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.quick),
      switchInCurve: AppMotion.out,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      // Sized by what is arriving: what leaves only fades over it.
      layoutBuilder: (current, previous) => Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.bottomCenter,
        children: [
          for (final leaving in previous)
            PositionedDirectional(start: 0, end: 0, bottom: 0, child: leaving),
          ?current,
        ],
      ),
      child: child,
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.state, required this.question});

  final ExerciseState state;
  final Exercise question;

  static const _padding = AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<ExerciseCubit>();
    final reference = question.bookReference;
    final clip = BodyClip(
      status: state.audio,
      slow: state.slow,
      length: state.clipLength,
      playCount: state.playCount,
      onToggle: cubit.togglePlay,
      onSlow: cubit.playSlow,
      onStop: cubit.stopAudio,
    );
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            question.instruction,
            textDirection: TextDirection.rtl,
            style: context.texts.bodyStrong.copyWith(color: colors.textPrimary),
          ),
        ),
        if (reference != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BookBadge(reference: reference),
          ),
        ],
        if (question.hint case final hint?)
          HintCard(hint: hint, open: state.hintOpen),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
    final body = exerciseBody(
      question,
      BodyAnswer(
        draft: state.draft,
        evaluation: state.evaluation,
        onDraft: cubit.updateDraft,
        onSubmit: cubit.check,
      ),
      clip,
      onSkipSpeech: cubit.skipSpeech,
    );
    final pinned = exercisePinned(
      question,
      clip,
      screenHeight: MediaQuery.sizeOf(context).height,
    );
    if (pinned == null) {
      return SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          _padding,
          _padding,
          _padding,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [head, body],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            _padding,
            _padding,
            _padding,
            0,
          ),
          sliver: SliverToBoxAdapter(child: head),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedPart(child: pinned.child, height: pinned.height),
        ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            _padding,
            AppSpacing.lg,
            _padding,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(child: body),
        ),
      ],
    );
  }
}

/// Stays at the top while the question scrolls under it, which its own
/// background hides.
class _PinnedPart extends SliverPersistentHeaderDelegate {
  const _PinnedPart({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) =>
      ColoredBox(
        color: context.colors.background,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: _Question._padding,
          ),
          child: child,
        ),
      );

  @override
  bool shouldRebuild(_PinnedPart oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}
