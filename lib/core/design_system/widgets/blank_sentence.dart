import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:flutter/material.dart';

/// An English sentence with its blank, left to right in any app language. A
/// chosen [word] takes the blank's place, so the whole sentence reads; a long
/// one wraps inside it.
class BlankSentence extends StatelessWidget {
  const BlankSentence({
    required this.before,
    required this.after,
    this.word,
    this.blankColor,
    super.key,
  });

  final String before;
  final String after;
  final String? word;

  /// The line of the empty blank; the border color by default.
  final Color? blankColor;

  static const _blankWidth = 64.0;
  static const _blankHeight = 26.0;
  static const _line = 2.0;
  static final _punctuation = RegExp(r'^[.,?!;:]');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final word = this.word;
    // Punctuation sits against a chosen word, but leaves the blank room.
    final gap = word != null && _punctuation.hasMatch(after) ? '' : ' ';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text.rich(
        locale: const Locale('en'),
        TextSpan(
          style: texts.reading.copyWith(color: colors.textPrimary),
          children: [
            TextSpan(text: '$before '),
            if (word == null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Semantics(
                  label: 'question_blank'.tr(),
                  child: Container(
                    width: _blankWidth,
                    height: _blankHeight,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: blankColor ?? colors.border,
                          width: _line,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              TextSpan(
                text: word,
                style: texts.reading.copyWith(
                  // The strong weight of the same size: each weight has its
                  // own family (ADR 5).
                  fontFamily: texts.bodyStrong.fontFamily,
                  color: colors.primary.text,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.primaryStrong,
                  decorationThickness: _line,
                ),
              ),
            TextSpan(text: '$gap$after'),
          ],
        ),
      ),
    );
  }
}
