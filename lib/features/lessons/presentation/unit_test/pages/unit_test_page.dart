import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/slide_swap.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/lessons/domain/entities/unit_test.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/exercise_body.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/exercise_top_bar.dart';
import 'package:englizia/features/lessons/presentation/unit_test/cubit/unit_test_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A unit's test (the backend's note B-33b): what it takes, its questions one
/// at a time with no hint or mark, then the server's result.
// ASSUMPTION(design): no design for the test; its questions take the
// exercise screen's container and bodies, with «التالي» in «تحقق»'s place,
// and its start and result are this page's own (docs/STATUS.md).
class UnitTestPage extends StatelessWidget {
  const UnitTestPage({required this.onDone, super.key});

  /// Back to where the test was opened from.
  final VoidCallback onDone;

  static const _topBarHeight = 56.0;
  static const _guide = 96.0;
  static const _sheetGuide = 96.0;

  Future<void> _askToLeave(BuildContext context) async {
    final cubit = context.read<UnitTestCubit>();
    if (cubit.state.phase != UnitTestPhase.answering) return onDone();
    await cubit.stopAudio();
    if (!context.mounted) return;
    final choice = await showActionSheet(
      context,
      illustration: const Mascot(
        expression: MascotExpression.encourage,
        size: _sheetGuide,
      ),
      title: 'unit_test_exit_title'.tr(),
      body: 'unit_test_exit_body'.tr(),
      primaryLabel: 'unit_test_exit_stay'.tr(),
      secondaryLabel: 'unit_test_exit_leave'.tr(),
      outlinedSecondary: true,
    );
    if (choice == SheetAction.secondary) onDone();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<UnitTestCubit, UnitTestViewState>(
        builder: (context, state) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _askToLeave(context);
          },
          child: Scaffold(
            body: SafeArea(
              child: switch (state.phase) {
                UnitTestPhase.loading => const AppStateView.loading(),
                UnitTestPhase.failure => AppStateView.error(
                  message: state.failure is NetworkFailure
                      ? 'unit_test_needs_connection'.tr()
                      : state.failure!.localizedMessage,
                  onRetry: context.read<UnitTestCubit>().start,
                ),
                UnitTestPhase.intro => _Intro(
                  state: state,
                  onExit: () => _askToLeave(context),
                ),
                UnitTestPhase.answering || UnitTestPhase.sending => _Questions(
                  state: state,
                  onExit: () => _askToLeave(context),
                ),
                UnitTestPhase.result => _Result(state: state, onDone: onDone),
              },
            ),
          ),
        ),
      );
}

