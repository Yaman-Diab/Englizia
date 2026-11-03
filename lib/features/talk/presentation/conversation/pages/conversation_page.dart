import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/listening_motion.dart';
import 'package:englizia/core/design_system/motion/rolling_number.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/ai_spark.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/design_system/widgets/mic_permission_sheet.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';
import 'package:englizia/features/talk/presentation/conversation/cubit/conversation_cubit.dart';
import 'package:englizia/features/talk/presentation/conversation/widgets/chat_parts.dart';
import 'package:englizia/features/talk/presentation/conversation/widgets/summary_view.dart';
import 'package:englizia/features/talk/presentation/widgets/talk_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A scenario's intro, the conversation, then its summary (requirements v3.0
/// §8.6, designs "Talk" and "Talk Summary"). [onClose] leaves, from the intro
/// or with «انتهيت».
class ConversationPage extends StatelessWidget {
  const ConversationPage({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ConversationCubit, ConversationState>(
        listenWhen: (previous, current) =>
            current.startFailure != null &&
            previous.startFailure != current.startFailure,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(state.startFailure!.localizedMessage)),
          ),
        buildWhen: (previous, current) => previous.stage != current.stage,
        builder: (context, state) => switch (state.stage) {
          TalkStage.loading => const Scaffold(body: AppStateView.loading()),
          TalkStage.failed => Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: onClose,
                tooltip: 'common_close'.tr(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            body: AppStateView.error(
              message: state.failure!.localizedMessage,
              onRetry: context.read<ConversationCubit>().start,
            ),
          ),
          TalkStage.intro => _Intro(onClose: onClose),
          TalkStage.chat => const _Chat(),
          TalkStage.summary => SummaryView(onDone: onClose),
        },
      );
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onClose});

  final VoidCallback onClose;

  static const _bar = 56.0;
  static const _halo = 136.0;
  static const _haloInset = 8.0;
  static const _speaker = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<ConversationCubit>();
    final scenario = cubit.state.scenario!;
    final character = scenario.character;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: _bar,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'common_close'.tr(),
                      color: colors.textSecondary,
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Spacer(),
                    TalkKindBadge(kind: scenario.kind, large: true),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl,
                  AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: _halo,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Breathing(
                            active: true,
                            duration: AppMotion.characterBreath * 2,
                            child: Opacity(
                              opacity: .5,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scenario.kind == TalkKind.ai
                                        ? colors.ai.text
                                        : colors.primary.text,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          CharacterAvatar(
                            character: character,
                            size: _halo - 2 * _haloInset,
                            kind: scenario.kind,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      header: true,
                      child: Text(
                        character.name,
                        style: texts.title.copyWith(color: colors.textPrimary),
                      ),
                    ),
                    if (character.description.isNotEmpty)
                      Text(
                        character.description,
                        textAlign: TextAlign.center,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                          fontSize: texts.body.fontSize! * .875,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              scenario.intro.english,
                              style: texts.reading.copyWith(
                                color: colors.textPrimary,
                                height: 34 / 20,
                              ),
                            ),
                          ),
                          if (scenario.intro.audioUrl != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              onPressed: cubit.playIntro,
                              tooltip: 'lesson_listen'.tr(),
                              style: IconButton.styleFrom(
                                fixedSize: const Size.square(_speaker),
                                backgroundColor: colors.info.fill,
                                foregroundColor: colors.surface,
                              ),
                              iconSize: AppSizes.iconSm + AppSpacing.xxs,
                              icon: const Icon(Icons.volume_up_rounded),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (scenario.intro.arabic.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          scenario.intro.arabic,
                          textDirection: TextDirection.rtl,
                          style: texts.body.copyWith(
                            color: colors.textSecondary,
                            fontSize: texts.body.fontSize! * .94,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _Role(role: scenario.role),
                    const SizedBox(height: AppSpacing.lg),
                    _Tasks(tasks: scenario.tasks),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  BlocSelector<ConversationCubit, ConversationState, bool>(
                    selector: (state) => state.starting,
                    builder: (context, starting) => AppButton(
                      label: 'talk_start'.tr(),
                      onPressed: cubit.begin,
                      isLoading: starting,
                      size: AppButtonSize.large,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                  Text(
                    'talk_start_note'.tr(),
                    textAlign: TextAlign.center,
                    style: texts.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: texts.caption.fontSize! * .92,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «دورك»: who the learner is in the scenario.
class _Role extends StatelessWidget {
  const _Role({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md + AppSpacing.xxs,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.primary.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxs),
            child: Icon(
              Icons.person_outline_rounded,
              size: AppSizes.iconMd - AppSpacing.xs,
              color: colors.primary.text,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'talk_your_role'.tr(),
                  style: texts.captionStrong.copyWith(
                    color: colors.primary.text,
                  ),
                ),
                Text(
                  role,
                  style: texts.body.copyWith(
                    color: colors.textPrimary,
                    fontSize: texts.body.fontSize! * .94,
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

/// «مهامك», numbered.
class _Tasks extends StatelessWidget {
  const _Tasks({required this.tasks});

  final List<TalkTask> tasks;

  static const _number = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final line = texts.body.copyWith(
      color: colors.textPrimary,
      fontSize: texts.body.fontSize! * .94,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'talk_your_tasks'.tr(),
            style: texts.bodyStrong.copyWith(
              color: colors.textPrimary,
              fontSize: texts.body.fontSize! * .94,
            ),
          ),
        ),
        for (final (index, task) in tasks.indexed) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: _number,
                  height: _number,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border, width: 1.5),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: texts.captionStrong.copyWith(
                      color: colors.textSecondary,
                      fontSize: texts.caption.fontSize! * .85,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Expanded(child: Text(task.text, style: line)),
            ],
          ),
        ],
      ],
    );
  }
}

class _Chat extends StatefulWidget {
  const _Chat();

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  static const _bar = 56.0;
  static const _bubbleShare = .84;

  final _scroll = ScrollController();
  final _typed = TextEditingController();
  final _typeFocus = FocusNode();
  late final _cubit = context.read<ConversationCubit>();
  late final _mic = context.read<MicCubit>();

  var _typing = false;
  var _panelOpen = false;

  /// The tasks done by the last reply, which pop in the panel.
  var _justDone = <String>{};

  /// The count the tasks' capsule rolls from.
  var _rolledFrom = 0;
  var _seenDone = <String>{};
  Timer? _panelTimer;

  /// Where the reply just chosen flies from.
  Rect? _flyFrom;

  @override
  void dispose() {
    _panelTimer?.cancel();
    _scroll.dispose();
    _typed.dispose();
    _typeFocus.dispose();
    super.dispose();
  }

  void _scrollToEnd() =>
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!_scroll.hasClients) return;
        await _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.out,
        );
      });

  /// A task done opens the panel by itself, and it folds back once read.
  void _onTasks(Set<String> done) {
    _panelTimer?.cancel();
    setState(() {
      _rolledFrom = _seenDone.length;
      _justDone = done.difference(_seenDone);
      _seenDone = done;
      _panelOpen = true;
    });
    _panelTimer = Timer(AppMotion.taskPanelHold, () {
      if (mounted) setState(() => _panelOpen = false);
    });
  }

  Future<void> _tapMic() async {
    if (_mic.state.phase == MicPhase.listening) return _mic.stop();
    if (_mic.state.phase == MicPhase.thinking ||
        _cubit.state.phase != TalkPhase.turn) {
      return;
    }
    switch (await _mic.access()) {
      case MicAccess.granted:
        unawaited(HapticFeedback.selectionClick());
        await _mic.listen();
      case MicAccess.denied:
        _mic.showDenied();
      case MicAccess.notAsked:
        if (!mounted) return;
        if (await showMicPermissionSheet(context)) await _mic.ask();
    }
  }

  void _onMic(BuildContext context, MicState state) {
    final messenger = ScaffoldMessenger.of(context);
    switch (state.phase) {
      case MicPhase.heard:
        _cubit.heard(state.transcript);
        _mic.reset();
      case MicPhase.notHeard:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('lesson_mic_not_heard'.tr())));
        _mic.reset();
      case MicPhase.denied:
        setState(() => _typing = true);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('lesson_mic_denied'.tr()),
              action: SnackBarAction(
                label: 'lesson_mic_open_settings'.tr(),
                onPressed: _mic.openSettings,
              ),
            ),
          );
        _mic.reset();
      case MicPhase.idle || MicPhase.listening || MicPhase.thinking:
        break;
    }
  }

  void _sendTyped() {
    if (_cubit.sendTyped(_typed.text)) _typed.clear();
  }

  void _useMic() {
    _typeFocus.unfocus();
    setState(() => _typing = false);
  }

  void _useKeyboard() {
    _mic.reset();
    setState(() => _typing = true);
    _typeFocus.requestFocus();
  }

  Future<void> _askToEnd() async {
    final choice = await showActionSheet(
      context,
      title: 'talk_end_title'.tr(),
      body: 'talk_end_body'.tr(),
      primaryLabel: 'talk_keep_on'.tr(),
      secondaryLabel: 'talk_end_now'.tr(),
      outlinedSecondary: true,
    );
    if (choice == SheetAction.secondary) _finish();
  }

  void _finish() {
    _mic.reset();
    _cubit.finish();
  }

  void _choose(int index, Rect from) {
    if (_cubit.state.phase != TalkPhase.turn) return;
    setState(() => _flyFrom = from);
    _cubit.choose(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MultiBlocListener(
      listeners: [
        BlocListener<ConversationCubit, ConversationState>(
          listenWhen: (previous, current) =>
              previous.messages.length != current.messages.length ||
              previous.phase != current.phase,
          listener: (_, _) => _scrollToEnd(),
        ),
        BlocListener<ConversationCubit, ConversationState>(
          listenWhen: (previous, current) =>
              current.tasksDone.length > previous.tasksDone.length,
          listener: (_, state) => _onTasks(state.tasksDone),
        ),
        BlocListener<MicCubit, MicState>(listener: _onMic),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_cubit.state.phase == TalkPhase.ended) {
            _finish();
          } else {
            unawaited(_askToEnd());
          }
        },
        child: Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: BlocBuilder<ConversationCubit, ConversationState>(
              builder: (context, state) => Stack(
                children: [
                  Column(
                    children: [
                      _header(context, state),
                      Expanded(child: _messages(context, state)),
                      _bottom(context, state),
                    ],
                  ),
                  if (_panelOpen)
                    PositionedDirectional(
                      top: _bar,
                      start: 0,
                      end: 0,
                      child: Entrance(
                        motion: EntranceMotion.down,
                        delay: Duration.zero,
                        duration: AppMotion.fast,
                        distance: AppMotion.distanceBase,
                        child: TaskPanel(
                          tasks: state.scenario!.tasks,
                          done: state.tasksDone,
                          justDone: _justDone,
                          turnsLeft: state.turnsLeft,
                        ),
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

  Widget _header(BuildContext context, ConversationState state) {
    final colors = context.colors;
    final texts = context.texts;
    final scenario = state.scenario!;
    final done = state.tasksDone.length;
    final total = scenario.tasks.length;
    return Container(
      height: _bar,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xs,
        0,
        AppSpacing.lg,
        0,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: context.scheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: state.phase == TalkPhase.ended ? _finish : _askToEnd,
            tooltip: 'talk_end_label'.tr(),
            color: colors.textSecondary,
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (state.written)
            CharacterAvatar(
              character: scenario.character,
              size: _SpeakingAvatar.size,
              kind: TalkKind.written,
            )
          else
            _SpeakingAvatar(
              character: scenario.character,
              speaking: state.speaking,
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenario.character.name,
                  style: texts.bodyStrong.copyWith(
                    color: colors.textPrimary,
                    fontSize: texts.body.fontSize! * .94,
                    height: 20 / 15,
                  ),
                ),
                Row(
                  children: [
                    if (state.written)
                      AppIconView(
                        AppIcon.scriptPage,
                        size: AppSizes.iconSm * .75,
                        color: colors.textSecondary,
                      )
                    else
                      const AiSpark(size: 12),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        state.written
                            ? 'talk_kind_written'.tr()
                            : 'talk_kind_ai'.tr(),
                        style: texts.caption.copyWith(
                          color: state.written
                              ? colors.textSecondary
                              : colors.ai.text,
                          fontSize: texts.caption.fontSize! * .85,
                          height: 16 / 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            expanded: _panelOpen,
            label: 'talk_tasks_button'.tr(),
            value: 'talk_done_of'.tr(
              namedArgs: {'done': '$done', 'total': '$total'},
            ),
            excludeSemantics: true,
            child: OutlinedButton.icon(
              onPressed: () {
                _panelTimer?.cancel();
                setState(() {
                  _panelOpen = !_panelOpen;
                  _justDone = {};
                });
              },
              style: OutlinedButton.styleFrom(
                fixedSize: const Size.fromHeight(36),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.sm + AppSpacing.xxs,
                  0,
                  AppSpacing.md,
                  0,
                ),
                backgroundColor: colors.surface,
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.border),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(
                Icons.format_list_bulleted_rounded,
                size: AppSizes.iconSm,
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RollingNumber(
                    key: ValueKey(done),
                    from: _rolledFrom,
                    to: done,
                    delay: AppMotion.taskCountDelay,
                    style: texts.captionStrong.copyWith(
                      color: colors.textPrimary,
                      height: 18 / 13,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'talk_tasks_of'.tr(namedArgs: {'total': '$total'}),
                    style: texts.captionStrong.copyWith(
                      color: colors.textPrimary,
                      height: 18 / 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messages(BuildContext context, ConversationState state) {
    final scenario = state.scenario!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 2 * AppSpacing.lg) * _bubbleShare;
        return SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, message) in state.messages.indexed) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  KeyedSubtree(
                    key: ValueKey(index),
                    child: _arrival(
                      index == state.messages.length - 1 &&
                          message.via == SaidVia.choice,
                      message.mine
                          ? MineBubble(
                              text: message.line.english,
                              via: message.via!,
                              maxWidth: width,
                            )
                          : CharacterBubble(
                              line: message.line,
                              character: scenario.character,
                              kind: scenario.kind,
                              showAvatar:
                                  index == 0 || state.messages[index - 1].mine,
                              translated: state.translated.contains(index),
                              maxWidth: width,
                              onReplay: () => _cubit.replay(index),
                              onTranslate: () =>
                                  _cubit.toggleTranslation(index),
                            ),
                    ),
                  ),
                ],
                if (state.phase == TalkPhase.thinking) ...[
                  const SizedBox(height: AppSpacing.md),
                  ThinkingBubble(character: scenario.character),
                ],
                if (state.phase == TalkPhase.failed) ...[
                  const SizedBox(height: AppSpacing.md),
                  ReplyFailed(onRetry: _cubit.retry),
                ],
                if (state.phase == TalkPhase.draft) ...[
                  const SizedBox(height: AppSpacing.md),
                  DraftBubble(
                    text: state.draft,
                    maxWidth: width,
                    onRedo: _cubit.redo,
                    onSend: _cubit.sendDraft,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// A bubble grows in; a reply chosen from its card flies in from it.
  Widget _arrival(bool chosen, Widget bubble) {
    final from = _flyFrom;
    if (chosen && from != null) return FlyIn(from: from, child: bubble);
    return bubbleEntrance(bubble);
  }

  Widget _bottom(BuildContext context, ConversationState state) {
    final colors = context.colors;
    final scenario = state.scenario!;
    final ended = state.phase == TalkPhase.ended;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: context.scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        child: BlocBuilder<MicCubit, MicState>(
          builder: (context, mic) {
            final recording = mic.phase == MicPhase.listening;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.phase == TalkPhase.turn &&
                    !recording &&
                    state.suggestions.isNotEmpty)
                  Entrance(
                    key: ValueKey(state.messages.length),
                    motion: EntranceMotion.up,
                    delay: Duration.zero,
                    duration: AppMotion.fast,
                    distance: AppSpacing.lg,
                    child: Suggestions(
                      lines: state.suggestions,
                      onPlay: _cubit.playLine,
                    ),
                  ),
                if (ended)
                  ChatEnded(
                    taskCount: scenario.tasks.length,
                    done: state.tasksDone.length,
                    onSummary: _finish,
                  )
                else if (state.written)
                  _scripted(state, recording)
                else if (_typing)
                  TypeBar(
                    controller: _typed,
                    focusNode: _typeFocus,
                    onMic: _useMic,
                    onSend: _sendTyped,
                  )
                else
                  MicBar(
                    recording: recording,
                    onMic: _tapMic,
                    onKeyboard: _useKeyboard,
                    label: 'talk_speak'.tr(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A written conversation's turn: dimmed while the character speaks or
  /// answers, and out of sight while a chosen reply flies from it.
  Widget _scripted(ConversationState state, bool recording) {
    final flying = state.phase == TalkPhase.sent && _flyFrom != null;
    final dimmed =
        state.phase == TalkPhase.speaking || state.phase == TalkPhase.sent;
    return IgnorePointer(
      ignoring: state.phase != TalkPhase.turn,
      child: AnimatedOpacity(
        opacity: flying
            ? 0
            : dimmed
            ? .45
            : 1,
        duration: AppMotion.resolve(context, AppMotion.closeUp),
        child: switch (state.scriptTurn) {
          RepeatTurn(:final sentence) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepeatCard(
                sentence: sentence,
                heard: state.heard,
                listening: recording,
                onListen: () => _cubit.playLine(sentence),
              ),
              MicBar(
                recording: recording,
                onMic: _tapMic,
                label: 'talk_say_sentence'.tr(),
              ),
            ],
          ),
          ChooseTurn(:final options) => ChooseCards(
            options: options,
            onChoose: _choose,
            onListen: _cubit.playLine,
          ),
          null => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// The character in the bar: its ring pulses while its voice plays.
class _SpeakingAvatar extends StatelessWidget {
  const _SpeakingAvatar({required this.character, required this.speaking});

  final TalkCharacter character;
  final bool speaking;

  static const size = 36.0;
  static const _ringGap = 3.0;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: -_ringGap,
          top: -_ringGap,
          right: -_ringGap,
          bottom: -_ringGap,
          child: Opacity(
            opacity: speaking ? .9 : .35,
            child: Breathing(
              active: speaking,
              duration: AppMotion.voiceRing * 2,
              growth: .18,
              fade: .39,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.ai.text, width: 2),
                ),
              ),
            ),
          ),
        ),
        CharacterAvatar(character: character, size: size, kind: TalkKind.ai),
      ],
    ),
  );
}
