import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/presentation/result/cubit/placement_result_cubit.dart';
import 'package:englizia/features/placement/presentation/result/widgets/level_ladder.dart';
import 'package:englizia/features/placement/presentation/widgets/guide_circle.dart';
import 'package:englizia/features/placement/presentation/widgets/scroll_edge_column.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Room over the ladder for the guide climbing it (design).
const _ladderTop = 68.0;

/// Tall enough for the design's big level code.
const _codeHeight = 64.0;
const _markSize = 20.0;

/// The placement test's result (requirements v3.0 §12.2, design "Placement
/// Result"): an honest estimate, not an exam mark. The guide climbs a ladder up
/// to the level, then come what the learner can do and how the skills compare,
/// as bars with no numbers and no colors of passing or failing.
class PlacementResultPage extends StatefulWidget {
  const PlacementResultPage({
    required this.onStart,
    required this.onLeave,
    super.key,
  });

  /// The server knows where to start: on to the lessons.
  final VoidCallback onStart;

  /// The system's back: home, never the test.
  final VoidCallback onLeave;

  @override
  State<PlacementResultPage> createState() => _PlacementResultPageState();
}

class _PlacementResultPageState extends State<PlacementResultPage>
    with TickerProviderStateMixin {
  /// Time since the reveal started; one clock for the whole scene.
  late final AnimationController _reveal;

  /// The hop down after choosing a lower level.
  late final AnimationController _lower;

  int? _lowerFrom;

  // Made here, not on first use: the screen may close before it reveals anything.
  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this);
    _lower = AnimationController(
      vsync: this,
      duration: PlacementLowerEntrance.settled,
    );
  }

  @override
  void dispose() {
    _reveal.dispose();
    _lower.dispose();
    super.dispose();
  }

  void _startReveal(int level) {
    final settled = PlacementResultEntrance(level).settled;
    _reveal.duration = settled;
    if (AppMotion.reduceMotion(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward(from: 0);
    }
  }

  void _startLower(int from) {
    _lowerFrom = from;
    if (AppMotion.reduceMotion(context)) {
      _lower.value = 1;
    } else {
      _lower.forward(from: 0);
    }
  }

  Future<void> _askToLower(PlacementResultState state) async {
    final cubit = context.read<PlacementResultCubit>();
    final current = state.level!.code;
    final lower = state.lowerLevel!.code;
    final isolated = '${Unicode.LRI}$lower${Unicode.PDI}';
    final choice = await showActionSheet(
      context,
      title: 'placement_lower_title'.tr(namedArgs: {'code': isolated}),
      body: 'placement_lower_body'.tr(),
      primaryLabel: 'placement_result_start_from'.tr(
        namedArgs: {'code': isolated},
      ),
      secondaryLabel: 'placement_lower_keep'.tr(
        namedArgs: {'code': '${Unicode.LRI}$current${Unicode.PDI}'},
      ),
      outlinedSecondary: true,
    );
    if (choice != SheetAction.primary || !mounted) return;
    final from = state.levelIndex;
    cubit.lower();
    _startLower(from);
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<PlacementResultCubit, PlacementResultState>(
        listenWhen: (before, now) =>
            now.view == PlacementResultView.ready &&
            before.view != PlacementResultView.ready,
        listener: (_, state) => _startReveal(state.levelIndex),
      ),
      BlocListener<PlacementResultCubit, PlacementResultState>(
        listenWhen: (before, now) => now.accepted && !before.accepted,
        listener: (_, _) => widget.onStart(),
      ),
      BlocListener<PlacementResultCubit, PlacementResultState>(
        listenWhen: (before, now) =>
            now.actionFailure != null &&
            now.actionFailure != before.actionFailure,
        listener: (context, state) => showFailureSnackBar(
          context,
          state.actionFailure!,
          onRetry: context.read<PlacementResultCubit>().accept,
        ),
      ),
    ],
    child: BlocBuilder<PlacementResultCubit, PlacementResultState>(
      builder: (context, state) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !state.accepting) widget.onLeave();
        },
        child: Scaffold(body: _body(context, state)),
      ),
    ),
  );

  Widget _body(BuildContext context, PlacementResultState state) {
    final cubit = context.read<PlacementResultCubit>();
    switch (state.view) {
      case PlacementResultView.loading:
        return const _Loading();
      case PlacementResultView.failed:
        return SafeArea(
          child: AppStateView.error(
            message: state.failure!.localizedMessage,
            onRetry: cubit.load,
          ),
        );
      case PlacementResultView.offline:
        return _Offline(retrying: state.retrying, onRetry: cubit.load);
      case PlacementResultView.ready:
        return AnimatedBuilder(
          animation: Listenable.merge([_reveal, _lower]),
          builder: (context, _) => _ready(context, state),
        );
    }
  }

  Widget _ready(BuildContext context, PlacementResultState state) {
    final cubit = context.read<PlacementResultCubit>();
    final colors = context.colors;
    final texts = context.texts;
    final result = state.result!;
    final level = state.level!;
    final language = context.locale.languageCode;
    final measured = PlacementResultEntrance(result.levelIndex);
    // With no reveal started, all has settled.
    final elapsed = _reveal.duration == null
        ? measured.settled
        : _reveal.duration! * _reveal.value;

    double since(Duration start, Duration length) => length == Duration.zero
        ? 1
        : ((elapsed - start).inMicroseconds / length.inMicroseconds)
              .clamp(0, 1)
              .toDouble();
    final rest = since(measured.rest, PlacementResultEntrance.restFade);
    final bars = AppMotion.smoothOut.transform(
      since(measured.rest, PlacementResultEntrance.barFill),
    );
    final lowerElapsed = PlacementLowerEntrance.settled * _lower.value;
    var levelIn = AppMotion.smoothOut.transform(
      since(measured.land, PlacementResultEntrance.levelPop),
    );
    if (_lowerFrom != null) {
      final since = lowerElapsed - PlacementLowerEntrance.level;
      levelIn = AppMotion.smoothOut.transform(
        (since.inMicroseconds /
                (PlacementLowerEntrance.settled - PlacementLowerEntrance.level)
                    .inMicroseconds)
            .clamp(0, 1)
            .toDouble(),
      );
    }

    final pre = state.isFirstLevel;
    final (String caption, TextStyle captionStyle) = state.lowered
        ? (
            'placement_result_chose'.tr(),
            texts.caption.copyWith(color: colors.textSecondary),
          )
        : pre
        ? (
            'placement_result_from_start'.tr(),
            texts.bodyStrong.copyWith(color: colors.textPrimary),
          )
        : (
            'placement_result_estimated'.tr(),
            texts.caption.copyWith(color: colors.textSecondary),
          );
    final skills = result.skills;
    final strongest = skills.isEmpty
        ? 0.0
        : skills.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    final weakest = skills.isEmpty
        ? 0.0
        : skills.map((s) => s.score).reduce((a, b) => a < b ? a : b);
    final lower = state.lowerLevel;
    final code = level.code;
    final isolated = '${Unicode.LRI}$code${Unicode.PDI}';

    return ScrollEdgeColumn(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppSpacing.xxl),
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  MediaQuery.paddingOf(context).top + _ladderTop,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  children: [
                    LevelLadder(
                      codes: [for (final l in result.levels) l.code],
                      level: state.levelIndex,
                      expression: pre
                          ? MascotExpression.encourage
                          : MascotExpression.happy,
                      moment: LadderMoment(
                        elapsed: elapsed,
                        guidePosition: _guidePosition(
                          state,
                          elapsed,
                          lowerElapsed,
                        ),
                        showSparks: !state.lowered,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Opacity(
                      opacity: levelIn,
                      child: Transform.scale(
                        scale: .9 + .1 * levelIn,
                        child: Semantics(
                          container: true,
                          liveRegion: true,
                          label: pre
                              ? 'placement_result_heading_first'.tr(
                                  namedArgs: {'caption': caption, 'code': code},
                                )
                              : 'placement_result_heading'.tr(
                                  namedArgs: {
                                    'caption': caption,
                                    'code': code,
                                    'name': level.name.of(language),
                                  },
                                ),
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                Text(
                                  caption,
                                  textAlign: TextAlign.center,
                                  style: captionStyle,
                                ),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppSpacing.md,
                                  runSpacing: AppSpacing.xs,
                                  children: [
                                    SizedBox(
                                      height: _codeHeight,
                                      child: FittedBox(
                                        fit: BoxFit.fitHeight,
                                        child: Text(
                                          code,
                                          textDirection: TextDirection.ltr,
                                          style: texts.display.copyWith(
                                            color: colors.primary.text,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!pre)
                                      Text(
                                        level.name.of(language),
                                        style: texts.title.copyWith(
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    if (state.isTopLevel && !pre)
                                      _Badge(
                                        text: 'placement_result_top'.tr(),
                                        background: colors.primary.surface,
                                        foreground: colors.primary.text,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Opacity(
              opacity: rest,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(
                      pre
                          ? 'placement_result_first_week'.tr()
                          : 'placement_result_can'.tr(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final (i, line) in level.canDo.indexed) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      _CanDo(line.of(language)),
                    ],
                    if (skills.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      _SectionTitle('placement_result_skills'.tr()),
                      const SizedBox(height: AppSpacing.md),
                      for (final (i, skill) in skills.indexed) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.lg),
                        _SkillRow(
                          skill: skill,
                          relative: strongest == 0
                              ? 0
                              : skill.score / strongest * bars,
                          strongest:
                              strongest != weakest && skill.score == strongest,
                          weakest:
                              strongest != weakest && skill.score == weakest,
                        ),
                      ],
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.xxs,
                          ),
                          child: AppIconView(
                            AppIcon.infoCircle,
                            size: AppSizes.iconSm,
                            color: colors.info.fill,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'placement_result_note'.tr(),
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      footer: SafeArea(
        top: false,
        child: Opacity(
          opacity: rest,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: pre
                      ? 'onboarding_level_beginner_cta'.tr()
                      : 'placement_result_start_from'.tr(
                          namedArgs: {'code': isolated},
                        ),
                  size: AppButtonSize.large,
                  isLoading: state.accepting,
                  onPressed: cubit.accept,
                ),
                if (lower != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: state.accepting
                        ? null
                        : () => _askToLower(state),
                    child: Text(
                      'placement_result_lower'.tr(
                        namedArgs: {
                          'code': '${Unicode.LRI}${lower.code}${Unicode.PDI}',
                        },
                      ),
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

  /// Where the guide stands: climbing during the reveal, or one hop down.
  double _guidePosition(
    PlacementResultState state,
    Duration elapsed,
    Duration lowerElapsed,
  ) {
    final from = _lowerFrom;
    if (from != null) {
      final hop =
          (lowerElapsed - PlacementLowerEntrance.hop).inMicroseconds /
          PlacementResultEntrance.hop.inMicroseconds;
      return from - hop.clamp(0, 1).toDouble();
    }
    final climbed = elapsed - PlacementResultEntrance.climb;
    if (climbed.isNegative) return 0;
    final hop = PlacementResultEntrance.hop.inMicroseconds;
    final done = climbed.inMicroseconds ~/ hop;
    if (done >= state.levelIndex) return state.levelIndex.toDouble();
    final air = PlacementResultEntrance.hopAir.inMicroseconds;
    final within = climbed.inMicroseconds - done * hop;
    return done + (within / air).clamp(0, 1).toDouble();
  }
}

/// «نحسب نتيجتك…»: the empty ladder with the guide on its first step, and the
/// app's one spinner.
class _Loading extends StatelessWidget {
  const _Loading();

  /// The usual track shape while the real one isn't known.
  static const _steps = ['Pre-A1', 'A1', 'A2', 'B1', 'B2'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppSpacing.xxl),
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              MediaQuery.paddingOf(context).top + _ladderTop,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              children: [
                const LevelLadder(
                  codes: _steps,
                  level: 0,
                  waiting: true,
                  expression: MascotExpression.focused,
                  moment: LadderMoment(
                    elapsed: Duration(seconds: 1),
                    guidePosition: 0,
                    showSparks: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'placement_result_computing'.tr(),
                    style: texts.bodyStrong.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: AppSpinner(
              size: AppSpinner.pageSize,
              color: colors.primary.fill,
            ),
          ),
        ),
      ],
    );
  }
}

/// No connection: reassurance first, in no error colors, as it isn't the
/// learner's mistake.
class _Offline extends StatelessWidget {
  const _Offline({required this.retrying, required this.onRetry});

  final bool retrying;
  final VoidCallback onRetry;

  static const _bodyMaxWidth = 290.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GuideCircle(
                          child: Mascot(
                            expression: MascotExpression.understand,
                            size: GuideCircle.guideSize,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Semantics(
                          liveRegion: true,
                          header: true,
                          child: Text(
                            'placement_result_saved'.tr(),
                            textAlign: TextAlign.center,
                            style: texts.title.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _bodyMaxWidth,
                          ),
                          child: Text(
                            'placement_result_when_back'.tr(),
                            textAlign: TextAlign.center,
                            style: texts.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: AppButton(
              label: 'common_retry'.tr(),
              size: AppButtonSize.large,
              isLoading: retrying,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: context.texts.bodyStrong.copyWith(
        color: context.colors.textPrimary,
      ),
    ),
  );
}

class _CanDo extends StatelessWidget {
  const _CanDo(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
          child: AppIconView(
            AppIcon.check,
            size: _markSize,
            color: colors.primary.fill,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: context.texts.body.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// One skill: its name, a bar relative to the strongest, and at most one badge
/// in a column of its own, so the bars line up. No numbers.
class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.skill,
    required this.relative,
    required this.strongest,
    required this.weakest,
  });

  final PlacementSkill skill;

  /// How full the bar is, 0 to 1.
  final double relative;
  final bool strongest;
  final bool weakest;

  static const _nameWidth = 64.0;
  static const _badgeWidth = 96.0;
  static const _barHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = switch (skill.kind) {
      PlacementSkillKind.vocabulary => 'placement_skill_vocabulary'.tr(),
      PlacementSkillKind.grammar => 'placement_skill_grammar'.tr(),
      PlacementSkillKind.reading => 'placement_skill_reading'.tr(),
      PlacementSkillKind.listening => 'placement_skill_listening'.tr(),
    };
    return Row(
      children: [
        SizedBox(
          width: _nameWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              name,
              style: context.texts.caption.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ExcludeSemantics(
            child: Container(
              height: _barHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(_barHeight / 2),
              ),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: relative.clamp(0, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.fill,
                    borderRadius: BorderRadius.circular(_barHeight / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: _badgeWidth,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: strongest
                ? _Badge(
                    text: 'placement_skill_strongest'.tr(),
                    background: colors.primary.surface,
                    foreground: colors.primary.text,
                  )
                : weakest
                ? _Badge(
                    text: 'placement_skill_needs_work'.tr(),
                    background: colors.info.surface,
                    foreground: colors.info.text,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  static const _height = 24.0;

  @override
  Widget build(BuildContext context) => Container(
    height: _height,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(_height / 2),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.texts.captionStrong.copyWith(color: foreground),
      ),
    ),
  );
}
