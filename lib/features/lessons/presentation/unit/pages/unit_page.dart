import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/session_notes.dart';
import 'package:englizia/features/lessons/presentation/unit/cubit/unit_cubit.dart';
import 'package:englizia/features/lessons/presentation/unit/widgets/kid_unit_grid.dart';
import 'package:englizia/features/lessons/presentation/unit/widgets/unit_header.dart';
import 'package:englizia/features/lessons/presentation/unit/widgets/unit_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A unit's screen (S §6.2, §13.5, §14; design "Unit"): the learner sees what
/// it teaches and how far they are, and starts the next lesson in one press.
class UnitPage extends StatefulWidget {
  const UnitPage({
    required this.onBack,
    required this.onOpen,
    required this.onUnit,
    super.key,
  });

  final VoidCallback onBack;

  /// Opens a lesson; [kids] opens it as a kids' lesson.
  final void Function(UnitLesson lesson, {required bool kids}) onOpen;

  /// Another unit: the next one, or the one to finish first.
  final ValueChanged<UnitLink> onUnit;

  @override
  State<UnitPage> createState() => _UnitPageState();
}

class _UnitPageState extends State<UnitPage> {
  final _scroll = ScrollController();
  final _currentKey = GlobalKey();
  late final _cubit = context.read<UnitCubit>();
  Timer? _moveOn;
  var _wasOnTop = true;
  var _placed = false;

  /// The lesson the chain just moved on to, whose card opens.
  String? _arrived;

  /// Where the current lesson stays once scrolled to: under the cover's edge.
  static const _currentTop = 140.0;

  /// Nearer the top than this, the current lesson is already in view.
  static const _inView = 260.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Back on top after a lesson: what it changed shows.
    final onTop = ModalRoute.isCurrentOf(context) ?? true;
    if (onTop && !_wasOnTop) unawaited(_cubit.returned());
    _wasOnTop = onTop;
  }

  @override
  void dispose() {
    _moveOn?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// The scroll offset that brings the current lesson in view, if any.
  double? _currentOffset() {
    final box = _currentKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !_scroll.hasClients) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    return viewport?.getOffsetToReveal(box, 0).offset;
  }

  void _place() {
    if (_placed) return;
    _placed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final offset = _currentOffset();
      if (!mounted || offset == null || offset < _inView) return;
      _scroll.jumpTo(
        (offset - _currentTop).clamp(0, _scroll.position.maxScrollExtent),
      );
    });
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final offset = _currentOffset();
      if (!mounted || offset == null) return;
      final target = (offset - _currentTop).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      final duration = AppMotion.resolve(context, AppMotion.slow);
      if (duration == Duration.zero) {
        _scroll.jumpTo(target);
      } else {
        unawaited(
          _scroll.animateTo(
            target,
            duration: duration,
            curve: AppMotion.smoothOut,
          ),
        );
      }
    });
  }

  void _onSettling(BuildContext context, UnitState state) {
    _moveOn?.cancel();
    if (state.settling == null) {
      final plan = state.plan;
      final current = plan == null ? -1 : plan.current;
      setState(() => _arrived = current < 0 ? null : plan!.lessons[current].id);
      _scrollToCurrent();
      return;
    }
    final wait = AppMotion.resolve(context, AppMotion.unitMoveOn);
    if (wait == Duration.zero) {
      _cubit.settled();
    } else {
      _moveOn = Timer(wait, _cubit.settled);
    }
  }

  void _open(UnitPlan plan, UnitLesson lesson) =>
      widget.onOpen(lesson, kids: plan.kids);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    body: SafeArea(
      child: BlocConsumer<UnitCubit, UnitState>(
        listenWhen: (previous, current) =>
            previous.settling != current.settling,
        listener: _onSettling,
        builder: (context, state) {
          final plan = state.plan;
          if (plan == null) {
            return state.load == LoadStatus.failure
                ? Column(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          tooltip: 'common_back'.tr(),
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      Expanded(
                        child: AppStateView.error(
                          message: state.failure?.localizedMessage ?? '',
                          onRetry: _cubit.refresh,
                        ),
                      ),
                    ],
                  )
                : _UnitSkeleton(onBack: widget.onBack);
          }
          _place();
          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scroll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UnitCover(
                      url: plan.coverUrl,
                      scroll: _scroll,
                      onBack: widget.onBack,
                      extra: plan.kids && plan.titleAudioUrl != null
                          ? KidGuideButton(
                              label: 'unit_say_name'.tr(),
                              speaking: state.speaking,
                              expression: state.speaking
                                  ? MascotExpression.talk
                                  : MascotExpression.welcome,
                              onPressed: _cubit.sayUnit,
                            )
                          : null,
                    ),
                    if (!state.online)
                      OfflineBand(message: 'unit_offline'.tr()),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.xl - AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.xl - AppSpacing.xs,
                        AppSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          UnitSummary(
                            plan: plan,
                            goalsOpen: state.goalsOpen,
                            onGoals: _cubit.toggleGoals,
                          ),
                          if (_banner(plan) case final banner?) ...[
                            const SizedBox(height: AppSpacing.lg + 4),
                            banner,
                          ],
                          SizedBox(
                            height: plan.kids
                                ? AppSpacing.lg + 4
                                : AppSpacing.xl,
                          ),
                          if (plan.kids)
                            KidUnitGrid(
                              plan: plan,
                              status: state.status,
                              available: state.available,
                              currentKey: _currentKey,
                              onPressed: (lesson) => _pressKid(state, lesson),
                            )
                          else
                            UnitTimeline(
                              plan: plan,
                              status: state.status,
                              available: state.available,
                              settling: state.settling,
                              arrived: _arrived,
                              currentKey: _currentKey,
                              onOpen: (lesson) => _open(plan, lesson),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              UnitTopBar(
                title: plan.title,
                scroll: _scroll,
                onBack: widget.onBack,
              ),
            ],
          );
        },
      ),
    ),
  );

  /// A locked card says its name; an open one opens.
  // ASSUMPTION(design): the design's cards only say their names; an open one
  // has to start its lesson somehow, and the lesson's guide then speaks.
  void _pressKid(UnitState state, UnitLesson lesson) {
    final index = state.plan!.lessons.indexOf(lesson);
    if (state.status(index) == UnitLessonStatus.locked ||
        !state.available(lesson)) {
      unawaited(_cubit.sayLesson(lesson));
      return;
    }
    _open(state.plan!, lesson);
  }

  Widget? _banner(UnitPlan plan) {
    if (plan.lockedBy case final before?) {
      return UnitBanner.locked(
        message: 'unit_locked'.tr(args: ['${before.number}']),
        action: 'unit_go_to'.tr(args: ['${before.number}']),
        onAction: () => widget.onUnit(before),
      );
    }
    if (!plan.complete) return null;
    final next = plan.next;
    return UnitBanner.done(
      message: 'unit_done'.tr(args: ['${plan.number}']),
      action: next == null ? null : 'unit_next'.tr(args: [next.title]),
      onAction: next == null ? null : () => widget.onUnit(next),
    );
  }
}

