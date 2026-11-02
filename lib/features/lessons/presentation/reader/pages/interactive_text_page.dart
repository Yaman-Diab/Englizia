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
import 'package:englizia/features/lessons/presentation/reader/cubit/reader_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_controls.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_parts.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_sentence.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_tip.dart';
import 'package:flutter/material.dart';
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

class _InteractiveTextPageState extends State<InteractiveTextPage> {
  static const _guide = 72.0;
  static const _third = 1 / 3;

  final _keys = ReaderKeys();
  final _area = GlobalKey();
  final _scroll = ScrollController();
  final _end = GlobalKey();
  late final _cubit = context.read<InteractiveTextCubit>();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) => ReaderClock(
    cubit: _cubit,
    child: MultiBlocListener(
      listeners: [
        BlocListener<InteractiveTextCubit, ReaderState>(
          listenWhen: (before, now) =>
              now.following &&
              now.playing &&
              (before.current != now.current ||
                  before.following != now.following ||
                  before.playing != now.playing),
          listener: (_, _) => _bringCurrentIntoView(),
        ),
        BlocListener<InteractiveTextCubit, ReaderState>(
          listenWhen: (before, now) => !before.finished && now.finished,
          listener: (_, _) => _bringEndIntoView(),
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<InteractiveTextCubit, ReaderState>(
            buildWhen: (before, now) =>
                before.load != now.load || before.content != now.content,
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReaderTopBar(
                  title: state.title,
                  kind: 'lesson_kind_interactive_text'.tr(),
                  onExit: widget.onExit,
                  settingsLabel: 'reader_settings'.tr(),
                  onSettings: state.load == LoadStatus.ready
                      ? () => showReaderSettings(context)
                      : null,
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
    ),
  );

  Widget _ready(ReaderState loaded) {
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
                      ReaderSentences(
                        cubit: _cubit,
                        content: content,
                        keys: _keys,
                        gap: AppSpacing.sm,
                        onListen: _cubit.listenTo,
                      ),
                      BlocSelector<InteractiveTextCubit, ReaderState, int>(
                        selector: (state) => state.saved.length,
                        builder: (context, saved) => ReaderEnd(
                          key: _end,
                          title: 'reader_end_title'.tr(),
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
            BlocBuilder<InteractiveTextCubit, ReaderState>(
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
        BlocBuilder<InteractiveTextCubit, ReaderState>(
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
                    label: 'reader_back_to_current'.tr(),
                    upward: _isCurrentAbove(),
                    onTap: _cubit.followAgain,
                  ),
                if (state.savedNotice) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ReaderSavedNotice(
                    text: 'reader_saved_notice'.tr(),
                    onShow: widget.onShowWords,
                  ),
                ],
              ],
            ),
          ),
        ),
        BlocSelector<InteractiveTextCubit, ReaderState, bool>(
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
        ReaderCardLayer(cubit: _cubit, keys: _keys, areaKey: _area),
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
