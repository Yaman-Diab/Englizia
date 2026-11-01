import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/grammar/widgets/option_sheet.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_video_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/reader_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_controls.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_parts.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_sentence.dart';
import 'package:englizia/features/lessons/presentation/video/lesson_player.dart';
import 'package:englizia/features/lessons/presentation/video/video_fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// An interactive video (requirements v3.0 §8.4, design "Interactive Video"): the
/// player, with no text over its picture, and the reader under it as its caption,
/// the current sentence kept at the top. Sideways, the video shares the screen with
/// a panel of the current and next sentences, which hides by its tab.
class InteractiveVideoPage extends StatefulWidget {
  const InteractiveVideoPage({
    required this.onExit,
    required this.onContinue,
    required this.onShowWords,
    super.key,
  });

  final VoidCallback onExit;

  /// Whether the video has sentences to practise saying.
  final ValueChanged<bool> onContinue;
  final VoidCallback onShowWords;

  @override
  State<InteractiveVideoPage> createState() => _InteractiveVideoPageState();
}

class _InteractiveVideoPageState extends State<InteractiveVideoPage> {
  static const _guide = 72.0;
  static const _topGap = AppSpacing.sm;

  /// Room under the list's end for what floats over it.
  static const _endRoom = 120.0;

  final _keys = ReaderKeys();
  final _area = GlobalKey();
  final _scroll = ScrollController();
  final _end = GlobalKey();
  late final _cubit = context.read<InteractiveVideoCubit>();
  bool _fullscreen = false;

  /// The list comes back from its top after the phone turns upright.
  bool _returnToCurrent = false;

  @override
  void dispose() {
    _scroll.dispose();
    if (_fullscreen) unawaited(setVideoFullscreen(fullscreen: false));
    super.dispose();
  }

  void _toggleFullscreen() {
    final to = !_fullscreen;
    if (to && _cubit.state.selection != null) unawaited(_cubit.closeCard());
    setState(() => _fullscreen = to);
    _returnToCurrent = !to;
    unawaited(setVideoFullscreen(fullscreen: to));
  }

