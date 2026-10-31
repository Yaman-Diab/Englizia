import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:flutter/material.dart';

/// A sentence with a field in its line, growing with what is typed, and the base
/// word in brackets after it. The keyboard opens by itself, and Enter checks.
class FillTypedBody extends StatefulWidget {
  const FillTypedBody({
    required this.exercise,
    required this.answer,
    super.key,
  });

  final FillTypedExercise exercise;
  final BodyAnswer answer;

  @override
  State<FillTypedBody> createState() => _FillTypedBodyState();
}

class _FillTypedBodyState extends State<FillTypedBody> {
  static const _lineHeight = 48.0;
  static const _fieldHeight = 40.0;
  static const _minWidth = 88.0;
  static const _perLetter = 12.5;
  static const _sidePadding = 20.0;
  static const _iconSize = 14.0;

  /// The new question has arrived by then.
  static const _focusAfter = Duration(milliseconds: 320);

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    _focusTimer = Timer(_focusAfter, _focus.requestFocus);
  }

  void _refresh() => setState(() {});

  @override
  void didUpdateWidget(FillTypedBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.answer.evaluation != null) _focus.unfocus();
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final colors = context.colors;
    final texts = context.texts;
    final reading = texts.reading;
    final evaluation = widget.answer.evaluation;
    final tone = evaluation == null
        ? null
        : evaluation.correct
        ? colors.success
        : colors.error;
    final line =
        tone?.fill ??
        (_focus.hasFocus ? colors.primaryStrong : context.scheme.outline);
    final strong = reading.copyWith(
      fontFamily: texts.bodyStrong.fontFamily,
      color: tone?.text ?? colors.primary.text,
    );
    final width = math.max(
      _minWidth,
      _controller.text.length * _perLetter + _sidePadding,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text.rich(
        locale: const Locale('en'),
        TextSpan(
          style: reading.copyWith(
            color: colors.textPrimary,
            height: _lineHeight / reading.fontSize!,
          ),
          children: [
            TextSpan(text: exercise.before),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm - AppSpacing.xxs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.resolve(context, AppMotion.micro),
                      width: width,
                      height: _fieldHeight,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: line, width: 2),
                        ),
                      ),
                      child: Semantics(
                        label: 'lesson_typed_field'.tr(),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          readOnly: evaluation != null,
                          textAlign: TextAlign.center,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.none,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          spellCheckConfiguration:
                              const SpellCheckConfiguration.disabled(),
                          keyboardType: TextInputType.visiblePassword,
                          textInputAction: TextInputAction.done,
                          style: strong,
                          onChanged: (text) {
                            setState(() {});
                            widget.answer.onDraft(TextDraft(text));
                          },
                          onSubmitted: (_) => widget.answer.onSubmit(),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsetsDirectional.only(
                              top: AppSpacing.xs,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (evaluation != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        evaluation.correct
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size: _iconSize,
                        color: tone?.fill,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            TextSpan(
              text: '${exercise.baseWord} ',
              style: TextStyle(color: colors.textSecondary),
            ),
            TextSpan(text: exercise.after),
          ],
        ),
      ),
    );
  }
}
