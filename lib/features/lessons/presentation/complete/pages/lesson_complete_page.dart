import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/presentation/complete/cubit/lesson_complete_cubit.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/complete_hero.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/complete_stats.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/kind_icon.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/today_card.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/unit_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A quiet, honest celebration with the learner's real numbers, then the next
/// lesson with one press (design "Lesson Complete"). The arrival takes under two
/// seconds and a press anywhere jumps to its end, which is the same state reduce
/// motion shows: each piece already knows how to be simply there.
///
/// The numbers that come from the server start when they arrive, never before
/// the moment the design gives them.
class LessonCompletePage extends StatefulWidget {
  const LessonCompletePage({
    required this.onNext,
    required this.onBack,
    required this.onWords,
    super.key,
  });

  final ValueChanged<NextStep> onNext;

  /// «العودة إلى الوحدة», and the phone's back.
  final VoidCallback onBack;

  /// «اعرضها».
  final VoidCallback onWords;

  @override
  State<LessonCompletePage> createState() => _LessonCompletePageState();
}

class _LessonCompletePageState extends State<LessonCompletePage> {
  final _clock = Stopwatch()..start();
  final _scroll = ScrollController();
  Timer? _toGoal;
  bool _skipped = false;
  bool _overflows = false;
  Duration? _dataLead;

  @override
  void initState() {
    super.initState();
    unawaited(AppHaptics.lightImpact());
  }

