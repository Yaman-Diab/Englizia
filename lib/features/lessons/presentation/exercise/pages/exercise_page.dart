import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/slide_swap.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/exercise_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/exercise_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/exercise_top_bar.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/session_notes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The container of a lesson's exercises (requirements v3.0 §7.1, design
/// "Exercise"): the top bar, the instruction, the hint and «تحقق» belong here;
/// each template brings only its question and answers (`exerciseBody`). No
/// hearts, timer or points. The right and wrong marks are the feedback sheet's
/// forerunner.
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
                    AnimatedSize(
                      duration: AppMotion.resolve(context, AppMotion.fast),
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
                key: ValueKey(question!.id),
                child: _Question(state: state, question: question),
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

class _Question extends StatelessWidget {
  const _Question({required this.state, required this.question});

  final ExerciseState state;
  final Exercise question;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
              question.instruction,
              textDirection: TextDirection.rtl,
              style: context.texts.bodyStrong.copyWith(
                color: colors.textPrimary,
              ),
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
          exerciseBody(
            question,
            BodyAnswer(
              draft: state.draft,
              evaluation: state.evaluation,
              onDraft: cubit.updateDraft,
            ),
            BodyClip(
              status: state.audio,
              slow: state.slow,
              length: state.clipLength,
              playCount: state.playCount,
              onToggle: cubit.togglePlay,
              onSlow: cubit.playSlow,
            ),
          ),
        ],
      ),
    );
  }
}
