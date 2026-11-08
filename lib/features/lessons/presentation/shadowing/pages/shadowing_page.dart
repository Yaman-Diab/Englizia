import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/count_up.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/design_system/widgets/lesson_progress_bar.dart';
import 'package:englizia/core/design_system/widgets/mic_permission_sheet.dart';
import 'package:englizia/core/design_system/widgets/said_word.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/mic_block.dart';
import 'package:englizia/features/lessons/presentation/shadowing/cubit/shadowing_cubit.dart';
import 'package:englizia/features/lessons/presentation/shadowing/widgets/shadowing_parts.dart';
import 'package:englizia/features/lessons/presentation/video/lesson_player.dart';
import 'package:englizia/features/lessons/presentation/widgets/karaoke_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shadowing (requirements v3.0 §9, design "Shadowing"): a sentence, its model
/// and the three ways of saying it, the microphone, and how many of its words
/// were heard. From a lesson it leads to the exercises; from «تدرّب», given
/// [practiceFrom], it only goes from sentence to sentence.
class ShadowingPage extends StatefulWidget {
  const ShadowingPage({
    required this.onExit,
    required this.onDone,
    required this.onSkip,
    this.practiceFrom,
    super.key,
  });

  final VoidCallback onExit;

  /// Past the last sentence.
  final VoidCallback onDone;

  /// «لا أستطيع التحدث الآن» and «تخطَّ الشادوينغ»: the whole step.
  final VoidCallback onSkip;

  /// The lesson the sentences were saved from, when practising them.
  final String? practiceFrom;

  @override
  State<ShadowingPage> createState() => _ShadowingPageState();
}

