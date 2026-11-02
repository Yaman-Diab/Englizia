import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/audio/mic_permission.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/mic_permission_sheet.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/services/exercise_evaluator.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/clip_button.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/mic_block.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/said_word.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Listen, then say it. There is no «تحقق»: the end of the recording is the
/// check. The words light up from the left, those heard with a check and those
/// missed in a neutral dotted line, and then the sheet comes. Never a red or a
/// cross: speech-to-text hears imperfectly, so it can't be called wrong (S §7.5).
class RepeatSentenceBody extends StatefulWidget {
  const RepeatSentenceBody({
    required this.exercise,
    required this.answer,
    required this.clip,
    required this.onSkipSpeech,
    super.key,
  });

  final RepeatSentenceExercise exercise;
  final BodyAnswer answer;
  final BodyClip clip;
  final VoidCallback onSkipSpeech;

  @override
  State<RepeatSentenceBody> createState() => _RepeatSentenceBodyState();
}

class _RepeatSentenceBodyState extends State<RepeatSentenceBody>
    with WidgetsBindingObserver {
  static const _clipBox = 56.0;
  static const _clipButton = 48.0;
  static const _clipIcon = 24.0;

  /// From the last word's turn to the sheet.
  static const _toSheet = Duration(milliseconds: 600);

  late final MicCubit _mic = context.read<MicCubit>();
  List<bool>? _heard;
  Timer? _toCheck;

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
  void didUpdateWidget(RepeatSentenceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another try: the sheet took the answer away.
    if (oldWidget.answer.draft != null && widget.answer.draft == null) {
      _toCheck?.cancel();
      setState(() => _heard = null);
      _mic.reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toCheck?.cancel();
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
    final words = widget.exercise.words;
    final heard = heardWords(words, transcript);
    setState(() => _heard = heard);
    widget.answer.onDraft(SpeechDraft(heard));
    final delay = AppMotion.reduceMotion(context)
        ? Duration.zero
        : AppMotion.stagger * 1.5 * words.length + _toSheet;
    _toCheck = Timer(delay, widget.answer.onSubmit);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final heard = _heard;
    final texts = context.texts;
    final colors = context.colors;
    final caught = heard?.where((word) => word).length ?? 0;
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
              children: [
                ClipButton(
                  clip: widget.clip,
                  box: _clipBox,
                  button: _clipButton,
                  icon: _clipIcon,
                ),
                const SizedBox(width: AppSpacing.sm),
                SlowButton(
                  on: widget.clip.playingSlow,
                  onTap: widget.clip.onSlow,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(
              spacing: AppSpacing.sm - 1,
              runSpacing: AppSpacing.lg,
              children: [
                for (final (i, word) in exercise.words.indexed)
                  SaidWord(word: word, index: i, heard: heard?[i]),
              ],
            ),
          ),
          if (heard != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                'lesson_heard_count'.plural(
                  exercise.words.length,
                  namedArgs: {'heard': '$caught'},
                ),
                style: texts.captionStrong.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
          MicBlock(
            state: state,
            levels: _mic.levels,
            locked: heard != null,
            onTap: _tapMic,
            onOpenSettings: _mic.openSettings,
            onSkip: widget.onSkipSpeech,
          ),
        ],
      ),
    );
  }
}