/// The shape of the screen while it loads, breathing slowly.
class _UnitSkeleton extends StatefulWidget {
  const _UnitSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_UnitSkeleton> createState() => _UnitSkeletonState();
}

class _UnitSkeletonState extends State<_UnitSkeleton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.skeletonPulse * .5,
  );

  static const _rows = [.62, .48, .70, .54, .44];
  static const _faded = .5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      unawaited(_pulse.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = context.scheme.surfaceContainerHigh;
    Widget bar(double height, {double? width, double share = 1}) {
      final shape = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: width != null
            ? shape
            : FractionallySizedBox(widthFactor: share, child: shape),
      );
    }

    return Semantics(
      label: 'common_loading'.tr(),
      liveRegion: true,
      child: Stack(
        children: [
          FadeTransition(
            opacity: Tween(begin: 1.0, end: _faded).animate(_pulse),
            child: ExcludeSemantics(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: UnitCover.height,
                      child: ColoredBox(color: tone),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(
                        AppSpacing.xl - AppSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(14, width: 72),
                          const SizedBox(height: AppSpacing.md),
                          bar(28, width: 200),
                          const SizedBox(height: AppSpacing.lg),
                          bar(8),
                          const SizedBox(height: AppSpacing.sm),
                          bar(12, width: 90),
                          const SizedBox(
                            height: AppSpacing.xxl - AppSpacing.xs,
                          ),
                          for (final share in _rows) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: tone,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      top: AppSpacing.xs,
                                    ),
                                    child: Column(
                                      children: [
                                        bar(16, share: share),
                                        const SizedBox(height: AppSpacing.sm),
                                        bar(12, share: .4),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl - 2),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: AppSpacing.xs,
            start: AppSpacing.xs,
            child: IconButton(
              tooltip: 'common_back'.tr(),
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
