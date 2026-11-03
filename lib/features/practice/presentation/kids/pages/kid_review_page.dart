import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/presentation/review/cubit/review_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «العب بكلماتي» (requirements v3.0 §13.4, design "Kid Media"): a word's
/// picture says its word by itself, and two faces answer with no text: a smile
/// (I know it) or a wonder (I don't), on the bank's own boxes. At its end a
/// star for each card, whatever the answer.
class KidReviewPage extends StatefulWidget {
  const KidReviewPage({required this.voice, required this.onExit, super.key});

  final KidWordsVoice voice;
  final VoidCallback onExit;

  @override
  State<KidReviewPage> createState() => _KidReviewPageState();
}

class _KidReviewPageState extends State<KidReviewPage>
    with SingleTickerProviderStateMixin {
  late final _cubit = context.read<ReviewCubit>();
  final _barStar = GlobalKey();
  late final _slide = AnimationController(
    vsync: this,
    duration: AppMotion.kidScreenIn,
  );

  /// The way the card leaves: toward the smile, or the wonder.
  var _known = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_cubit.sayLine(widget.voice.review));
      _show();
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  /// The card comes face up and says its word.
  void _show() {
    if (_cubit.state.word == null) return;
    _cubit.flip();
    unawaited(_cubit.sayWord());
  }

  Future<void> _answer({required bool known}) async {
    if (_slide.isAnimating || _cubit.state.word == null) return;
    setState(() => _known = known);
    await _cubit.answer(known: known);
    if (!mounted) return;
    if (!AppMotion.reduceMotion(context)) {
      await _slide.forward(from: 0).orCancel.catchError((_) {});
    }
    if (!mounted) return;
    _cubit.next();
    _slide.value = 0;
    if (_cubit.state.word == null) {
      unawaited(_cubit.sayLine(widget.voice.done));
    } else {
      _show();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    body: SafeArea(
      child: BlocBuilder<ReviewCubit, ReviewState>(
        builder: (context, state) => state.word == null
            ? _Done(stars: state.answers.length, onNext: widget.onExit)
            : Column(
                children: [
                  KidTopBar(
                    progress: state.answers.length,
                    total: state.words.length,
                    speaking: false,
                    expression: MascotExpression.welcome,
                    starKey: _barStar,
                    onExit: widget.onExit,
                    onGuide: () => _cubit.sayLine(widget.voice.review),
                  ),
                  Expanded(child: _card(state.word!)),
                ],
              ),
      ),
    ),
  );

  Widget _card(BankWord word) {
    final colors = context.colors;
    final away =
        (_known ? -1.2 : 1.2) *
        (Directionality.of(context) == TextDirection.rtl ? -1 : 1);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.xl - AppSpacing.xs,
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _slide,
                  builder: (context, child) => Opacity(
                    opacity: 1 - _slide.value,
                    child: FractionalTranslation(
                      translation: Offset(away * _slide.value, 0),
                      child: Transform.rotate(
                        angle: away * .12 * _slide.value,
                        child: child,
                      ),
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(word.id),
                    child: _Face(word: word),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KidRoundButton(
                      icon: const Icon(Icons.sentiment_satisfied_alt_rounded),
                      label: 'kid_know'.tr(),
                      primary: true,
                      size: 88,
                      onPressed: () => _answer(known: true),
                    ),
                    const SizedBox(width: AppSpacing.xxxl - AppSpacing.sm),
                    KidRoundButton(
                      icon: Icon(
                        Icons.help_outline_rounded,
                        color: colors.textSecondary,
                      ),
                      label: 'kid_dont_know'.tr(),
                      size: 88,
                      onPressed: () => _answer(known: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The word's picture and the word, each saying it again.
class _Face extends StatelessWidget {
  const _Face({required this.word});

  final BankWord word;

  static const _height = 320.0;
  static const _picture = 260.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<ReviewCubit>();
    final face = Column(
      children: [
        Semantics(
          button: true,
          label: word.word,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: cubit.sayWord,
            child: Container(
              height: _height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.primary.surface,
                borderRadius: BorderRadius.circular(kidRadius),
              ),
              child: Center(
                child: KidPicture(url: word.imageUrl ?? '', size: _picture),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: cubit.sayWord,
          child: Text(
            word.word,
            textDirection: TextDirection.ltr,
            style: context.texts.kidsCard.copyWith(
              color: colors.textPrimary,
              fontSize: 40,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
    if (AppMotion.reduceMotion(context)) return face;
    final from = Directionality.of(context) == TextDirection.rtl ? -60.0 : 60.0;
    return face
        .animate()
        .fadeIn(duration: AppMotion.kidScreenIn, curve: AppMotion.smoothOut)
        .moveX(begin: from, end: 0, curve: AppMotion.smoothOut)
        .rotate(begin: from / 1500, end: 0);
  }
}

/// The game's end: the guide dancing, and a star for each card.
class _Done extends StatelessWidget {
  const _Done({required this.stars, required this.onNext});

  final int stars;
  final VoidCallback onNext;

  static const _guide = 180.0;
  static const _star = 56.0;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    const guide = Mascot(expression: MascotExpression.happy, size: _guide);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.xxxl + AppSpacing.lg,
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.xl - AppSpacing.xs,
      ),
      child: Column(
        children: [
          if (reduce)
            guide
          else
            const RepaintBoundary(child: guide)
                .animate(onPlay: (dance) => dance.repeat(reverse: true))
                .rotate(
                  begin: -.06,
                  end: .06,
                  alignment: const Alignment(0, .8),
                  duration: AppMotion.kidDance,
                  curve: AppMotion.inOut,
                )
                .moveX(begin: -AppSpacing.sm, end: AppSpacing.sm),
          const SizedBox(height: AppSpacing.xxl),
          Semantics(
            label: 'kid_review_stars'.plural(stars),
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var star = 0; star < stars; star++) ...[
                    if (star > 0) const SizedBox(width: AppSpacing.sm + 2),
                    if (reduce)
                      const KidStar(size: _star)
                    else
                      Stack(
                        children: [
                          const KidStar(size: _star, filled: false),
                          const KidStar(size: _star)
                              .animate(
                                delay:
                                    AppMotion.kidStarFill +
                                    AppMotion.kidStarFlight * .7 * star,
                              )
                              .fadeIn(duration: AppMotion.closeUp)
                              .scaleXY(
                                begin: .4,
                                end: 1,
                                duration: AppMotion.kidStarFill,
                                curve: AppMotion.overshoot,
                              ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          KidRoundButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            label: 'kid_next'.tr(),
            primary: true,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