  @override
  void dispose() {
    _toGoal?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// The card is usually under the fold, and this is the moment not to miss.
  void _bringGoalIntoView() {
    if (AppMotion.reduceMotion(context)) return;
    _dataLead ??= _leadNow();
    _toGoal = Timer(_dataLead! + LessonCompleteEntrance.scrollAfterData, () {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.medium,
          curve: AppMotion.inOut,
        ),
      );
    });
  }

  /// How long until the server's numbers may start, fixed when they arrive.
  Duration _leadNow() {
    final left =
        LessonCompleteEntrance.xp.inMilliseconds - _clock.elapsedMilliseconds;
    return Duration(milliseconds: math.max(0, left));
  }

  bool _followScroll(ScrollMetrics metrics) {
    final overflows = metrics.extentAfter > 2;
    if (overflows != _overflows) setState(() => _overflows = overflows);
    return false;
  }

  String _said(LessonCompleteState state) {
    final result = state.result;
    return [
      _title(state),
      if (state.counted > 0)
        'lesson_done_said_first'.tr(
          namedArgs: {
            'right': '${state.rightFirstTime}',
            'total': '${state.counted}',
          },
        ),
      if (result?.xp case final xp?)
        'lesson_done_said_xp'.tr(namedArgs: {'xp': '$xp'}),
      if (result?.goal?.justMet ?? false) 'lesson_done_goal_reached'.tr(),
    ].join(' ');
  }

  String _title(LessonCompleteState state) {
    if (state.replay) return 'lesson_done_replayed'.tr();
    if (state.unitDone) {
      return 'lesson_done_unit'.tr(
        namedArgs: {'unit': '${state.unit!.number}'},
      );
    }
    return 'lesson_complete_title'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: _skipped ? media.copyWith(disableAnimations: true) : media,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onBack();
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            _toGoal?.cancel();
            if (!_skipped) setState(() => _skipped = true);
          },
          child: BlocConsumer<LessonCompleteCubit, LessonCompleteState>(
            listenWhen: (before, now) =>
                before.result == null && now.result != null,
            listener: (_, state) {
              if (state.result?.goal?.justMet ?? false) {
                unawaited(AppHaptics.mediumImpact());
                _bringGoalIntoView();
              }
            },
            builder: (context, state) {
              if (state.result != null) _dataLead ??= _leadNow();
              return Scaffold(
                body: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _content(state)),
                      _Footer(
                        state: state,
                        showsEdge: _overflows,
                        onNext: widget.onNext,
                        onBack: widget.onBack,
                      ),
                      Semantics(
                        liveRegion: true,
                        label: _said(state),
                        child: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(LessonCompleteState state) {
    final result = state.result;
    final lead = _dataLead ?? Duration.zero;
    final unit = state.unit;
    final goal = result?.goal;
    final streak = result?.streak;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _followScroll(n.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _followScroll(n.metrics),
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CompleteHero(),
              const SizedBox(height: AppSpacing.xl),
              CompleteTitle(
                title: _title(state),
                lesson: state.summary.outline.title,
                perfect: state.perfect,
              ),
              Entrance(
                motion: EntranceMotion.up,
                delay: LessonCompleteEntrance.body,
                duration: AppMotion.closeUp,
                distance: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    CompleteStats(state: state, xpDelay: lead),
                    _Arrives(
                      child: CompleteExtras(
                        state: state,
                        onWords: widget.onWords,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      UnitChain(
                        unit: unit,
                        lessonId: state.summary.lessonId,
                        moved: !state.replay,
                      ),
                    ],
                    _Arrives(
                      child: goal != null && streak != null
                          ? Padding(
                              padding: const EdgeInsetsDirectional.only(
                                top: AppSpacing.xl,
                              ),
                              child: TodayCard(
                                goal: goal,
                                streak: streak,
                                lead: lead,
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the server brings late opens its place rather than jumping in.
class _Arrives extends StatelessWidget {
  const _Arrives({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SmoothSize(
    duration: AppMotion.fast,
    curve: AppMotion.out,
    alignment: AlignmentDirectional.topStart,
    child: child,
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.showsEdge,
    required this.onNext,
    required this.onBack,
  });

  final LessonCompleteState state;
  final bool showsEdge;
  final ValueChanged<NextStep> onNext;
  final VoidCallback onBack;

  static const _nextIcon = AppSizes.iconSm;

  String _nextLine(NextStep next) => switch (next.kind) {
    NextKind.lesson => 'lesson_done_next_lesson_line'.tr(
      namedArgs: {'kind': lessonKindName(next.lessonKind), 'title': next.title},
    ),
    NextKind.unitReview => 'lesson_done_next_review_line'.tr(),
    NextKind.unit => 'lesson_done_next_unit_line'.tr(
      namedArgs: {'unit': '${next.unitNumber ?? ''}', 'title': next.title},
    ),
  };

  String _action(NextStep next) => switch (next.kind) {
    NextKind.lesson => 'lesson_done_next_lesson'.tr(),
    NextKind.unitReview => 'lesson_done_start_review'.tr(),
    NextKind.unit => 'lesson_done_next_unit'.tr(),
  };

  AppIcon _icon(NextStep next) => switch (next.kind) {
    NextKind.lesson => lessonKindIcon(next.lessonKind),
    NextKind.unitReview => AppIcon.lessonReview,
    NextKind.unit => AppIcon.unitFlag,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final next = state.next;
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.quick),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: showsEdge ? colors.border : Colors.transparent,
          ),
        ),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmoothSize(
            duration: AppMotion.fast,
            curve: AppMotion.out,
            child: state.waitingForServer
                ? const _SavedOnPhone()
                : const SizedBox(width: double.infinity),
          ),
          if (next != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIconView(
                  _icon(next),
                  size: _nextIcon,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    _nextLine(next),
                    textAlign: TextAlign.center,
                    style: context.texts.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: _action(next),
              size: AppButtonSize.large,
              onPressed: () => onNext(next),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          AppButton(
            label: 'lesson_done_back'.tr(),
            variant: next == null
                ? AppButtonVariant.primary
                : AppButtonVariant.text,
            size: next == null ? AppButtonSize.large : AppButtonSize.regular,
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

class _SavedOnPhone extends StatelessWidget {
  const _SavedOnPhone();

  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconView(
              AppIcon.wifiOff,
              size: _iconSize,
              color: colors.info.fill,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'lesson_done_saved_on_phone'.tr(),
                style: context.texts.caption.copyWith(color: colors.info.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
