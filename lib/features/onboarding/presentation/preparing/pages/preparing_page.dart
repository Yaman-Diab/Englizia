import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/swap.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/onboarding/presentation/preparing/cubit/preparing_cubit.dart';
import 'package:englizia/features/onboarding/presentation/preparing/widgets/preparing_step_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Preparing" (requirements v3.0 §4.4, design "Preparing"): after the
/// account, the guide works through the learner's three steps, then cheers
/// and offers the first lesson or the placement test. A failed step says why
/// and the button retries it. The screen replaces the sign-up screens, so
/// back never returns to them.
class PreparingPage extends StatefulWidget {
  const PreparingPage({
    required this.name,
    required this.onStartLesson,
    required this.onStartTest,
    super.key,
  });

  /// The learner's name, or empty (a guest, or no name given).
  final String name;
  final VoidCallback onStartLesson;
  final VoidCallback onStartTest;

  @override
  State<PreparingPage> createState() => _PreparingPageState();
}

class _PreparingPageState extends State<PreparingPage> {
  final _action = FocusNode();

  static const _circleSize = 216.0;
  static const _mascotSize = 160.0;
  static const _compactCircleSize = 168.0;
  static const _compactMascotSize = 124.0;
  static const _compactHeight = 700.0;
  static const _stepsWidth = 264.0;

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact = MediaQuery.sizeOf(context).height < _compactHeight;
    return BlocConsumer<PreparingCubit, PreparingState>(
      // Everything is ready: the button takes the focus, so a screen reader
      // lands on it.
      listenWhen: (before, now) => now.ready && !before.ready,
      listener: (_, _) => _action.requestFocus(),
      builder: (context, state) {
        final cubit = context.read<PreparingCubit>();
        final showAction = state.ready || state.failed;
        final title = state.ready
            ? widget.name.isEmpty
                  ? 'preparing_ready'.tr()
                  : 'preparing_ready_named'.tr(namedArgs: {'name': widget.name})
            : 'preparing_title'.tr();
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.xl,
                      compact
                          ? AppSpacing.xxl
                          : AppSpacing.xxxl + AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: compact ? _compactCircleSize : _circleSize,
                          height: compact ? _compactCircleSize : _circleSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primary.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Mascot(
                            expression: switch (state) {
                              PreparingState(ready: true) =>
                                MascotExpression.excited,
                              PreparingState(failed: true) =>
                                MascotExpression.understand,
                              _ => MascotExpression.focused,
                            },
                            size: compact ? _compactMascotSize : _mascotSize,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Semantics(
                          liveRegion: true,
                          header: true,
                          child: Swap(
                            child: Text(
                              title,
                              key: ValueKey(title),
                              textAlign: TextAlign.center,
                              style: context.texts.title.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _stepsWidth,
                          ),
                          child: Column(
                            children: [
                              for (final (i, step) in state.steps.indexed) ...[
                                if (i > 0)
                                  const SizedBox(
                                    height: AppSpacing.lg + AppSpacing.xs,
                                  ),
                                PreparingStepRow(step: step, state: state),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  // The button's place is kept from the start, so nothing
                  // moves when it appears.
                  child: AnimatedOpacity(
                    opacity: showAction ? 1 : 0,
                    duration: AppMotion.resolve(context, AppMotion.medium),
                    curve: AppMotion.out,
                    child: IgnorePointer(
                      ignoring: !showAction,
                      child: ExcludeSemantics(
                        excluding: !showAction,
                        child: AppButton(
                          focusNode: _action,
                          size: AppButtonSize.large,
                          label: state.failed
                              ? 'common_retry'.tr()
                              : state.takesTest
                              ? 'preparing_start_test'.tr()
                              : 'preparing_start_lesson'.tr(),
                          onPressed: !showAction
                              ? null
                              : state.failed
                              ? cubit.retry
                              : state.takesTest
                              ? widget.onStartTest
                              : widget.onStartLesson,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
