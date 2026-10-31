import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/mic_cubit.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/session/mic_permission_sheet.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_text_field.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/clip_button.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/mic_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A question to answer in the learner's own words, spoken or typed. What was
/// said shows word by word, and then the server's AI judges it: the answer leaves
/// the phone only for that, and the app holds no AI key (S §16.3).
class SpeakAnswerBody extends StatefulWidget {
  const SpeakAnswerBody({
    required this.exercise,
    required this.answer,
    required this.clip,
    required this.onSkipSpeech,
    super.key,
  });

  final SpeakAnswerExercise exercise;
  final BodyAnswer answer;
  final BodyClip clip;
  final VoidCallback onSkipSpeech;

  @override
  State<SpeakAnswerBody> createState() => _SpeakAnswerBodyState();
}

class _SpeakAnswerBodyState extends State<SpeakAnswerBody>
    with WidgetsBindingObserver {
  static const _clipBox = 56.0;
  static const _clipButton = 48.0;
  static const _clipIcon = 24.0;

  late final MicCubit _mic = context.read<MicCubit>();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _said;
  bool _typing = false;
  Timer? _toCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mic.reset();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_mic.recheck());
  }

  @override
  void didUpdateWidget(SpeakAnswerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final evaluation = widget.answer.evaluation;
    if (evaluation != null && oldWidget.answer.evaluation == null) {
      _focus.unfocus();
      if (widget.answer.draft case SpokenDraft(:final text)) {
        setState(() => _said = text);
      }
    }
    // Another try: the sheet took the answer away.
    if (oldWidget.answer.draft != null && widget.answer.draft == null) {
      _toCheckTimer?.cancel();
      _controller.clear();
      setState(() {
        _said = null;
        _typing = false;
      });
      _mic.reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toCheckTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _tapMic() async {
    final mic = _mic;
    if (mic.state.phase == MicPhase.listening) return mic.stop();
    if (mic.state.phase == MicPhase.thinking) return;
    widget.clip.onStop();
    switch (await mic.access()) {
      case MicAccess.granted:
        unawaited(HapticFeedback.selectionClick());
        await mic.listen();
      case MicAccess.denied:
        mic.showDenied();
      case MicAccess.notAsked:
        if (!mounted) return;
        if (await showMicPermissionSheet(context)) await mic.ask();
    }
  }

  void _onHeard(String transcript) {
    setState(() => _said = transcript);
    widget.answer.onDraft(SpokenDraft(transcript));
    final delay = AppMotion.reduceMotion(context)
        ? Duration.zero
        : SpokenEntrance.settled(_SaidBubble.wordsOf(transcript).length);
    _toCheckTimer = Timer(delay, widget.answer.onSubmit);
  }

  void _toTyping() {
    widget.clip.onStop();
    _mic.reset();
    setState(() => _typing = true);
    widget.answer.onDraft(const SpokenDraft('', typed: true));
    _focus.requestFocus();
  }

  void _toMic() {
    _focus.unfocus();
    _controller.clear();
    setState(() => _typing = false);
    widget.answer.onDraft(const SpokenDraft(''));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final said = _said;
    final locked = said != null;
    return BlocConsumer<MicCubit, MicState>(
      listenWhen: (before, now) =>
          before.phase != now.phase && now.phase == MicPhase.heard,
      listener: (_, state) => _onHeard(state.transcript),
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipButton(
                  clip: widget.clip,
                  box: _clipBox,
                  button: _clipButton,
                  icon: _clipIcon,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppSpacing.md,
                    ),
                    child: Text(
                      widget.exercise.ask,
                      locale: const Locale('en'),
                      style: context.texts.reading.copyWith(
                        fontFamily: context.texts.bodyStrong.fontFamily,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (said != null) ...[
            const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
            _SaidBubble(text: said),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_typing && !locked) ...[
            AnswerTextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: (text) =>
                  widget.answer.onDraft(SpokenDraft(text, typed: true)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: _toMic,
                icon: const Icon(Icons.mic_rounded, size: AppSizes.iconSm),
                label: Text('lesson_speak_instead'.tr()),
              ),
            ),
          ] else if (!locked)
            MicBlock(
              state: state,
              levels: _mic.levels,
              onTap: _tapMic,
              onOpenSettings: _mic.openSettings,
              onSkip: widget.onSkipSpeech,
              onType: _toTyping,
            ),
        ],
      ),
    );
  }
}

/// «إجابتك», at the learner's side, the words arriving one by one.
class _SaidBubble extends StatelessWidget {
  const _SaidBubble({required this.text});

  final String text;

  static const _maxShare = .86;
  static const _bubbleRadius = AppRadius.lg;
  static const _tightCorner = AppSpacing.xs;

  static List<String> wordsOf(String text) => text.trim().split(RegExp(r'\s+'));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final words = wordsOf(text);
    return Semantics(
      liveRegion: true,
      label: 'lesson_speak_said'.tr(namedArgs: {'text': text}),
      child: ExcludeSemantics(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FractionallySizedBox(
            widthFactor: _maxShare,
            alignment: AlignmentDirectional.centerEnd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'lesson_speak_your_answer'.tr(),
                  style: context.texts.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.surface,
                    borderRadius: const BorderRadiusDirectional.only(
                      topStart: Radius.circular(_bubbleRadius),
                      topEnd: Radius.circular(_tightCorner),
                      bottomStart: Radius.circular(_bubbleRadius),
                      bottomEnd: Radius.circular(_bubbleRadius),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          for (final (i, word) in words.indexed)
                            Entrance(
                              motion: EntranceMotion.up,
                              delay: SpokenEntrance.word(i),
                              duration: AppMotion.quick,
                              distance: AppMotion.distanceMicro,
                              child: Text(
                                word,
                                locale: const Locale('en'),
                                style: context.texts.body.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
