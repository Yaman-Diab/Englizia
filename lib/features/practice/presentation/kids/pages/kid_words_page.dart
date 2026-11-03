import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/illustrations/empty_box.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/presentation/kids/cubit/kid_words_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Kids' «كلماتي» (requirements v3.0 §13.4, design "Kid Media"): how many
/// words, «العب بكلماتي», the units as pictures, and the words as a grid of
/// pictures that say themselves.
class KidWordsPage extends StatelessWidget {
  const KidWordsPage({required this.onPlay, super.key});

  /// «العب بكلماتي», and back when it ends.
  final Future<void> Function() onPlay;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<KidWordsCubit>();
    return SafeArea(
      bottom: false,
      child: BlocBuilder<KidWordsCubit, KidWordsState>(
        builder: (context, state) => switch (state.load) {
          LoadStatus.loading => const AppStateView.loading(),
          LoadStatus.failure => AppStateView.error(
            message: state.failure!.localizedMessage,
            onRetry: cubit.start,
          ),
          LoadStatus.ready => _Words(
            state: state,
            onPlay: () async {
              await onPlay();
              await cubit.start();
            },
          ),
        },
      ),
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({required this.state, required this.onPlay});

  final KidWordsState state;
  final VoidCallback onPlay;

  static const _cell = 86.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<KidWordsCubit>();
    final bank = state.bank!;
    final empty = bank.words.isEmpty;
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'kid_words_title'.tr(),
                  style: texts.display.copyWith(
                    color: colors.textPrimary,
                    height: 40 / 28,
                  ),
                ),
              ),
              if (!empty)
                Row(
                  children: [
                    const KidStar(size: 24),
                    const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                    Text(
                      'kid_words_count'.plural(bank.words.length),
                      style: texts.title.copyWith(
                        color: colors.textSecondary,
                        fontSize: 20,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        KidGuideButton(
          speaking: state.speaking,
          expression: state.speaking
              ? MascotExpression.talk
              : MascotExpression.welcome,
          onPressed: cubit.sayInstruction,
        ),
      ],
    );
    if (empty) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.xl,
        ),
        child: Column(
          children: [
            header,
            const Spacer(),
            const SizedBox(
              width: 200,
              height: 220,
              child: Stack(
                alignment: AlignmentDirectional.topCenter,
                children: [
                  Mascot(
                    expression: MascotExpression.understand,
                    size: 160,
                    animate: false,
                    sparkles: false,
                  ),
                  PositionedDirectional(top: 104, child: EmptyBox()),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            KidRoundButton(
              icon: const Icon(Icons.volume_up_rounded),
              label: 'kid_listen'.tr(),
              info: true,
              onPressed: cubit.sayInstruction,
            ),
            const Spacer(),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl - AppSpacing.xs,
            0,
          ),
          sliver: SliverList.list(
            children: [
              header,
              const SizedBox(height: AppSpacing.lg),
              _PlayButton(onPressed: onPlay),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _UnitChips(bank: bank, unit: state.unit),
        ),
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xl - AppSpacing.xs,
            AppSpacing.xl - AppSpacing.xs,
          ),
          sliver: SliverGrid.count(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.md + AppSpacing.xxs,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: .78,
            children: [
              for (final word in state.shown)
                _WordCell(
                  word: word,
                  size: _cell,
                  hop: state.said == word.id ? state.sayings : 0,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _height = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'kid_play_words'.tr(),
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: colors.primaryStrong,
              borderRadius: BorderRadius.circular(_height / 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  size: AppSizes.iconLg,
                  color: colors.onPrimaryStrong,
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                Text(
                  'kid_play_words'.tr(),
                  style: context.texts.title.copyWith(
                    color: colors.onPrimaryStrong,
                    fontSize: 20,
                    height: 1,
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

/// The units as pictures only, and «الكل».
class _UnitChips extends StatelessWidget {
  const _UnitChips({required this.bank, required this.unit});

  final WordBank bank;
  final String? unit;

  static const _width = 72.0;
  static const _height = 56.0;
  static const _picture = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<KidWordsCubit>();
    if (bank.units.isEmpty) return const SizedBox.shrink();
    Widget chip({
      required String? id,
      required String label,
      required Widget icon,
    }) {
      final on = unit == id;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => cubit.filter(id),
          child: AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.quick),
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              color: on ? colors.primary.surface : colors.surface,
              borderRadius: BorderRadius.circular(_height / 2),
              border: Border.all(
                color: on ? colors.primaryStrong : colors.border,
                width: on ? 3 : 2,
              ),
            ),
            child: Center(child: icon),
          ),
        ),
      );
    }

    return SizedBox(
      height: _height + AppSpacing.xxs,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xl - AppSpacing.xs,
        ),
        children: [
          chip(
            id: null,
            label: 'kid_words_all'.tr(),
            icon: Icon(
              Icons.grid_view_rounded,
              size: AppSizes.iconMd + AppSpacing.xxs,
              color: colors.primaryStrong,
            ),
          ),
          for (final unit in bank.units) ...[
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            chip(
              id: unit.id,
              label: unit.title,
              icon: KidPicture(url: unit.imageUrl ?? '', size: _picture),
            ),
          ],
        ],
      ),
    );
  }
}

/// A word's picture and the word: pressed, it says itself and hops.
class _WordCell extends StatelessWidget {
  const _WordCell({required this.word, required this.size, required this.hop});

  final BankWord word;
  final double size;

  /// Which press it hops for.
  final int hop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cell = Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.primary.surface,
              borderRadius: BorderRadius.circular(kidRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: KidPicture(
                  url: word.imageUrl ?? '',
                  size: constraints.biggest.shortestSide.clamp(0, size),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          word.word,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.texts.kidsCard.copyWith(
            color: colors.textPrimary,
            fontSize: 20,
            height: 28 / 20,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: word.word,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.read<KidWordsCubit>().say(word),
        child: hop == 0 || AppMotion.reduceMotion(context)
            ? cell
            : KeyedSubtree(
                key: ValueKey(hop),
                child: cell
                    .animate()
                    .moveY(
                      begin: 0,
                      end: -12,
                      duration: AppMotion.kidStarFill * .4,
                      curve: AppMotion.out,
                    )
                    .then()
                    .moveY(
                      begin: 0,
                      end: 12,
                      duration: AppMotion.kidStarFill * .6,
                    ),
              ),
      ),
    );
  }
}
