import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/widgets/clip_failed_view.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/clip_button.dart';
import 'package:flutter/material.dart';

/// A clip, and a field to write what it says. The keyboard pushes everything up
/// and covers nothing, and helps with nothing either: suggestions would write
/// the answer for the learner (S §7.4).
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
  static const _lines = 4;

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
    final colors = context.colors;
    final clip = widget.clip;
    final evaluation = widget.answer.evaluation;
    final Color? judged = evaluation == null
        ? null
        : evaluation.correct
        ? colors.success.fill
        : colors.error.fill;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
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
        TextField(
          controller: _controller,
          focusNode: _focus,
          readOnly: evaluation != null,
          textDirection: TextDirection.ltr,
          minLines: _lines,
          maxLines: _lines,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          style: context.texts.body.copyWith(color: colors.textPrimary),
          onChanged: (text) => widget.answer.onDraft(TextDraft(text)),
          decoration: InputDecoration(
            hintText: 'lesson_write_hint'.tr(),
            filled: true,
            fillColor: colors.surface,
            enabledBorder: border(
              judged ?? context.scheme.outline,
              judged == null ? 1 : 2,
            ),
            focusedBorder: border(judged ?? colors.primaryStrong, 2),
          ),
        ),
      ],
    );
  }
}
