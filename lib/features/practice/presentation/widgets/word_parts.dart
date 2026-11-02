import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/letter_panel.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/services/review_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String wordKindName(WordKind kind) => switch (kind) {
  WordKind.noun => 'practice_kind_noun'.tr(),
  WordKind.verb => 'practice_kind_verb'.tr(),
  WordKind.adjective => 'practice_kind_adjective'.tr(),
  WordKind.adverb => 'practice_kind_adverb'.tr(),
  WordKind.phrase => 'practice_kind_phrase'.tr(),
  WordKind.phrasalVerb => 'practice_kind_phrasal'.tr(),
  WordKind.idiom => 'practice_kind_idiom'.tr(),
  WordKind.word => 'practice_kind_word'.tr(),
};

/// «feed، فعل، يُطعم», for a screen reader.
String wordSaid(BankWord word) => switch (word.kind) {
  final kind? => 'practice_card_said'.tr(
    namedArgs: {
      'word': word.word,
      'kind': wordKindName(kind),
      'meaning': word.arabic,
    },
  ),
  null => 'practice_card_said_plain'.tr(
    namedArgs: {'word': word.word, 'meaning': word.arabic},
  ),
};

/// The word's picture, or its first letter.
class WordPicture extends StatelessWidget {
  const WordPicture({required this.word, this.letter = 88, super.key});

  final BankWord word;
  final double letter;

  @override
  Widget build(BuildContext context) {
    final url = word.imageUrl;
    final panel = LetterPanel(word: word.word, size: letter);
    return ExcludeSemantics(
      child: url == null
          ? panel
          : ColoredBox(
              // ASSUMPTION(design): ILLU_BG, as in a vocabulary card.
              color: context.colors.tiles.neutral.background,
              child: url.startsWith('http')
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => panel,
                    )
                  : SvgPicture.asset(url),
            ),
    );
  }
}

/// A round sound button in the information colour.
class SayButton extends StatelessWidget {
  const SayButton({
    required this.label,
    required this.onTap,
    this.size = 48,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: size < AppSizes.minTapTarget
              ? AppSizes.minTapTarget
              : size,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: colors.info.fill,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIconView(
                  AppIcon.volume,
                  size: size * .45,
                  color: colors.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KindBadge extends StatelessWidget {
  const KindBadge({required this.kind, super.key});

  final WordKind kind;

  static const _height = 24.0;

  @override
  Widget build(BuildContext context) => Container(
    height: _height,
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.sm + AppSpacing.xxs,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_height / 2),
      border: Border.all(color: context.colors.border),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        wordKindName(kind),
        style: context.texts.captionStrong.copyWith(
          color: context.colors.textSecondary,
          height: 1,
        ),
      ),
    ),
  );
}

/// The back of a card, and the word's details: its meaning, its kind, and the
/// sentence it was saved from with the word marked in it.
class WordBack extends StatelessWidget {
  const WordBack({
    required this.word,
    required this.onSayWord,
    required this.onSaySentence,
    super.key,
  });

  final BankWord word;
  final VoidCallback onSayWord;
  final VoidCallback onSaySentence;

  static const _smallSay = 36.0;
  static const _sentenceSay = 40.0;
  static const _dimmed = .5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final kind = word.kind;
    final title = word.lessonTitle;
    final reading = texts.reading.copyWith(color: colors.textPrimary);
    final parts = word.sentence.split(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  word.word,
                  locale: const Locale('en'),
                  style: texts.bodyStrong.copyWith(color: colors.textSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SayButton(
                label: 'practice_listen'.tr(),
                size: _smallSay,
                onTap: onSayWord,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          word.arabic,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: texts.display.copyWith(color: colors.textPrimary),
        ),
        if (kind != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(child: KindBadge(kind: kind)),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.only(
            top: AppSpacing.xl - AppSpacing.xs,
            bottom: AppSpacing.md + AppSpacing.xxs,
          ),
          child: Divider(height: 1, color: context.scheme.outlineVariant),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  locale: const Locale('en'),
                  TextSpan(
                    style: reading,
                    children: [
                      for (final (i, part) in parts.indexed)
                        TextSpan(
                          text: i < parts.length - 1 ? '$part ' : part,
                          style: word.highlighted.contains(i)
                              ? TextStyle(
                                  fontFamily: texts.bodyStrong.fontFamily,
                                  color: colors.reader.selectedWord,
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SayButton(
                label: 'practice_listen_sentence'.tr(),
                size: _sentenceSay,
                onTap: onSaySentence,
              ),
            ],
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'practice_from'.tr(namedArgs: {'title': title}),
            style: texts.caption.copyWith(color: colors.textSecondary),
          ),
        ],
        // ASSUMPTION(design): the design shows it dimmed with «قريبًا», where
        // S §10.3 leaves it out until after the launch.
        if (word.moment != null) ...[
          const SizedBox(height: AppSpacing.md),
          ExcludeSemantics(
            child: Opacity(
              opacity: _dimmed,
              child: Row(
                children: [
                  Container(
                    height: _smallSay,
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.md,
                      end: AppSpacing.md + AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_smallSay / 2),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: AppSizes.iconSm + AppSpacing.xxs,
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                        Text(
                          'practice_watch_clip'.tr(),
                          style: texts.captionStrong.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'practice_soon'.tr(),
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// How firmly a word is kept: five small bars, those reached lit.
class StrengthBars extends StatelessWidget {
  const StrengthBars({required this.box, super.key});

  final int box;

  static const _width = 4.0;
  static const _least = 5.0;
  static const _step = 2.5;
  static const _unreached = .35;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < boxCount; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              Container(
                width: _width,
                height: _least + i * _step,
                decoration: BoxDecoration(
                  color: i < box
                      ? colors.primary.fill
                      : colors.border.withValues(alpha: _unreached),
                  borderRadius: BorderRadius.circular(_width / 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
