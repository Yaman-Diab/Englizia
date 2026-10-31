import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/presentation/grammar/cubit/grammar_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/grammar/widgets/grammar_player.dart';
import 'package:englizia/features/lessons/presentation/grammar/widgets/rule_summary_card.dart';
import 'package:englizia/features/lessons/presentation/grammar/widgets/teacher_questions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A grammar lesson before its exercises (requirements v3.0 §8.1, design "Grammar
/// Video"): the video with no autoplay, its teacher, the rule in short and the
/// learner's own questions, and a button that opens the exercises once enough was
/// watched. With no video, the rule comes first and the exercises are open.
class GrammarLessonPage extends StatefulWidget {
  const GrammarLessonPage({
    required this.onStartExercises,
    required this.onExit,
    super.key,
  });

  final VoidCallback onStartExercises;
  final VoidCallback onExit;

  @override
  State<GrammarLessonPage> createState() => _GrammarLessonPageState();
}

class _GrammarLessonPageState extends State<GrammarLessonPage>
    with WidgetsBindingObserver {
  static const _barHeight = 56.0;

  final _scroll = ScrollController();
  bool _fullscreen = false;
  bool _overflows = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// A call or leaving the app stops the video (S §8.1).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      final cubit = context.read<GrammarLessonCubit>();
      if (cubit.state.playing) unawaited(cubit.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    if (_fullscreen) unawaited(_systemUi(fullscreen: false));
    super.dispose();
  }

  Future<void> _systemUi({required bool fullscreen}) async {
    await SystemChrome.setPreferredOrientations(
      fullscreen
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    await SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _toggleFullscreen() {
    final to = !_fullscreen;
    setState(() => _fullscreen = to);
    unawaited(_systemUi(fullscreen: to));
  }

  bool _followScroll(ScrollMetrics metrics) {
    final overflows = metrics.extentAfter > 2;
    if (overflows != _overflows) setState(() => _overflows = overflows);
    return false;
  }

  /// «شاهد الفيديو»: starts it, and brings it into view.
  void _watch() {
    final cubit = context.read<GrammarLessonCubit>();
    unawaited(
      _scroll.animateTo(
        0,
        duration: AppMotion.resolve(context, AppMotion.medium),
        curve: AppMotion.inOut,
      ),
    );
    if (!cubit.state.playing) unawaited(cubit.play());
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<GrammarLessonCubit, GrammarLessonState>(
        listenWhen: (before, now) => !before.unlocked && now.celebrating,
        listener: (_, _) => unawaited(HapticFeedback.lightImpact()),
        buildWhen: (before, now) =>
            before.load != now.load ||
            before.content != now.content ||
            before.unlocked != now.unlocked ||
            before.saying != now.saying,
        builder: (context, state) => PopScope(
          canPop: !_fullscreen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _fullscreen) _toggleFullscreen();
          },
          child: Scaffold(
            backgroundColor: _fullscreen
                ? context.colors.reader.videoBackground
                : null,
            body: _fullscreen
                ? GrammarPlayer(
                    fullscreen: true,
                    onToggleFullscreen: _toggleFullscreen,
                  )
                : SafeArea(child: _portrait(state)),
          ),
        ),
      );

  Widget _portrait(GrammarLessonState state) {
    final content = state.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _barHeight,
          child: _TopBar(state: state, onExit: widget.onExit),
        ),
        Expanded(
          child: switch (state.load) {
            LoadStatus.loading => const AppStateView.loading(),
            LoadStatus.failure => AppStateView.error(
              message: state.failure!.localizedMessage,
              onRetry: context.read<GrammarLessonCubit>().start,
            ),
            LoadStatus.ready => NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) => _followScroll(n.metrics),
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (n) => _followScroll(n.metrics),
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (content?.video != null)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: GrammarPlayer(
                            fullscreen: false,
                            onToggleFullscreen: _toggleFullscreen,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (content?.video != null) ...[
                              const _Teacher(),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                            if (content != null)
                              RuleSummaryCard(
                                summary: content.summary,
                                bookPage: content.video == null
                                    ? content.bookPage
                                    : null,
                                saying: state.saying,
                                onSay: context
                                    .read<GrammarLessonCubit>()
                                    .sayExample,
                              ),
                            if ((content?.questionsEnabled ?? false) &&
                                content?.video != null) ...[
                              const SizedBox(height: AppSpacing.xxl),
                              TeacherQuestionsSection(
                                videoPosition: () => context
                                    .read<GrammarLessonCubit>()
                                    .state
                                    .position,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          },
        ),
        if (state.load == LoadStatus.ready)
          _Footer(
            showsEdge: _overflows,
            onWatch: _watch,
            onStart: widget.onStartExercises,
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onExit});

  final GrammarLessonState state;
  final VoidCallback onExit;

  static const _side = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final title = state.lessonTitle;
    return Stack(
      children: [
        PositionedDirectional(
          start: AppSpacing.md,
          top: AppSpacing.xs,
          child: IconButton(
            onPressed: onExit,
            tooltip: 'lesson_gv_exit'.tr(),
            color: colors.textSecondary,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: _side),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texts.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                if (state.content != null)
                  Text(
                    state.video != null
                        ? 'lesson_kind_grammar_video'.tr()
                        : 'lesson_gv_rule_lesson'.tr(),
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Who teaches it, how long it is, and «شاهدته» once it has been watched enough.
class _Teacher extends StatelessWidget {
  const _Teacher();

  static const _avatar = 40.0;
  static const _badgeHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return BlocSelector<GrammarLessonCubit, GrammarLessonState, bool>(
      selector: (state) => state.unlocked,
      builder: (context, unlocked) {
        final state = context.read<GrammarLessonCubit>().state;
        final name = state.content?.teacherName;
        final watched = unlocked && state.watchedPercent > 0;
        return Row(
          children: [
            if (name != null) ...[
              ExcludeSemantics(
                child: Container(
                  width: _avatar,
                  height: _avatar,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    name.characters.first,
                    style: texts.bodyStrong.copyWith(
                      color: colors.primary.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name != null)
                    Text(
                      name,
                      style: texts.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  Text(
                    'lesson_gv_video_length'.tr(
                      namedArgs: {
                        'time': videoTime(
                          state.video?.duration ?? Duration.zero,
                        ),
                      },
                    ),
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (watched)
              Container(
                height: _badgeHeight,
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.sm,
                  end: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: colors.success.surface,
                  borderRadius: BorderRadius.circular(_badgeHeight / 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconView(
                      AppIcon.check,
                      size: AppSizes.iconSm,
                      color: colors.success.fill,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'lesson_gv_watched_badge'.tr(),
                      style: texts.captionStrong.copyWith(
                        color: colors.success.text,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.showsEdge,
    required this.onWatch,
    required this.onStart,
  });

  final bool showsEdge;
  final VoidCallback onWatch;
  final VoidCallback onStart;

  static const _barHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return BlocBuilder<GrammarLessonCubit, GrammarLessonState>(
      buildWhen: (before, now) =>
          before.watchedPercent != now.watchedPercent ||
          before.unlocked != now.unlocked ||
          before.celebrating != now.celebrating ||
          before.started != now.started,
      builder: (context, state) {
        final required = state.content?.requiredPercent ?? 100;
        final showsPercent = !state.unlocked && state.watchedPercent > 0;
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
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SmoothSize(
                child: state.celebrating
                    ? const _Unlocked()
                    : const SizedBox(width: double.infinity),
              ),
              if (showsPercent) ...[
                Text(
                  'lesson_gv_watched'.tr(
                    namedArgs: {
                      'watched': '${state.watchedPercent}',
                      'required': '$required',
                    },
                  ),
                  style: texts.caption.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  child: SizedBox(
                    height: _barHeight,
                    child: ColoredBox(
                      color: context.scheme.outline,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AnimatedFractionallySizedBox(
                          heightFactor: 1,
                          duration: AppMotion.resolve(
                            context,
                            AppMotion.sheetIn,
                          ),
                          curve: AppMotion.out,
                          widthFactor: (state.watchedPercent / required).clamp(
                            0,
                            1,
                          ),
                          child: ColoredBox(color: colors.primary.fill),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _MainButton(
                unlocked: state.unlocked,
                celebrating: state.celebrating,
                watchLabel: state.started
                    ? 'lesson_gv_keep_watching'.tr()
                    : 'lesson_gv_watch'.tr(),
                onWatch: onWatch,
                onStart: onStart,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Unlocked extends StatelessWidget {
  const _Unlocked();

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
          color: colors.success.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            AppIconView(
              AppIcon.check,
              size: AppSizes.iconSm + AppSpacing.xxs,
              color: colors.success.fill,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'lesson_gv_can_start'.tr(),
                style: context.texts.captionStrong.copyWith(
                  color: colors.success.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «شاهد الفيديو» turning into «ابدأ التمارين», with a shine crossing it once: the
/// one moment of the screen.
class _MainButton extends StatelessWidget {
  const _MainButton({
    required this.unlocked,
    required this.celebrating,
    required this.watchLabel,
    required this.onWatch,
    required this.onStart,
  });

  final bool unlocked;
  final bool celebrating;
  final String watchLabel;
  final VoidCallback onWatch;
  final VoidCallback onStart;

  static const _height = 56.0;
  static const _shineWidth = .22;
  static const _shineDelay = Duration(milliseconds: 220);
  static const _shineLength = Duration(milliseconds: 750);
  static const _shineAlpha = .32;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.texts.button.copyWith(color: colors.onPrimaryStrong);
    final label = unlocked ? 'lesson_gv_start'.tr() : watchLabel;
    return PressScale(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_height / 2),
          child: Material(
            color: colors.primaryStrong,
            child: InkWell(
              onTap: unlocked ? onStart : onWatch,
              child: SizedBox(
                height: _height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.resolve(context, AppMotion.fast),
                      child: Row(
                        key: ValueKey(label),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!unlocked) ...[
                            Icon(
                              Icons.play_arrow_rounded,
                              size: AppSizes.iconMd,
                              color: colors.onPrimaryStrong,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Text(label, style: style),
                        ],
                      ),
                    ),
                    if (celebrating)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: TimedValue(
                            delay: _shineDelay,
                            duration: _shineLength,
                            curve: AppMotion.inOut,
                            builder: (_, value) => value >= 1
                                ? const SizedBox.shrink()
                                : FractionallySizedBox(
                                    widthFactor: _shineWidth,
                                    alignment: AlignmentDirectional(
                                      -1.6 + 3.2 * value,
                                      0,
                                    ),
                                    child: ColoredBox(
                                      color: colors.onPrimaryStrong.withValues(
                                        alpha: _shineAlpha,
                                      ),
                                    ),
                                  ),
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
    );
  }
}
