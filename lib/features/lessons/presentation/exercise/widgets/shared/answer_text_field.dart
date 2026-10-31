import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// A field to write English in. The keyboard pushes everything up and covers
/// nothing, and helps with nothing either: suggestions would write the answer for
/// the learner (S §7.4). The controller and focus are the caller's.
class AnswerTextField extends StatelessWidget {
  const AnswerTextField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.correct,
    this.readOnly = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  /// The verdict, once checked.
  final bool? correct;
  final bool readOnly;

  static const _lines = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final correct = this.correct;
    final judged = correct == null
        ? null
        : correct
        ? colors.success.fill
        : colors.error.fill;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly || correct != null,
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
      onChanged: onChanged,
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
    );
  }
}