  /// The current sentence at the top of the reader, right under the picture.
  void _bringCurrentToTop() {
    final box = _keys
        .sentence(_cubit.state.current)
        .currentContext
        ?.findRenderObject();
    if (box is! RenderBox || !_scroll.hasClients) return;
    final position = _scroll.position;
    final offset =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset -
        _topGap;
    unawaited(
      position.animateTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
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

  Future<void> _pickMode() async {
    final mode = await showOptionSheet<ReaderMode>(
      context,
      title: 'reader_mode_title'.tr(),
      selected: _cubit.state.prefs.videoMode,
      options: [
        for (final mode in ReaderMode.forVideo)
          SheetOption(
            value: mode,
            label: readerModeNames(mode).$1,
            detail: mode == ReaderMode.listening
                ? 'reader_mode_bars_detail'.tr()
                : readerModeNames(mode).$2,
          ),
      ],
    );
    if (mode != null) await _cubit.setMode(mode);
  }

  Widget _player({
    required bool fullscreen,
  }) => BlocBuilder<InteractiveVideoCubit, ReaderState>(
    // The bar's time needs no more than this, and the frames are the words'.
    buildWhen: (before, now) =>
        before.stage != now.stage ||
        before.playing != now.playing ||
        before.buffering != now.buffering ||
        before.slowConnection != now.slowConnection ||
        before.speed != now.speed ||
        before.quality != now.quality ||
        before.resumeFrom != now.resumeFrom ||
        before.bufferedTo != now.bufferedTo ||
        (before.selection == null) != (now.selection == null) ||
        before.position.inMilliseconds ~/ 250 !=
            now.position.inMilliseconds ~/ 250,
    builder: (context, state) => LessonPlayer(
      state: state,
      actions: _cubit,
      fullscreen: fullscreen,
      onToggleFullscreen: _toggleFullscreen,
      titleInFullscreen: false,
      onSettings: fullscreen ? _pickMode : null,
      held: state.selection != null,
    ),
  );

  @override
  Widget build(BuildContext context) => ReaderClock(
    cubit: _cubit,
    child: MultiBlocListener(
      listeners: [
        BlocListener<InteractiveVideoCubit, ReaderState>(
          listenWhen: (before, now) =>
              now.following &&
              now.playing &&
              (before.current != now.current ||
                  before.following != now.following ||
                  before.playing != now.playing),
          listener: (_, _) => _bringCurrentToTop(),
        ),
        BlocListener<InteractiveVideoCubit, ReaderState>(
          listenWhen: (before, now) => !before.finished && now.finished,
          listener: (_, _) => _bringEndIntoView(),
        ),
      ],
      child: PopScope(
        canPop: !_fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _fullscreen) _toggleFullscreen();
        },
        child: Scaffold(
          backgroundColor: _fullscreen
              ? context.colors.reader.videoBackground
              : null,
          body: _body(context),
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    final sideways = MediaQuery.orientationOf(context) == Orientation.landscape;
    // While the phone turns, the screen's shape isn't yet the layout's.
    if (_fullscreen != sideways) return _player(fullscreen: _fullscreen);
    if (!sideways) {
      if (_returnToCurrent) {
        _returnToCurrent = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _bringCurrentToTop();
        });
      }
      return SafeArea(child: _portrait());
    }
    return _Sideways(
      cubit: _cubit,
      content: _cubit.state.content!,
      player: _player(fullscreen: true),
    );
  }

  Widget _portrait() => BlocBuilder<InteractiveVideoCubit, ReaderState>(
    buildWhen: (before, now) =>
        before.load != now.load || before.content != now.content,
    builder: (context, state) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReaderTopBar(
          title: state.title,
          kind: 'lesson_kind_interactive_video'.tr(),
          onExit: widget.onExit,
          settingsLabel: 'reader_mode_title'.tr(),
          onSettings: state.load == LoadStatus.ready ? _pickMode : null,
        ),
        Expanded(
          child: switch (state.load) {
            LoadStatus.loading => const AppStateView.loading(),
            LoadStatus.failure => AppStateView.error(
              message: state.failure!.localizedMessage,
              onRetry: _cubit.start,
            ),
            LoadStatus.ready => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _player(fullscreen: false),
                ),
                Expanded(child: _reader(state.content!)),
              ],
            ),
          },
        ),
      ],
    ),
  );

  Widget _reader(ReaderContent content) => Stack(
    key: _area,
    fit: StackFit.expand,
    children: [
      NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (notification.dragDetails != null) _cubit.stopFollowing();
          return false;
        },
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg + AppSpacing.xs,
            _topGap,
            AppSpacing.lg + AppSpacing.xs,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReaderSentences(
                cubit: _cubit,
                content: content,
                keys: _keys,
                gap: AppSpacing.xs,
                video: true,
                onListen: _cubit.goTo,
              ),
              BlocSelector<InteractiveVideoCubit, ReaderState, int>(
                selector: (state) => state.saved.length,
                builder: (context, saved) => ReaderEnd(
                  key: _end,
                  title: 'reader_end_clip'.tr(),
                  sentences: content.sentences.length,
                  savedCount: saved,
                  markedCount: content.spans.length,
                  hasShadowing: content.hasShadowing,
                  phrases: true,
                  guide: const Mascot(
                    expression: MascotExpression.happy,
                    size: _guide,
                    animate: false,
                  ),
                  onContinue: () => widget.onContinue(content.hasShadowing),
                ),
              ),
              const SizedBox(height: _endRoom),
            ],
          ),
        ),
      ),
      BlocBuilder<InteractiveVideoCubit, ReaderState>(
        buildWhen: (before, now) =>
            before.following != now.following ||
            before.playing != now.playing ||
            before.savedNotice != now.savedNotice,
        builder: (context, state) => PositionedDirectional(
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          bottom: AppSpacing.md,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.playing && !state.following)
                ReaderBackToCurrent(
                  label: 'reader_back_to_clip'.tr(),
                  upward: _isCurrentAbove(),
                  onTap: _cubit.followAgain,
                ),
              if (state.savedNotice) ...[
                const SizedBox(height: AppSpacing.sm),
                ReaderSavedNotice(
                  text: 'reader_saved_with_time'.tr(),
                  onShow: widget.onShowWords,
                ),
              ],
            ],
          ),
        ),
      ),
      ReaderCardLayer(cubit: _cubit, keys: _keys, areaKey: _area),
    ],
  );

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

/// The video and, on the screen's right in any app language, its panel: 62% and 38%,
/// or all the video once the panel is hidden by its tab.
class _Sideways extends StatefulWidget {
  const _Sideways({
    required this.cubit,
    required this.content,
    required this.player,
  });

  final InteractiveVideoCubit cubit;
  final ReaderContent content;
  final Widget player;

  @override
  State<_Sideways> createState() => _SidewaysState();
}