class _ShadowingPageState extends State<ShadowingPage>
    with WidgetsBindingObserver {
  /// After the model, a second for the learner to finish (design's note).
  static const _afterModel = Duration(seconds: 1);

  late final _cubit = context.read<ShadowingCubit>();
  late final _mic = context.read<MicCubit>();
  final _levels = <double>[];
  StreamSubscription<double>? _listening;
  DateTime? _since;
  Duration _listenFor = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mic.reset();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_mic.recheck());
    } else {
      _cubit.stopModel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_listening?.cancel());
    super.dispose();
  }

  Future<void> _tapMic() async {
    final mic = _mic;
    if (mic.state.phase == MicPhase.listening) return mic.stop();
    if (mic.state.phase == MicPhase.thinking) return;
    switch (await mic.access()) {
      case MicAccess.granted:
        unawaited(AppHaptics.selectionClick());
        await _listen();
      case MicAccess.denied:
        mic.showDenied();
      case MicAccess.notAsked:
        if (!mounted) return;
        if (await showMicPermissionSheet(context)) await mic.ask();
    }
  }

  Future<void> _listen() async {
    _levels.clear();
    unawaited(_listening?.cancel());
    _listening = _mic.levels.listen(_levels.add);
    _since = DateTime.now();
    if (_cubit.state.together) {
      final length = _cubit.startTogether() + _afterModel;
      setState(() => _listenFor = length);
      await _mic.listen(silence: length, limit: length);
    } else {
      _cubit.stopModel();
      await _mic.listen();
    }
  }

  void _onMic(MicState state) {
    if (state.phase == MicPhase.listening) return;
    unawaited(_listening?.cancel());
    _listening = null;
    if (state.phase == MicPhase.notHeard) _cubit.stopModel();
    if (state.phase != MicPhase.heard) return;
    final since = _since;
    _cubit.heard(
      state.transcript,
      length: since == null ? Duration.zero : DateTime.now().difference(since),
      levels: List.of(_levels),
    );
  }

  void _retry() {
    _mic.reset();
    _cubit.retry();
  }

  void _next() {
    _mic.reset();
    _cubit.next();
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<MicCubit, MicState>(
        listenWhen: (before, now) => before.phase != now.phase,
        listener: (_, state) => _onMic(state),
      ),
      BlocListener<ShadowingCubit, ShadowingState>(
        listenWhen: (before, now) => !before.finished && now.finished,
        listener: (_, _) => widget.onDone(),
      ),
    ],
    child: Scaffold(
      body: SafeArea(
        child: BlocBuilder<ShadowingCubit, ShadowingState>(
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                state: state,
                practiceFrom: widget.practiceFrom,
                onExit: widget.onExit,
              ),
              Expanded(
                child: switch (state.load) {
                  LoadStatus.loading => const AppStateView.loading(),
                  LoadStatus.failure => AppStateView.error(
                    message: state.failure!.localizedMessage,
                    onRetry: _cubit.start,
                  ),
                  LoadStatus.ready => _ready(state),
                },
              ),
              if (state.load == LoadStatus.ready && state.attempt != null)
                _Footer(
                  label: state.isLast && widget.practiceFrom == null
                      ? 'shadow_to_exercises'.tr()
                      : widget.practiceFrom != null
                      ? 'shadow_next_sentence'.tr()
                      : 'shadow_next'.tr(),
                  onRetry: _retry,
                  onNext: _next,
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _ready(ShadowingState state) {
    final colors = context.colors;
    final texts = context.texts;
    final sentence = state.sentence!;
    final attempt = state.attempt;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShadowingModeSwitch(
                  mode: state.mode,
                  onPick: (mode) {
                    _mic.reset();
                    unawaited(_cubit.setMode(mode));
                  },
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.xs,
                    0,
                  ),
                  child: Text(
                    switch (state.mode) {
                      ShadowingMode.repeat => 'shadow_mode_repeat_hint'.tr(),
                      ShadowingMode.together =>
                        'shadow_mode_together_hint'.tr(),
                      ShadowingMode.hidden => 'shadow_mode_hidden_hint'.tr(),
                    },
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: _SentenceCard(
              key: ValueKey('${state.at}:${state.mode}'),
              state: state,
              video: state.content!.video != null,
              cubit: _cubit,
            ),
          ),
          if (attempt != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.xl - AppSpacing.xs,
                0,
              ),
              child: _Result(
                key: ValueKey(state.counts.length),
                state: state,
                attempt: attempt,
                sentence: sentence,
                onCompare: _cubit.compare,
              ),
            )
          else
            BlocBuilder<MicCubit, MicState>(
              builder: (context, mic) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.mode == ShadowingMode.together &&
                      !state.headphonesSeen &&
                      mic.phase != MicPhase.listening)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: _HeadphonesNote(
                        onDismiss: _cubit.dismissHeadphones,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: state.together && mic.phase == MicPhase.listening
                        ? Column(
                            children: [
                              const SizedBox(height: AppSpacing.xl),
                              LiveWave(
                                levels: _mic.levels,
                                length: _listenFor,
                                onStop: _mic.stop,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _RecordingDot(seconds: mic.seconds),
                            ],
                          )
                        : MicBlock(
                            state: mic,
                            levels: _mic.levels,
                            onTap: _tapMic,
                            onOpenSettings: _mic.openSettings,
                            onSkip: widget.onSkip,
                            caption: state.together
                                ? 'shadow_start_together'.tr()
                                : null,
                            skipLabel: 'shadow_skip'.tr(),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.practiceFrom,
    required this.onExit,
  });

  final ShadowingState state;
  final String? practiceFrom;
  final VoidCallback onExit;

  static const _height = 56.0;
  static const _counter = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final practiceFrom = this.practiceFrom;
    final count = state.order.length;
    return SizedBox(
      height: _height,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.xl - AppSpacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onExit,
              tooltip: 'lesson_gv_exit'.tr(),
              color: colors.textSecondary,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (practiceFrom != null)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'shadow_title'.tr(),
                      style: texts.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'shadow_from'.tr(namedArgs: {'title': practiceFrom}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texts.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (count > 0) ...[
              Expanded(
                child: LessonProgressBar(
                  position: state.at + 1,
                  total: count,
                  label: 'shadow_progress'.tr(),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _counter),
                child: Text(
                  'shadow_counter'.tr(
                    namedArgs: {'at': '${state.at + 1}', 'of': '$count'},
                  ),
                  textAlign: TextAlign.end,
                  style: texts.caption.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The sentence, its model and the model's speed. Hidden as bars while
/// practising without the text, until the try's verdict shows it.
class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.state,
    required this.video,
    required this.cubit,
    super.key,
  });

  final ShadowingState state;
  final bool video;
  final ShadowingCubit cubit;

  static const _lineHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final sentence = state.sentence!;
    final heard = state.attempt?.heard;
    final hidden = state.mode == ShadowingMode.hidden && heard == null;
    final style = texts.reading.copyWith(color: colors.textPrimary);
    final words = sentence.words;
    final card = Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl - AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          if (video) ...[
            Semantics(
              image: true,
              label: 'shadow_video_frame'.tr(),
              excludeSemantics: true,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: _VideoStill(
                    url:
                        sentence.imageUrl ??
                        state.content!.video?.video.coverUrl,
                    caption: [
                      videoTime(sentence.start),
                      ?state.title,
                    ].join(' · '),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (hidden)
            HiddenWords(sentence: sentence)
          else
            Semantics(
              label: sentence.english,
              excludeSemantics: true,
              child: KaraokeText(
                count: words.length,
                run: heard == null ? state.modelRun : null,
                alignment: WrapAlignment.center,
                spacing:
                    MediaQuery.textScalerOf(
                      context,
                    ).scale(style.fontSize ?? 20) *
                    .28,
                runSpacing:
                    _lineHeight - (style.fontSize ?? 20) * (style.height ?? 1),
                saidAt: (elapsed, _) {
                  final at = sentence.start + elapsed * state.speed;
                  int? said;
                  for (final (i, word) in words.indexed) {
                    if (at >= word.start) said = i;
                  }
                  return said;
                },
                word: (context, i) => heard == null
                    ? Text(
                        words[i].text,
                        locale: const Locale('en'),
                        style: style,
                      )
                    : SaidWord(word: words[i].text, index: i, heard: heard[i]),
              ),
            ),
          if (!hidden) ...[
            const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
            Text(
              sentence.arabic,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: texts.body.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              _ModelButton(
                playing: state.modelRun != null,
                onTap: state.modelRun != null
                    ? cubit.stopModel
                    : cubit.playModel,
              ),
              _SpeedSwitch(speed: state.speed, onPick: cubit.setSpeed),
            ],
          ),
        ],
      ),
    );
    return AppMotion.reduceMotion(context)
        ? card
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.closeUp,
            curve: AppMotion.out,
            builder: (_, value, child) => Opacity(opacity: value, child: child),
            child: card,
          );
  }
}

/// A still of the video at the sentence (S §9): the server's picture, or its
/// moment and the lesson's name on the video's own dark.
class _VideoStill extends StatelessWidget {
  const _VideoStill({required this.url, required this.caption});

  final String? url;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    final url = this.url;
    final placeholder = Center(
      child: Text(
        caption,
        textDirection: TextDirection.ltr,
        style: context.texts.captionStrong.copyWith(color: reader.onVideo),
      ),
    );
    return ColoredBox(
      color: reader.videoBoard,
      child: url == null
          ? placeholder
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class _ModelButton extends StatelessWidget {
  const _ModelButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final info = context.colors.info;
    return Semantics(
      button: true,
      toggled: playing,
      label: 'shadow_listen_model'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: AppSizes.minTapTarget,
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.quick),
              height: _height,
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.md + AppSpacing.xxs,
                end: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: playing ? info.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(_height / 2),
                border: Border.all(color: info.fill, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: AppSizes.iconSm + AppSpacing.xxs,
                    color: info.text,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'shadow_listen_model'.tr(),
                    style: context.texts.captionStrong.copyWith(
                      color: info.text,
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

/// 0.75× or 1×, left to right in any language.
class _SpeedSwitch extends StatelessWidget {
  const _SpeedSwitch({required this.speed, required this.onPick});

  final double speed;
  final ValueChanged<double> onPick;

  static const _height = 32.0;
  static const _option = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Semantics(
      label: 'shadow_speed'.tr(),
      container: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          height: _height,
          padding: const EdgeInsetsDirectional.all(AppSpacing.xxs),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(_height / 2),
            border: Border.all(color: context.scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in const [ShadowingCubit.slow, 1.0])
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: value == speed,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPick(value),
                    child: AnimatedContainer(
                      duration: AppMotion.resolve(context, AppMotion.quick),
                      height: _option,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.sm + AppSpacing.xxs,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: value == speed
                            ? colors.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(_option / 2),
                        border: Border.all(
                          color: value == speed
                              ? colors.border
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        'lesson_gv_speed'.tr(
                          namedArgs: {'speed': value == 1 ? '1' : '$value'},
                        ),
                        style:
                            (value == speed
                                    ? texts.captionStrong
                                    : texts.caption)
                                .copyWith(color: colors.textPrimary),
                      ),
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

/// How many words were heard, counted up once the words have lit; or the guide
/// glad that all were. «قارن» beside it, and the line for doing better.
class _Result extends StatelessWidget {
  const _Result({
    required this.state,
    required this.attempt,
    required this.sentence,
    required this.onCompare,
    super.key,
  });

  final ShadowingState state;
  final ShadowingTry attempt;
  final ReaderSentence sentence;
  final VoidCallback onCompare;

  static const _guide = 56.0;
  static const _countAfter = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final total = attempt.heard.length;
    final all = attempt.count == total;
    final better = state.improvement;
    final compare = state.compare;
    final words = AppMotion.reduceMotion(context)
        ? Duration.zero
        : AppMotion.stagger * 1.5 * total + _countAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: all
              ? 'shadow_all_heard'.tr()
              : 'lesson_heard_count'.plural(
                  total,
                  namedArgs: {'heard': '${attempt.count}'},
                ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                if (all) ...[
                  const Mascot(
                    expression: MascotExpression.happy,
                    size: _guide,
                    animate: false,
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      'shadow_all_heard'.tr(),
                      style: texts.bodyStrong.copyWith(
                        color: colors.success.text,
                      ),
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.hearing_rounded,
                    size: AppSizes.iconMd,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  Expanded(
                    child: CountUp(
                      value: attempt.count,
                      delay: words,
                      builder: (context, shown) => Text(
                        'lesson_heard_count'.plural(
                          total,
                          namedArgs: {'heard': '$shown'},
                        ),
                        style: texts.bodyStrong.copyWith(
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
                _CompareButton(on: compare != null, onTap: onCompare),
              ],
            ),
          ),
        ),
        if (better case (final before, final now))
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
            child: Text(
              'shadow_better'.tr(
                namedArgs: {'before': '$before', 'now': '$now'},
              ),
              style: texts.caption.copyWith(color: colors.success.text),
            ),
          ),
        SmoothSize(
          child: compare == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: AppSpacing.sm + AppSpacing.xxs,
                  ),
                  child: _CompareCard(
                    compare: compare,
                    you: barsOf(attempt.levels),
                    model: modelBars(sentence),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CompareButton extends StatelessWidget {
  const _CompareButton({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  static const _height = 36.0;

  @override
  Widget build(BuildContext context) {
    final info = context.colors.info;
    return Semantics(
      button: true,
      toggled: on,
      label: 'shadow_compare'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: AppSizes.minTapTarget,
          child: Center(
            widthFactor: 1,
            child: Container(
              height: _height,
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.md,
                end: AppSpacing.md + AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_height / 2),
                border: Border.all(color: info.fill, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: AppSizes.iconSm + AppSpacing.xxs,
                    color: info.text,
                  ),
                  const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                  Text(
                    'shadow_compare'.tr(),
                    style: context.texts.captionStrong.copyWith(
                      color: info.text,
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

/// The learner's voice and the model's, one after the other, each with its line.
class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.compare,
    required this.you,
    required this.model,
  });

  final ShadowingCompare compare;
  final List<double> you;
  final List<double> model;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md + AppSpacing.xxs,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _WaveRow(
            label: 'shadow_you'.tr(),
            bars: you,
            color: colors.primary.fill,
            run: compare.part == ComparePart.you ? compare.run : null,
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          _WaveRow(
            label: 'shadow_model'.tr(),
            bars: model,
            color: colors.info.fill,
            run: compare.part == ComparePart.model ? compare.run : null,
          ),
        ],
      ),
    );
  }
}

class _WaveRow extends StatelessWidget {
  const _WaveRow({
    required this.label,
    required this.bars,
    required this.color,
    required this.run,
  });

  final String label;
  final List<double> bars;
  final Color color;
  final SoundRun? run;

  static const _label = 52.0;
  static const _height = 36.0;
  static const _waiting = .4;

  @override
  Widget build(BuildContext context) {
    final run = this.run;
    return Semantics(
      label: label,
      selected: run != null,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: AppMotion.resolve(context, AppMotion.closeUp),
        opacity: run == null ? _waiting : 1,
        child: Row(
          children: [
            SizedBox(
              width: _label,
              child: Text(
                label,
                style: context.texts.captionStrong.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            Expanded(
              child: SizedBox(
                height: _height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    WaveBars(bars: bars, color: color),
                    if (run != null) PlayLine(key: ValueKey(run.id), run: run),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadphonesNote extends StatelessWidget {
  const _HeadphonesNote({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md + AppSpacing.xxs,
          end: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              Icons.headphones_rounded,
              size: AppSizes.iconSm + AppSpacing.xs,
              color: colors.info.fill,
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            Expanded(
              child: Text(
                'shadow_headphones'.tr(),
                style: context.texts.caption.copyWith(color: colors.info.text),
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              child: Text('shadow_headphones_skip'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.seconds});

  final int seconds;

  static const _dot = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      label: 'lesson_mic_listening'.tr(),
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: colors.primaryStrong,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '0:${'$seconds'.padLeft(2, '0')}',
              style: context.texts.captionStrong.copyWith(
                color: colors.primary.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.label,
    required this.onRetry,
    required this.onNext,
  });

  final String label;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.scheme.outlineVariant)),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          AppButton(
            label: 'shadow_retry'.tr(),
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.large,
            expand: false,
            icon: Icons.replay_rounded,
            onPressed: onRetry,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppButton(
              label: label,
              size: AppButtonSize.large,
              onPressed: onNext,
            ),
          ),
        ],
      ),
    ),
  );
}
