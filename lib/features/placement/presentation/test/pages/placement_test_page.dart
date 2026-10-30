import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/slide_swap.dart';
import 'package:englizia/core/design_system/motion/swap.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/design_system/widgets/notice_card.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/placement/presentation/test/cubit/placement_test_cubit.dart';
import 'package:englizia/features/placement/presentation/test/widgets/question_content.dart';
import 'package:englizia/features/placement/presentation/test/widgets/stage_bar.dart';
import 'package:englizia/features/placement/presentation/widgets/guide_circle.dart';
import 'package:englizia/features/placement/presentation/widgets/scroll_edge_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The placement test's questions (requirements v3.0 §12.2, design "Placement
/// Question"): one per screen, with no hint, correction, points or timer. The
/// bar shows the stages; between them the guide cheers on with no score. Close
/// and the system's back both ask before stopping, as answers are kept.
class PlacementTestPage extends StatelessWidget {
  const PlacementTestPage({
    required this.onStop,
    required this.onFinished,
    super.key,
  });

  /// The learner stopped for now; the answers are kept.
  final VoidCallback onStop;

  /// The last stage closed: the result follows.
  final VoidCallback onFinished;

  static const _topBarHeight = 56.0;

  Future<void> _askToStop(BuildContext context) async {
    final cubit = context.read<PlacementTestCubit>();
    if (cubit.state.sending) return;
    await cubit.interrupt();
    if (!context.mounted) return;
    final choice = await showActionSheet(
      context,
      title: 'placement_stop_title'.tr(),
      body: 'placement_stop_body'.tr(),
      primaryLabel: 'placement_continue'.tr(),
      secondaryLabel: 'placement_stop_now'.tr(),
      outlinedSecondary: true,
    );
    if (choice == SheetAction.secondary) onStop();
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<PlacementTestCubit, PlacementTestState>(
        listenWhen: (before, now) => now.finished && !before.finished,
        listener: (_, _) => onFinished(),
      ),
      BlocListener<PlacementTestCubit, PlacementTestState>(
        listenWhen: (before, now) =>
            now.actionFailure != null &&
            now.actionFailure != before.actionFailure,
        listener: (context, state) => showFailureSnackBar(
          context,
          state.actionFailure!,
          onRetry: context.read<PlacementTestCubit>().retry,
        ),
      ),
    ],
    child: BlocBuilder<PlacementTestCubit, PlacementTestState>(
      builder: (context, state) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _askToStop(context);
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _header(context, state),
                if (state.stageSizes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: StageBar(
                      sizes: state.stageSizes,
                      stage: state.stage,
                      progress: state.stageProgress,
                    ),
                  ),
                Expanded(child: _content(context, state)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context, PlacementTestState state) {
    final colors = context.colors;
    final texts = context.texts;
    final known = state.stageSizes.isNotEmpty;
    final counter = state.view == PlacementView.question
        ? '${state.index + 1} / ${state.stageSize}'
        : '${state.stageSize} / ${state.stageSize}';
    return SizedBox(
      height: _topBarHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (known)
            Swap(
              child: Text(
                _stageName(state.stage),
                key: ValueKey(state.stage),
                style: texts.captionStrong.copyWith(color: colors.textPrimary),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              0,
              AppSpacing.xl,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _askToStop(context),
                  tooltip: 'placement_stop'.tr(),
                  icon: const Icon(Icons.close_rounded),
                ),
                const Spacer(),
                if (known)
                  ExcludeSemantics(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        counter,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, PlacementTestState state) {
    final cubit = context.read<PlacementTestCubit>();
    switch (state.view) {
      case PlacementView.loading:
        return const AppStateView.loading();
      case PlacementView.failed:
        return AppStateView.error(
          message: state.failure!.localizedMessage,
          onRetry: cubit.start,
        );
      case PlacementView.question ||
          PlacementView.between ||
          PlacementView.deciding ||
          PlacementView.offline:
        final onQuestion = state.question != null;
        return ScrollEdgeColumn(
          body: SlideSwap(
            child: KeyedSubtree(
              key: ValueKey((state.view, state.stage, state.index)),
              child: onQuestion
                  ? QuestionContent(state: state)
                  : _StageEnd(state: state),
            ),
          ),
          footer: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.view == PlacementView.offline) ...[
                  NoticeCard(
                    icon: AppIcon.wifiOff,
                    title: 'placement_offline_next'.tr(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppButton(
                  label: switch (state.view) {
                    PlacementView.offline => 'common_retry'.tr(),
                    PlacementView.question => 'placement_next'.tr(),
                    _ => 'placement_go_on'.tr(),
                  },
                  size: AppButtonSize.large,
                  isLoading: state.sending,
                  onPressed: onQuestion
                      ? (state.canGoOn ? cubit.next : null)
                      : cubit.goOn,
                ),
              ],
            ),
          ),
        );
    }
  }

  static String _stageName(int stage) => switch (stage) {
    1 => 'placement_stage_1'.tr(),
    2 => 'placement_stage_2'.tr(),
    _ => 'placement_stage_3'.tr(),
  };
}

/// Between two stages: the guide, what comes next, and never a score.
class _StageEnd extends StatelessWidget {
  const _StageEnd({required this.state});

  final PlacementTestState state;

  static const _bodyMaxWidth = 290.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final next = state.next;
    final offline = state.view == PlacementView.offline;
    final (String title, String? body) = switch (state.view) {
      PlacementView.deciding => (
        'placement_deciding_title'.tr(),
        'placement_deciding_body'.plural(next!.questionCount),
      ),
      PlacementView.between => (
        state.stage == 1
            ? 'placement_finished_stage_1'.tr()
            : 'placement_finished_stage_2'.tr(),
        _nextStage(state),
      ),
      _ => ('placement_offline_title'.tr(), null),
    };
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GuideCircle(
                  child: Mascot(
                    expression: offline
                        ? MascotExpression.understand
                        : MascotExpression.encourage,
                    size: GuideCircle.guideSize,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: texts.title.copyWith(color: colors.textPrimary),
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: texts.body.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _nextStage(PlacementTestState state) {
    final next = state.next!;
    final stage = next.stage == 2
        ? 'placement_stage_2'.tr()
        : 'placement_stage_3'.tr();
    final questions = 'placement_question_count'.plural(next.questionCount);
    if (next.listeningCount == 0) {
      return 'placement_next_stage_plain'.tr(
        namedArgs: {'stage': stage, 'questions': questions},
      );
    }
    return 'placement_next_stage'.tr(
      namedArgs: {
        'stage': stage,
        'questions': questions,
        'listening': 'placement_listening_count'.plural(next.listeningCount),
      },
    );
  }
}
