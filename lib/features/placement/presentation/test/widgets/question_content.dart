import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/widgets/blank_sentence.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/core/design_system/widgets/fading_scroll.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';
import 'package:englizia/features/placement/presentation/test/cubit/placement_test_cubit.dart';
import 'package:englizia/features/placement/presentation/test/widgets/listening_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _english = Locale('en');

/// One question: its instruction in the app's language, then its content and
/// options in English, left to right, whatever the app's language.
class QuestionContent extends StatelessWidget {
  const QuestionContent({required this.state, super.key});

  final PlacementTestState state;

  @override
  Widget build(BuildContext context) {
    final question = state.question!;
    final cubit = context.read<PlacementTestCubit>();
    final colors = context.colors;
    final texts = context.texts;
    final instruction = switch (question.kind) {
      PlacementQuestionKind.vocabulary => 'placement_q_vocabulary'.tr(),
      PlacementQuestionKind.grammar => 'placement_q_grammar'.tr(),
      PlacementQuestionKind.reading => 'placement_q_reading'.tr(),
      PlacementQuestionKind.listening => 'placement_q_listening'.tr(),
    };
    final sentence =
        question.kind == PlacementQuestionKind.vocabulary ||
        question.kind == PlacementQuestionKind.grammar;
    final heading = 'placement_question_of'.tr(
      namedArgs: {
        'n': '${state.index + 1}',
        'total': '${state.stageSize}',
        'instruction': instruction,
      },
    );
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            label: heading,
            child: ExcludeSemantics(
              child: Text(
                instruction,
                style: texts.bodyStrong.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
          if (sentence) ...[
            const SizedBox(height: AppSpacing.md),
            BlankSentence(
              before: question.before,
              after: question.after,
              blankColor: colors.textPrimary,
            ),
          ],
          if (question.kind == PlacementQuestionKind.reading) ...[
            const SizedBox(height: AppSpacing.md),
            _PassageCard(key: ValueKey(question.id), text: question.passage),
            const SizedBox(height: AppSpacing.lg),
            _Ask(question.ask),
          ],
          if (question.kind == PlacementQuestionKind.listening) ...[
            const SizedBox(height: AppSpacing.lg),
            ListeningBlock(
              audio: state.audio,
              playsLeft: state.playsLeft,
              maxPlays: question.maxPlays,
              clipLength: state.clipLength,
              playCount: state.playCount,
              onToggle: cubit.togglePlay,
            ),
            const SizedBox(height: AppSpacing.lg),
            _Ask(question.ask),
          ],
          SizedBox(height: sentence ? AppSpacing.xl : AppSpacing.lg),
          for (final option in question.options) ...[
            _Option(
              text: option.text,
              selected: state.optionId == option.id,
              onTap: () => cubit.choose(option.id),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.xxs),
          _DontKnow(selected: state.dontKnow, onTap: cubit.chooseDontKnow),
        ],
      ),
    );
  }
}

class _Ask extends StatelessWidget {
  const _Ask(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(
      text,
      locale: _english,
      style: context.texts.bodyStrong.copyWith(
        color: context.colors.textPrimary,
      ),
    ),
  );
}

/// The reading text, in a card of limited height.
class _PassageCard extends StatelessWidget {
  const _PassageCard({required this.text, super.key});

  final String text;

  static const _maxHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: 'placement_passage'.tr(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          constraints: const BoxConstraints(maxHeight: _maxHeight),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: FadingScroll(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Text(
              text,
              locale: _english,
              style: context.texts.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  static const _minHeight = 56.0;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ChoiceSurface(
      selected: selected,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              ChoiceRadio(selected: selected),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  locale: _english,
                  style: context.texts.body.copyWith(
                    color: context.colors.textPrimary,
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

/// A ring whose dot pops in when chosen. Selection is blue only: nothing here
/// says right or wrong.

/// «لا أعرف»: a choice like the others, dashed until chosen.
class _DontKnow extends StatelessWidget {
  const _DontKnow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return ChoiceSurface(
      selected: selected,
      dashed: !selected,
      onTap: onTap,
      child: SizedBox(
        height: _height,
        child: Center(
          child: Text(
            'placement_dont_know'.tr(),
            style: selected
                ? texts.bodyStrong.copyWith(color: colors.textPrimary)
                : texts.body.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
    );
  }
}