class _SidewaysState extends State<_Sideways> {
  static const _panelShare = .38;
  static const _tabWidth = 28.0;
  static const _tabHeight = 56.0;

  bool _panel = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final appDirection = Directionality.of(context);
    final time = AppMotion.resolve(context, AppMotion.fast);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth * _panelShare;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: time,
                curve: AppMotion.out,
                start: 0,
                top: 0,
                bottom: 0,
                end: _panel ? width : 0,
                child: widget.player,
              ),
              AnimatedPositionedDirectional(
                duration: time,
                curve: AppMotion.out,
                top: 0,
                bottom: 0,
                end: _panel ? 0 : -width,
                width: width,
                child: Directionality(
                  textDirection: appDirection,
                  child: ExcludeSemantics(
                    excluding: !_panel,
                    child: _Panel(cubit: widget.cubit, content: widget.content),
                  ),
                ),
              ),
              AnimatedPositionedDirectional(
                duration: time,
                curve: AppMotion.out,
                end: _panel ? width : 0,
                top: (box.maxHeight - _tabHeight) / 2,
                width: _tabWidth,
                height: _tabHeight,
                child: Semantics(
                  button: true,
                  label: _panel
                      ? 'reader_panel_hide'.tr()
                      : 'reader_panel_show'.tr(),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _panel = !_panel),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(color: context.scheme.outline),
                        borderRadius: const BorderRadiusDirectional.horizontal(
                          start: Radius.circular(AppRadius.md),
                        ),
                      ),
                      child: Icon(
                        _panel
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                        size: AppSizes.iconMd,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The current sentence, to read along with and not to press, and the next one.
class _Panel extends StatelessWidget {
  const _Panel({required this.cubit, required this.content});

  final InteractiveVideoCubit cubit;
  final ReaderContent content;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final media = MediaQuery.of(context);
    return MediaQuery(
      // The app's text grows with the screen's width, which is the long side here.
      data: media.copyWith(textScaler: TextScaler.linear(1 / 1.sp)),
      child: ColoredBox(
        color: colors.surface,
        child: SafeArea(
          left: false,
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Semantics(
              container: true,
              label: 'reader_panel'.tr(),
              child: BlocBuilder<InteractiveVideoCubit, ReaderState>(
                bloc: cubit,
                buildWhen: (before, now) =>
                    before.current != now.current ||
                    before.stage != now.stage ||
                    before.prefs != now.prefs,
                builder: (context, state) {
                  final mode = state.prefs.videoMode;
                  final at = state.current;
                  final next = at + 1 < content.sentences.length
                      ? content.sentences[at + 1]
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PanelSentence(
                        key: ValueKey(at),
                        cubit: cubit,
                        content: content,
                        index: at,
                      ),
                      if (next != null && mode != ReaderMode.listening) ...[
                        const SizedBox(height: AppSpacing.md),
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                ['reader_next'.tr(), ?next.speaker].join(' · '),
                                style: texts.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (mode == ReaderMode.arabicOnly)
                                Text(
                                  next.arabic,
                                  textDirection: TextDirection.rtl,
                                  style: texts.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                )
                              else
                                Text(
                                  next.english,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.start,
                                  locale: const Locale('en'),
                                  style: texts.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelSentence extends StatefulWidget {
  const _PanelSentence({
    required this.cubit,
    required this.content,
    required this.index,
    super.key,
  });

  final InteractiveVideoCubit cubit;
  final ReaderContent content;
  final int index;

  @override
  State<_PanelSentence> createState() => _PanelSentenceState();
}

class _PanelSentenceState extends State<_PanelSentence> {
  final _keys = ReaderKeys();

  @override
  Widget build(BuildContext context) =>
      BlocSelector<InteractiveVideoCubit, ReaderState, SentenceView>(
        bloc: widget.cubit,
        selector: (state) {
          final view = readerSentenceView(state, widget.index, video: true);
          return SentenceView(
            current: view.current,
            saidWord: view.saidWord,
            saidFor: view.saidFor,
            open: view.open,
            revealed: view.revealed,
            selection: null,
            mode: view.mode,
            size: ReaderTextSize.small,
          );
        },
        builder: (context, view) => ReaderSentenceBlock(
          index: widget.index,
          sentence: widget.content.sentences[widget.index],
          content: widget.content,
          view: view,
          keys: _keys,
          video: true,
          compact: true,
          onTapSentence: () {},
          onTapWord: (_) => true,
          onListen: () {},
          onToggleTranslation: () {},
          onReveal: () {},
        ),
      );
}
