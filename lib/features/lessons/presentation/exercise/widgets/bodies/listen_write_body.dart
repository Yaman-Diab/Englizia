import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/widgets/clip_failed_view.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_text_field.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/clip_button.dart';
import 'package:flutter/material.dart';

/// A clip, and a field to write what it says.
class ListenWriteBody extends StatefulWidget {
  const ListenWriteBody({
    required this.exercise,
    required this.answer,
    required this.clip,
    super.key,
  });

  final ListenWriteExercise exercise;
  final BodyAnswer answer;
  final BodyClip clip;

  @override
  State<ListenWriteBody> createState() => _ListenWriteBodyState();
}

class _ListenWriteBodyState extends State<ListenWriteBody> {
  static const _box = 84.0;
  static const _button = 72.0;
  static const _icon = 32.0;
  static const _failed = 72.0;
  static const _failedIcon = 34.0;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void didUpdateWidget(ListenWriteBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.answer.evaluation != null) _focus.unfocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (clip.status == ClipStatus.failed)
          ClipFailedView(
            circle: _failed,
            iconSize: _failedIcon,
            gap: AppSpacing.sm,
            onRetry: clip.onToggle,
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipButton(
                clip: clip,
                box: _box,
                button: _button,
                icon: _icon,
                waves: true,
              ),
              const SizedBox(width: AppSpacing.md),
              SlowButton(on: clip.playingSlow, onTap: clip.onSlow),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),
        AnswerTextField(
          controller: _controller,
          focusNode: _focus,
          correct: widget.answer.evaluation?.correct,
          onChanged: (text) => widget.answer.onDraft(TextDraft(text)),
        ),
      ],
    );
  }
}
