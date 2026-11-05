import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/lesson_progress_bar.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/presentation/review/cubit/review_cubit.dart';
import 'package:englizia/features/practice/presentation/widgets/word_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A review (requirements v3.0 §10.3, design "Practice"): a card's face, turned
/// by pressing it anywhere, its back, and «لم أعرفها» or «عرفتها»; then how the
/// review went.
class ReviewPage extends StatelessWidget {
  const ReviewPage({required this.onExit, super.key});

  /// The way out, and «انتهيت».
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BlocBuilder<ReviewCubit, ReviewState>(
        buildWhen: (before, now) => before.done != now.done,
        builder: (context, state) => state.done
            ? _Done(state: state, onFinish: onExit)
            : _Session(onExit: onExit),
      ),
    ),
  );
}

class _Session extends StatefulWidget {
  const _Session({required this.onExit});

  final VoidCallback onExit;

  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> with TickerProviderStateMixin {
  static const _counter = 48.0;

  /// How long the line after an answer stays.
  static const _lineHold = Duration(milliseconds: 900);

  late final _cubit = context.read<ReviewCubit>();
  late final _turn = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  );
  late final _leave = AnimationController(
    vsync: this,
    duration: AppMotion.sheetIn,
  );
  late final _arrive = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
    value: 1,
  );
  Timer? _hold;
  bool? _leftKnown;

  @override
  void dispose() {
    _hold?.cancel();
    _turn.dispose();
    _leave.dispose();
    _arrive.dispose();
    super.dispose();
  }

  Duration _time(Duration full) =>
      AppMotion.reduceMotion(context) ? AppMotion.quick : full;

  Future<void> _answer({required bool known}) async {
    unawaited(AppHaptics.selectionClick());
    setState(() => _leftKnown = known);
    unawaited(_cubit.answer(known: known));
    _leave.duration = _time(AppMotion.sheetIn);
    await _leave.forward(from: 0);
    if (!mounted) return;
    _hold = Timer(_lineHold, () {
      if (!mounted) return;
      _cubit.next();
      _turn.value = 0;
      _leave.value = 0;
      _arrive.duration = _time(AppMotion.fast);
      unawaited(_arrive.forward(from: 0));
    });
  }

  /// The card turns when the state says so, whatever turned it.
  void _turnOver() {
    _turn.duration = _time(AppMotion.medium);
    unawaited(_turn.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return BlocConsumer<ReviewCubit, ReviewState>(
      listenWhen: (before, now) => !before.flipped && now.flipped,
      listener: (_, _) => _turnOver(),
      builder: (context, state) {
        final word = state.word;
        final total = state.words.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: AppSizes.minTapTarget + AppSpacing.sm,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.md,
                  end: AppSpacing.xl - AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onExit,
                      tooltip: 'practice_end_review'.tr(),
                      color: colors.textSecondary,
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: LessonProgressBar(
                        position: state.index + (state.flash == null ? 0 : 1),
                        total: total,
                        label: 'practice_progress'.tr(),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: _counter),
                      child: Text(
                        'practice_counter'.tr(
                          namedArgs: {
                            'at': '${math.min(total, state.index + 1)}',
                            'of': '$total',
                          },
                        ),
                        textAlign: TextAlign.end,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: word == null
                  ? const SizedBox.shrink()
                  : _CardArea(
                      word: word,
                      state: state,
                      turn: _turn,
                      leave: _leave,
                      arrive: _arrive,
                      leftKnown: _leftKnown,
                      onFlip: _cubit.flip,
                      onSayWord: _cubit.sayWord,
                      onSaySentence: _cubit.saySentence,
                    ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl - AppSpacing.xs,
                0,
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.md,
              ),
              child: !state.flipped
                  ? AppButton(
                      label: 'practice_flip'.tr(),
                      size: AppButtonSize.large,
                      onPressed: _cubit.flip,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'practice_again'.tr(),
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.large,
                            icon: Icons.replay_rounded,
                            onPressed: state.flash == null
                                ? () => _answer(known: false)
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppButton(
                            label: 'practice_known'.tr(),
                            size: AppButtonSize.large,
                            icon: Icons.check_rounded,
                            onPressed: state.flash == null
                                ? () => _answer(known: true)
                                : null,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The card, the edge of the next behind it, and the line an answer leaves.
class _CardArea extends StatelessWidget {
  const _CardArea({
    required this.word,
    required this.state,
    required this.turn,
    required this.leave,
    required this.arrive,
    required this.leftKnown,
    required this.onFlip,
    required this.onSayWord,
    required this.onSaySentence,
  });

  final BankWord word;
  final ReviewState state;
  final Animation<double> turn;
  final Animation<double> leave;
  final Animation<double> arrive;
  final bool? leftKnown;
  final VoidCallback onFlip;
  final VoidCallback onSayWord;
  final VoidCallback onSaySentence;

  static const _minHeight = 440.0;
  static const _behindScale = AppMotion.scaleLarge;
  static const _behindDrop = AppMotion.distanceBase;
  static const _rise = 140.0;
  static const _shrink = .3;
  static const _slide = 1.2;
  static const _tilt = 5 * math.pi / 180;
  static const _perspective = .0011;
  static const _lineAt = .42;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduce = AppMotion.reduceMotion(context);
    final side = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final flash = state.flash;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.border),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.lg,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: const Offset(0, _behindDrop),
                    child: Transform.scale(
                      scale: _behindScale,
                      alignment: Alignment.bottomCenter,
                      child: card,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: Listenable.merge([turn, leave, arrive]),
                  builder: (context, child) {
                    final out = AppMotion.inOut.transform(leave.value);
                    final into = AppMotion.smoothOut.transform(arrive.value);
                    var pose = Matrix4.identity();
                    var opacity = 1.0;
                    if (reduce) {
                      opacity = leave.value > 0 ? 1 - leave.value : into;
                    } else if (leave.value > 0) {
                      opacity = 1 - out;
                      pose = leftKnown ?? false
                          ? (Matrix4.translationValues(0, -_rise * out, 0)
                              ..scaleByDouble(
                                1 - _shrink * out,
                                1 - _shrink * out,
                                1,
                                1,
                              ))
                          : (Matrix4.translationValues(
                              side * box.maxWidth * _slide * out,
                              0,
                              0,
                            )..rotateZ(side * _tilt * out));
                    } else if (arrive.value < 1) {
                      final scale = _behindScale + (1 - _behindScale) * into;
                      opacity = .6 + .4 * into;
                      pose = Matrix4.translationValues(
                        0,
                        (_behindDrop + 2) * (1 - into),
                        0,
                      )..scaleByDouble(scale, scale, 1, 1);
                    }
                    final angle = reduce ? 0.0 : turn.value * math.pi;
                    final showBack = reduce
                        ? state.flipped
                        : angle > math.pi / 2;
                    final turned = Matrix4.identity()
                      ..setEntry(3, 2, _perspective)
                      ..rotateY(showBack ? angle - math.pi : angle);
                    return Opacity(
                      opacity: opacity.clamp(0, 1),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: pose,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: turned,
                          child: _Card(
                            word: word,
                            back: showBack,
                            minHeight: _minHeight,
                            onFlip: onFlip,
                            onSayWord: onSayWord,
                            onSaySentence: onSaySentence,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (flash != null)
            PositionedDirectional(
              start: AppSpacing.xl - AppSpacing.xs,
              end: AppSpacing.xl - AppSpacing.xs,
              top: box.maxHeight * _lineAt,
              child: AnimatedBuilder(
                animation: leave,
                builder: (context, _) => leave.value < 1
                    ? const SizedBox.shrink()
                    : _Line(flash: flash),
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.word,
    required this.back,
    required this.minHeight,
    required this.onFlip,
    required this.onSayWord,
    required this.onSaySentence,
  });

  final BankWord word;
  final bool back;
  final double minHeight;
  final VoidCallback onFlip;
  final VoidCallback onSayWord;
  final VoidCallback onSaySentence;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Semantics(
      container: true,
      label: back ? wordSaid(word) : word.word,
      onTapHint: back ? null : 'practice_tap_meaning'.tr(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onFlip,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: colors.border),
          ),
          child: back
              ? Padding(
                  padding: const EdgeInsetsDirectional.all(
                    AppSpacing.xl - AppSpacing.xs,
                  ),
                  child: WordBack(
                    word: word,
                    onSayWord: onSayWord,
                    onSaySentence: onSaySentence,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: WordPicture(word: word),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.xl - AppSpacing.xs,
                        AppSpacing.xl,
                        AppSpacing.xl - AppSpacing.xs,
                        AppSpacing.xl,
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                word.word,
                                textAlign: TextAlign.center,
                                locale: const Locale('en'),
                                style: texts.display.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            SayButton(
                              label: 'practice_listen'.tr(),
                              onTap: onSayWord,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.xl - AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: AppSizes.iconSm,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                          Text(
                            'practice_tap_meaning'.tr(),
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// «تراها بعد 7 أيام» or «تراها غدًا»: where the answer sent the word.
class _Line extends StatelessWidget {
  const _Line({required this.flash});

  final ReviewFlash flash;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = flash.known ? colors.primary.text : colors.textSecondary;
    return Semantics(
      liveRegion: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.resolve(context, AppMotion.closeUp),
        curve: AppMotion.out,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, AppMotion.distanceSmall * (1 - value)),
            child: child,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              flash.known ? Icons.north_rounded : Icons.replay_rounded,
              size: AppSizes.iconMd - 4,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'practice_see_in'.plural(flash.days),
              style: context.texts.bodyStrong.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// «راجعت 12 كلمة», how many moved on and how many come back tomorrow.
class _Done extends StatelessWidget {
  const _Done({required this.state, required this.onFinish});

  final ReviewState state;
  final VoidCallback onFinish;

  static const _halo = 140.0;
  static const _guide = 120.0;
  static const _rowHeight = 52.0;
  static const _dot = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final known = state.known;
    final again = state.answers.length - known;
    Widget row(
      IconData icon,
      Color tint,
      Color ink,
      String text,
      bool strong,
    ) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: Row(
        children: [
          Container(
            width: _dot,
            height: _dot,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: AppSizes.iconSm, color: ink),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
          Expanded(
            child: Text(
              text,
              style: (strong ? texts.bodyStrong : texts.body).copyWith(
                color: strong ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: _halo,
            height: _halo,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.surface,
              shape: BoxShape.circle,
            ),
            child: const Mascot(
              expression: MascotExpression.happy,
              size: _guide,
              animate: false,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              'practice_done'.plural(state.answers.length),
              textAlign: TextAlign.center,
              style: texts.title.copyWith(color: colors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                row(
                  Icons.north_rounded,
                  colors.primary.surface,
                  colors.primary.fill,
                  'practice_done_up'.plural(known),
                  true,
                ),
                Divider(height: 1, color: context.scheme.outlineVariant),
                row(
                  Icons.replay_rounded,
                  colors.background,
                  colors.textSecondary,
                  'practice_done_again'.plural(again),
                  false,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'practice_finish'.tr(),
            size: AppButtonSize.large,
            onPressed: onFinish,
          ),
        ],
      ),
    );
  }
}
