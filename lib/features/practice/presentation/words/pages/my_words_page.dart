import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/presentation/widgets/word_parts.dart';
import 'package:englizia/features/practice/presentation/words/cubit/my_words_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «كلماتي» (requirements v3.0 §10.4, design "Practice"): every word with its
/// meaning and strength, found by search or filter, and a sheet for each.
class MyWordsPage extends StatefulWidget {
  const MyWordsPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<MyWordsPage> createState() => _MyWordsPageState();
}

class _MyWordsPageState extends State<MyWordsPage> {
  final _query = TextEditingController();
  late final _cubit = context.read<MyWordsCubit>();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _query.clear();
    _cubit.closeSearch();
  }

  Future<void> _open(BankWord word) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: sheetAnimation(context),
    builder: (_) => _WordSheet(
      word: word,
      onSay: _cubit.say,
      onRemove: () => _cubit.remove(word),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<MyWordsCubit, MyWordsState>(
          builder: (context, state) {
            final shown = _cubit.shown;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: AppSizes.minTapTarget + AppSpacing.sm,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.xs,
                      end: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: widget.onBack,
                          tooltip: 'common_back'.tr(),
                          color: colors.textPrimary,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        if (state.searching)
                          Expanded(
                            child: _SearchField(
                              controller: _query,
                              onChanged: _cubit.search,
                              onClose: _closeSearch,
                            ),
                          )
                        else ...[
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                'practice_my_words'.tr(),
                                style: texts.bodyStrong.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _cubit.openSearch,
                            tooltip: 'practice_search'.tr(),
                            color: colors.textPrimary,
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _Filters(selected: state.filter, onPick: _cubit.setFilter),
                Expanded(
                  child: shown.isEmpty
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(
                            top: AppSpacing.xxl,
                          ),
                          child: Text(
                            'practice_no_results'.tr(),
                            textAlign: TextAlign.center,
                            style: texts.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          itemCount: shown.length,
                          itemBuilder: (context, i) => _WordRow(
                            word: shown[i],
                            onTap: () => _open(shown[i]),
                            onSay: () => _cubit.say(shown[i].audioUrl),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  static const _height = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: _height,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.md + AppSpacing.xxs,
        end: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: colors.primaryStrong, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: AppSizes.iconSm + AppSpacing.xxs,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              style: context.texts.body.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'practice_search_hint'.tr(),
                hintStyle: context.texts.body.copyWith(
                  color: colors.textSecondary,
                ),
                semanticCounterText: '',
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'practice_search_close'.tr(),
            color: colors.textSecondary,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onPick});

  final WordFilter selected;
  final ValueChanged<WordFilter> onPick;

  static const _height = 36.0;

  String _name(WordFilter filter) => switch (filter) {
    WordFilter.all => 'practice_filter_all'.tr(),
    WordFilter.due => 'practice_filter_due'.tr(),
    WordFilter.learning => 'practice_filter_learning'.tr(),
    WordFilter.firm => 'practice_filter_firm'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'practice_filter'.tr(),
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            for (final (i, filter) in WordFilter.values.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: filter == selected,
                button: true,
                label: _name(filter),
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onPick(filter),
                  child: AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.quick),
                    height: _height,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: AppSpacing.md + AppSpacing.xxs,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filter == selected
                          ? colors.primary.surface
                          : colors.surface,
                      borderRadius: BorderRadius.circular(_height / 2),
                      border: Border.all(
                        color: filter == selected
                            ? colors.primaryStrong
                            : colors.border,
                      ),
                    ),
                    child: Text(
                      _name(filter),
                      style: context.texts.captionStrong.copyWith(
                        color: filter == selected
                            ? colors.primary.text
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.word,
    required this.onTap,
    required this.onSay,
  });

  final BankWord word;
  final VoidCallback onTap;
  final VoidCallback onSay;

  static const _height = 72.0;
  static const _say = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Semantics(
      button: true,
      label: 'practice_row_said'.tr(
        namedArgs: {
          'word': word.word,
          'meaning': word.arabic,
          'box': '${word.box}',
        },
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _height),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.scheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        word.word,
                        textDirection: TextDirection.ltr,
                        locale: const Locale('en'),
                        style: texts.bodyStrong.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        word.arabic,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              StrengthBars(box: word.box),
              const SizedBox(width: AppSpacing.sm),
              SayButton(
                label: 'practice_listen'.tr(),
                size: _say,
                onTap: onSay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A word's back in full, and taking it out of the bank after asking.
class _WordSheet extends StatefulWidget {
  const _WordSheet({
    required this.word,
    required this.onSay,
    required this.onRemove,
  });

  final BankWord word;
  final ValueChanged<String?> onSay;
  final Future<void> Function() onRemove;

  @override
  State<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<_WordSheet> {
  bool _asking = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final word = widget.word;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.md,
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.resolve(context, AppMotion.quick),
          child: _asking
              ? Column(
                  key: const ValueKey('ask'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'practice_delete_title'.tr(
                          namedArgs: {'word': word.word},
                        ),
                        textAlign: TextAlign.center,
                        style: texts.title.copyWith(color: colors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'practice_delete_body'.tr(),
                      textAlign: TextAlign.center,
                      style: texts.body.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                    AppButton(
                      label: 'practice_cancel'.tr(),
                      size: AppButtonSize.large,
                      onPressed: () => setState(() => _asking = false),
                    ),
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await widget.onRemove();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error.text,
                        side: BorderSide(color: colors.error.fill),
                        minimumSize: const Size.fromHeight(
                          AppSizes.minTapTarget + AppSpacing.sm,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: texts.button,
                      ),
                      child: Text('practice_delete_confirm'.tr()),
                    ),
                  ],
                )
              : Column(
                  key: const ValueKey('word'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      container: true,
                      label: wordSaid(word),
                      child: WordBack(
                        word: word,
                        onSayWord: () => widget.onSay(word.audioUrl),
                        onSaySentence: () =>
                            widget.onSay(word.sentenceAudioUrl),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _asking = true),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.error.text,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text('practice_delete'.tr()),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
