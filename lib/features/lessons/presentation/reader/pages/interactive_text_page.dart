import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_text_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_card.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_controls.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_sentence.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_tip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// An interactive text (requirements v3.0 §8.2–§8.3, design "Interactive Text"):
/// the sentences in a list that follows the sound, keeping the current one a third
/// of the way down; the player at the foot; and a card for a word pressed. Scrolling
/// by hand stops the following until «الجملة الحالية».
class InteractiveTextPage extends StatefulWidget {
  const InteractiveTextPage({
    required this.onExit,
    required this.onContinue,
    required this.onShowWords,
    super.key,
  });

  final VoidCallback onExit;

  /// Whether the text has sentences to practise saying.
  final ValueChanged<bool> onContinue;
  final VoidCallback onShowWords;

  @override
  State<InteractiveTextPage> createState() => _InteractiveTextPageState();
}

class _InteractiveTextPageState extends State<InteractiveTextPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _barHeight = 56.0;
  static const _guide = 72.0;
  static const _third = 1 / 3;

  final _keys = ReaderKeys();
  final _area = GlobalKey();
  final _scroll = ScrollController();
  final _end = GlobalKey();
  late final Ticker _ticker;
  late final _cubit = context.read<InteractiveTextCubit>();
  var _lastFrame = Duration.zero;
  Rect? _anchor;
  Size? _areaSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onFrame);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _cubit.state.playing) {
      unawaited(_cubit.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    final delta = elapsed - _lastFrame;
    _lastFrame = elapsed;
    _cubit.tick(delta);
  }

  void _followPlaying(bool playing) {
    if (playing && !_ticker.isActive) {
      _lastFrame = Duration.zero;
      unawaited(_ticker.start());
    } else if (!playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _bringCurrentIntoView() {
    final target = _keys.sentence(_cubit.state.current).currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: _third,
        duration: AppMotion.resolve(context, AppMotion.medium),
        curve: AppMotion.inOut,
      ),
    );
  }

  void _bringEndIntoView() {
    final target = _end.currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: AppMotion.resolve(context, AppMotion.medium),
        curve: AppMotion.inOut,
      ),
    );
  }

  /// Where a card should point: over the whole span when it shares a line.
  void _placeCard(ReaderSelection selection) {
    final area = _area.currentContext?.findRenderObject();
    if (area is! RenderBox) return;
    final sentence = _cubit.state.content!.sentences[selection.sentence];
    final span = selection.span;
    Rect? rect;
    for (final (i, word) in sentence.words.indexed) {
      if (!(span?.wordIds.contains(word.id) ?? i == selection.word)) continue;
      final box = _keys
          .word(selection.sentence, i)
          .currentContext
          ?.findRenderObject();
      if (box is! RenderBox) continue;
      final here = box.localToGlobal(Offset.zero, ancestor: area) & box.size;
      rect = rect == null || (rect.top - here.top).abs() > 4
          ? rect ?? here
          : rect.expandToInclude(here);
    }
    setState(() {
      _anchor = rect;
      _areaSize = area.size;
    });
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<InteractiveTextCubit, InteractiveTextState>(
        listenWhen: (before, now) => before.playing != now.playing,
        listener: (_, state) => _followPlaying(state.playing),
      ),
      BlocListener<InteractiveTextCubit, InteractiveTextState>(
        listenWhen: (before, now) =>
            now.following &&
            now.playing &&
            (before.current != now.current ||
                before.following != now.following ||
                before.playing != now.playing),
        listener: (_, _) => _bringCurrentIntoView(),
      ),
      BlocListener<InteractiveTextCubit, InteractiveTextState>(
        listenWhen: (before, now) => !before.finished && now.finished,
        listener: (_, _) => _bringEndIntoView(),
      ),
      BlocListener<InteractiveTextCubit, InteractiveTextState>(
        listenWhen: (before, now) => before.selection != now.selection,
        listener: (_, state) {
          if (state.selection case final selection?) {
            _placeCard(selection);
          }
        },
      ),
    ],
    child: Scaffold(
      body: SafeArea(
        child: BlocBuilder<InteractiveTextCubit, InteractiveTextState>(
          buildWhen: (before, now) =>
              before.load != now.load || before.content != now.content,
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _barHeight,
                child: _TopBar(
                  title: state.title,
                  ready: state.load == LoadStatus.ready,
                  onExit: widget.onExit,
                ),
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
            ],
          ),
        ),
      ),
    ),
  );

  Widget _ready(InteractiveTextState loaded) {
    final content = loaded.content!;
    return Stack(
      key: _area,
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification &&
                      notification.dragDetails != null) {
                    _cubit.stopFollowing();
                  }
                  if (notification.metrics.extentAfter < AppSpacing.xxl &&
                      notification.metrics.maxScrollExtent > 0) {
                    _cubit.reachedEnd();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg + AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.lg + AppSpacing.xs,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, sentence)
                          in content.sentences.indexed) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.sm),
                        BlocSelector<
                          InteractiveTextCubit,
                          InteractiveTextState,
                          SentenceView
                        >(
                          selector: (state) {
                            final current = state.current == i;
                            final said = current && state.started
                                ? state.word
                                : null;
                            final selection = state.selection?.sentence == i
                                ? state.selection
                                : null;
                            return SentenceView(
                              current: current,
                              saidWord: selection == null ? said : null,
                              saidFor: said == null
                                  ? Duration.zero
                                  : (sentence.words[said].end -
                                            sentence.words[said].start) *
                                        (1 / state.speed),
                              open: state.open.contains(i),
                              revealed: state.revealed.contains(i),
                              selection: selection,
                              mode: state.prefs.mode,
                              size: state.prefs.size,
                            );
                          },
                          builder: (context, view) => ReaderSentenceBlock(
                            index: i,
                            sentence: sentence,
                            content: content,
                            view: view,
                            keys: _keys,
                            onTapSentence: () => _cubit.goTo(i),
                            onTapWord: (word) {
                              if (!_cubit.selectWord(i, word)) _cubit.goTo(i);
                              return true;
                            },
                            onListen: () => _cubit.listenTo(i),
                            onToggleTranslation: () =>
                                _cubit.toggleTranslation(i),
                            onReveal: () => _cubit.reveal(i),
                          ),
                        ),
                      ],
                      BlocSelector<
                        InteractiveTextCubit,
                        InteractiveTextState,
                        int
                      >(
                        selector: (state) => state.saved.length,
                        builder: (context, saved) => ReaderEnd(
                          key: _end,
                          sentences: content.sentences.length,
                          savedCount: saved,
                          markedCount: content.spans.length,
                          hasShadowing: content.hasShadowing,
                          guide: const Mascot(
                            expression: MascotExpression.happy,
                            size: _guide,
                            animate: false,
                          ),
                          onContinue: () =>
                              widget.onContinue(content.hasShadowing),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            BlocBuilder<InteractiveTextCubit, InteractiveTextState>(
              buildWhen: (before, now) =>
                  before.position.inSeconds != now.position.inSeconds ||
                  before.playing != now.playing ||
                  before.current != now.current ||
                  before.audioFailed != now.audioFailed ||
                  before.speed != now.speed,
              builder: (context, state) => DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(color: context.scheme.outline),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.audioFailed)
                      ReaderAudioFailed(onRetry: _cubit.retryAudio),
                    ReaderPlayerBar(state: state),
                  ],
                ),
              ),
            ),
          ],
        ),
        BlocBuilder<InteractiveTextCubit, InteractiveTextState>(
          buildWhen: (before, now) =>
              before.following != now.following ||
              before.playing != now.playing ||
              before.savedNotice != now.savedNotice ||
              before.audioFailed != now.audioFailed,
          builder: (context, state) => PositionedDirectional(
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            bottom:
                ReaderPlayerBar.height +
                AppSpacing.sm +
                (state.audioFailed ? AppSizes.minTapTarget + AppSpacing.sm : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.playing && !state.following)
                  ReaderBackToCurrent(
                    upward: _isCurrentAbove(),
                    onTap: _cubit.followAgain,
                  ),
                if (state.savedNotice) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ReaderSavedNotice(onShow: widget.onShowWords),
                ],
              ],
            ),
          ),
        ),
        BlocSelector<InteractiveTextCubit, InteractiveTextState, bool>(
          selector: (state) => state.showTip,
          builder: (context, showTip) => showTip
              ? ReaderTip(
                  keys: _keys,
                  areaKey: _area,
                  content: content,
                  onClose: _cubit.closeTip,
                )
              : const SizedBox.shrink(),
        ),
        BlocBuilder<InteractiveTextCubit, InteractiveTextState>(
          buildWhen: (before, now) =>
              before.selection != now.selection || before.saved != now.saved,
          builder: (context, state) {
            final selection = state.selection;
            final anchor = _anchor;
            final size = _areaSize;
            if (selection == null || anchor == null || size == null) {
              return const SizedBox.shrink();
            }
            final word =
                content.sentences[selection.sentence].words[selection.word];
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _cubit.closeCard,
                ),
                ReaderCard(
                  span: selection.span,
                  word: word.text,
                  gloss: word.gloss,
                  anchor: anchor,
                  area: size,
                  saved: state.saved.contains(selection.span?.id),
                  onSay: _cubit.sayCard,
                  onSave: _cubit.toggleSaved,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  bool _isCurrentAbove() {
    final target = _keys
        .sentence(_cubit.state.current)
        .currentContext
        ?.findRenderObject();
    final area = _area.currentContext?.findRenderObject();
    if (target is! RenderBox || area is! RenderBox) return false;
    return target.localToGlobal(Offset.zero, ancestor: area).dy < 0;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.ready,
    required this.onExit,
  });

  final String? title;
  final bool ready;
  final VoidCallback onExit;

  static const _side = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final title = this.title;
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
                Text(
                  'lesson_kind_interactive_text'.tr(),
                  style: texts.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if (ready)
          PositionedDirectional(
            end: AppSpacing.md,
            top: AppSpacing.xs,
            child: Semantics(
              button: true,
              label: 'reader_settings'.tr(),
              excludeSemantics: true,
              child: TextButton(
                onPressed: () => showReaderSettings(context),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  minimumSize: const Size.square(AppSizes.minTapTarget),
                  padding: EdgeInsetsDirectional.zero,
                  shape: const CircleBorder(),
                ),
                child: Text(
                  'reader_size_sample'.tr(),
                  textDirection: TextDirection.ltr,
                  style: texts.bodyStrong,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