/// «05:42»: what is left of a wait.
String _clock(Duration left) {
  final minutes = left.inMinutes;
  final seconds = left.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class _Close extends StatelessWidget {
  const _Close({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: IconButton(
      tooltip: 'unit_test_close'.tr(),
      onPressed: onExit,
      icon: AppIconView(AppIcon.cross, color: context.colors.textSecondary),
    ),
  );
}

class _Intro extends StatelessWidget {
  const _Intro({required this.state, required this.onExit});

  final UnitTestViewState state;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<UnitTestCubit>();
    final status = state.test!.status;
    final wait = state.waitLeft;
    final note = switch (status.state) {
      UnitTestState.locked => 'unit_test_locked'.tr(),
      _ when wait != null => 'unit_test_wait'.tr(
        namedArgs: {'time': _clock(wait)},
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: UnitTestPage._topBarHeight,
          child: _Close(onExit: onExit),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Mascot(
                    expression: MascotExpression.focused,
                    size: UnitTestPage._guide,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'unit_test_title'.tr(),
                  textAlign: TextAlign.center,
                  style: texts.title.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'unit_test_what'.tr(
                    namedArgs: {
                      'questions': 'unit_test_questions'.plural(
                        status.questionCount,
                      ),
                      'percent': '${status.passPercent}',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: texts.body.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'unit_test_how'.tr(),
                  textAlign: TextAlign.center,
                  style: texts.body.copyWith(color: colors.textSecondary),
                ),
                if (status.bestPercent case final best?) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'unit_test_best'.tr(namedArgs: {'percent': '$best'}),
                    textAlign: TextAlign.center,
                    style: texts.bodyStrong.copyWith(color: colors.textPrimary),
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    liveRegion: wait == null,
                    child: Text(
                      note,
                      textAlign: TextAlign.center,
                      style: texts.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: AppButton(
            label: status.state == UnitTestState.passed
                ? 'unit_test_again'.tr()
                : 'unit_test_start'.tr(),
            size: AppButtonSize.large,
            onPressed: state.canStart ? cubit.begin : null,
          ),
        ),
      ],
    );
  }
}

class _Questions extends StatelessWidget {
  const _Questions({required this.state, required this.onExit});

  final UnitTestViewState state;
  final VoidCallback onExit;

  static const _padding = AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<UnitTestCubit>();
    final question = state.question!;
    final sending = state.phase == UnitTestPhase.sending;
    final clip = BodyClip(
      status: state.audio,
      slow: state.slow,
      length: state.clipLength,
      playCount: state.playCount,
      onToggle: cubit.togglePlay,
      onSlow: cubit.playSlow,
      onStop: cubit.stopAudio,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: UnitTestPage._topBarHeight,
          child: ExerciseTopBar(
            position: state.index,
            total: state.test!.questions.length,
            hasHint: false,
            hintOpen: false,
            hintUsed: false,
            onExit: onExit,
            onHint: () {},
          ),
        ),
        Expanded(
          child: SlideSwap(
            child: KeyedSubtree(
              key: ValueKey(question.id),
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  _padding,
                  _padding,
                  _padding,
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
                        style: texts.bodyStrong.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    exerciseBody(
                      question,
                      BodyAnswer(
                        draft: state.draft,
                        evaluation: null,
                        onDraft: cubit.updateDraft,
                        onSubmit: () {},
                        blind: true,
                      ),
                      clip,
                      onSkipSpeech: () {},
                    ),
                  ],
                ),
              ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.sendFailed) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'unit_test_send_failed'.tr(),
                    textAlign: TextAlign.center,
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppButton(
                label: state.isLast
                    ? 'unit_test_send'.tr()
                    : 'unit_test_next'.tr(),
                size: AppButtonSize.large,
                isLoading: sending,
                onPressed: state.canGoOn && !sending ? cubit.next : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.state, required this.onDone});

  final UnitTestViewState state;
  final VoidCallback onDone;

  static const _dot = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final result = state.result!;
    final wait = state.waitLeft;
    final cubit = context.read<UnitTestCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Mascot(
                    expression: result.passed
                        ? MascotExpression.happy
                        : MascotExpression.encourage,
                    size: UnitTestPage._guide,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    result.passed
                        ? 'unit_test_passed'.tr()
                        : 'unit_test_failed'.tr(),
                    textAlign: TextAlign.center,
                    style: texts.title.copyWith(color: colors.textPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'unit_test_percent'.tr(
                    namedArgs: {'percent': '${result.percent}'},
                  ),
                  textAlign: TextAlign.center,
                  style: texts.display.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'unit_test_score'.tr(
                    namedArgs: {
                      'correct': '${result.correct}',
                      'total': '${result.questionCount}',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: texts.body.copyWith(color: colors.textSecondary),
                ),
                if (result.marks.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final (i, right) in result.marks.indexed)
                        Semantics(
                          label: right
                              ? 'unit_test_mark_right'.tr(
                                  namedArgs: {'n': '${i + 1}'},
                                )
                              : 'unit_test_mark_wrong'.tr(
                                  namedArgs: {'n': '${i + 1}'},
                                ),
                          child: Container(
                            width: _dot,
                            height: _dot,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: right
                                  ? colors.success.surface
                                  : colors.error.surface,
                            ),
                            child: AppIconView(
                              right ? AppIcon.check : AppIcon.cross,
                              size: AppSizes.iconSm,
                              color: right
                                  ? colors.success.text
                                  : colors.error.text,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (!result.passed) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'unit_test_need'.tr(
                      namedArgs: {'percent': '${result.passPercent}'},
                    ),
                    textAlign: TextAlign.center,
                    style: texts.body.copyWith(color: colors.textSecondary),
                  ),
                  if (wait != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'unit_test_wait'.tr(namedArgs: {'time': _clock(wait)}),
                      textAlign: TextAlign.center,
                      style: texts.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ],
                if (result.suggestion case final suggestion?
                    when !state.chosen) ...[
                  const SizedBox(height: AppSpacing.xl),
                  LevelSuggestionCard(
                    suggestion: suggestion,
                    busy: state.choosing,
                    onChoose: (move) async {
                      final failure = await cubit.chooseLevel(move: move);
                      if (failure != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(failure.localizedMessage)),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sm,
            children: [
              if (!result.passed && wait == null)
                AppButton(
                  label: 'unit_test_again'.tr(),
                  size: AppButtonSize.large,
                  onPressed: cubit.start,
                ),
              AppButton(
                label: 'unit_test_done'.tr(),
                variant: !result.passed && wait == null
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                size: AppButtonSize.large,
                onPressed: onDone,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The level the server suggests after the first unit's test: «انتقل» or
/// «ابقَ» (the backend's note B-33b, its M2), on the result and on home.
class LevelSuggestionCard extends StatelessWidget {
  const LevelSuggestionCard({
    required this.suggestion,
    required this.onChoose,
    this.busy = false,
    super.key,
  });

  final LevelSuggestion suggestion;

  /// True to move to the level suggested.
  final ValueChanged<bool> onChoose;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.primary.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: [
            Text(
              'level_suggestion_score'.tr(
                namedArgs: {'percent': '${suggestion.percent}'},
              ),
              style: texts.body.copyWith(color: colors.textPrimary),
            ),
            Text(
              'level_suggestion_offer'.tr(
                namedArgs: {'level': suggestion.suggested.label},
              ),
              style: texts.bodyStrong.copyWith(color: colors.textPrimary),
            ),
            AppButton(
              label: 'level_suggestion_move'.tr(
                namedArgs: {'level': suggestion.suggested.label},
              ),
              isLoading: busy,
              onPressed: busy ? null : () => onChoose(true),
            ),
            AppButton(
              label: 'level_suggestion_stay'.tr(
                namedArgs: {'level': suggestion.level.label},
              ),
              variant: AppButtonVariant.secondary,
              onPressed: busy ? null : () => onChoose(false),
            ),
          ],
        ),
      ),
    );
  }
}
