import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/core/design_system/widgets/dashed_border.dart';
import 'package:englizia/features/lessons/domain/entities/vocabulary.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/cubit/vocab_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/widgets/save_star.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A kind of word, as its badge says it.
String vocabKindName(VocabKind kind) => switch (kind) {
  VocabKind.noun => 'vocab_kind_noun'.tr(),
  VocabKind.verb => 'vocab_kind_verb'.tr(),
  VocabKind.adjective => 'vocab_kind_adjective'.tr(),
  VocabKind.adverb => 'vocab_kind_adverb'.tr(),
  VocabKind.phrase => 'vocab_kind_phrase'.tr(),
};

/// What a card needs from the lesson. A card behind the top one has none of the
/// presses and none of the sounds.
final class VocabCardView {
  const VocabCardView({
    this.saved = false,
    this.revealed = false,
    this.wordRun,
    this.exampleRun,
    this.audioFailed = false,
  });

  final bool saved;
  final bool revealed;
  final SoundRun? wordRun;
  final SoundRun? exampleRun;
  final bool audioFailed;
}

/// One card: the picture, the word with its sound, its kind and meaning, and the
/// word in a sentence whose translation shows when asked for (S §8.5).
class VocabCard extends StatelessWidget {
  const VocabCard({
    required this.word,
    this.view = const VocabCardView(),
    this.onSave,
    this.onSayWord,
    this.onSayExample,
    this.onReveal,
    super.key,
  });

  final VocabWord word;
  final VocabCardView view;
  final VoidCallback? onSave;
  final VoidCallback? onSayWord;
  final VoidCallback? onSayExample;
  final VoidCallback? onReveal;

  static const radius = AppRadius.xl;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final kind = word.kind;
    final onSave = this.onSave;
    final label = kind == null
        ? 'vocab_card_said_plain'.tr(
            namedArgs: {'word': word.word, 'meaning': word.arabic},
          )
        : 'reader_span_card_said'.tr(
            namedArgs: {
              'base': word.word,
              'kind': vocabKindName(kind),
              'meaning': word.arabic,
            },
          );
    return Semantics(
      container: true,
      label: label,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: context.scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Picture(word: word),
                  if (onSave != null)
                    PositionedDirectional(
                      end: AppSpacing.md,
                      top: AppSpacing.md,
                      child: SaveStar(
                        saved: view.saved,
                        onTap: onSave,
                        raised: true,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.xl - AppSpacing.xs,
                0,
              ),
              child: Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Semantics(
                            button: true,
                            label: 'reader_listen_to'.tr(
                              namedArgs: {'text': word.word},
                            ),
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onSayWord,
                              child: Text(
                                word.word,
                                textAlign: TextAlign.center,
                                locale: const Locale('en'),
                                style: texts.display.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _SayWordButton(
                          run: view.wordRun,
                          failed: view.audioFailed,
                          onTap: onSayWord,
                        ),
                      ],
                    ),
                  ),
                  if (kind != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ExcludeSemantics(child: _KindBadge(kind: kind)),
                  ],
                  const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                  ExcludeSemantics(
                    child: Text(
                      word.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: texts.body.copyWith(
                        fontSize: texts.title.fontSize,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.xl - AppSpacing.xs,
                0,
              ),
              child: Divider(height: 1, color: context.scheme.outlineVariant),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.md + AppSpacing.xxs,
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.xl - AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vocab_in_sentence'.tr(),
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: VocabExampleText(
                            example: word.example,
                            run: view.exampleRun,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (word.example.audioUrl != null)
                          _SayExampleButton(
                            playing: view.exampleRun != null,
                            failed: view.audioFailed,
                            onTap: onSayExample,
                          ),
                      ],
                    ),
                  ),
                  SmoothSize(
                    child: view.revealed
                        ? Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: AppSpacing.sm + AppSpacing.xxs,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                word.example.arabic,
                                textDirection: TextDirection.rtl,
                                style: texts.body.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (!view.revealed && onReveal != null) ...[
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                    _RevealButton(onTap: onReveal!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The word's picture, or its first letter on a soft panel.
class _Picture extends StatelessWidget {
  const _Picture({required this.word});

  final VocabWord word;

  @override
  Widget build(BuildContext context) {
    final url = word.imageUrl;
    return ExcludeSemantics(
      child: url == null
          ? VocabLetter(word: word.word)
          : ColoredBox(
              // ASSUMPTION(design): ILLU_BG is temporary in the design; the
              // neutral tile is its colour in both themes.
              color: context.colors.tiles.neutral.background,
              child: url.startsWith('http')
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, image, progress) =>
                          progress == null ? image : const VocabSkeleton(),
                      errorBuilder: (_, _, _) => VocabLetter(word: word.word),
                    )
                  : SvgPicture.asset(url),
            ),
    );
  }
}

/// A word with no picture: its first letter, large.
class VocabLetter extends StatelessWidget {
  const VocabLetter({required this.word, this.size = 96, super.key});

  final String word;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final display = context.texts.display;
    return ColoredBox(
      color: colors.primary.surface,
      child: Center(
        child: Text(
          word.characters.first,
          textDirection: TextDirection.ltr,
          style: display.copyWith(
            fontSize: display.fontSize! * size / 28,
            height: 1,
            color: colors.primary.fill,
          ),
        ),
      ),
    );
  }
}

/// Where a picture is still loading: a slow pulse, still under reduce motion.
class VocabSkeleton extends StatefulWidget {
  const VocabSkeleton({super.key});

  @override
  State<VocabSkeleton> createState() => _VocabSkeletonState();
}

class _VocabSkeletonState extends State<VocabSkeleton>
    with SingleTickerProviderStateMixin {
  static const _low = .18;
  static const _high = .38;
  static const _still = .28;

  late final _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.characterPulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = context.colors.border;
    final still = AppMotion.reduceMotion(context);
    return Semantics(
      label: 'vocab_picture_loading'.tr(),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) => ColoredBox(
          color: border.withValues(
            alpha: still ? _still : _low + (_high - _low) * _pulse.value,
          ),
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final VocabKind kind;

  static const _height = 24.0;

  @override
  Widget build(BuildContext context) => Container(
    height: _height,
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.sm + AppSpacing.xxs,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_height / 2),
      border: Border.all(color: context.scheme.outline),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        vocabKindName(kind),
        style: context.texts.captionStrong.copyWith(
          color: context.colors.textSecondary,
          height: 1,
        ),
      ),
    ),
  );
}

/// The word's sound, with a ring that fills around it as long as it is said.
class _SayWordButton extends StatelessWidget {
  const _SayWordButton({
    required this.run,
    required this.failed,
    required this.onTap,
  });

  final SoundRun? run;
  final bool failed;
  final VoidCallback? onTap;

  static const _circle = 48.0;
  static const _icon = 22.0;

  @override
  Widget build(BuildContext context) {
    final info = context.colors.info;
    final run = this.run;
    return Semantics(
      button: true,
      label: 'vocab_listen_word'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: _circle,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: info.fill,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: _circle,
                  child: Center(
                    child: AppIconView(
                      failed ? AppIcon.volumeOff : AppIcon.volume,
                      size: _icon,
                      color: context.colors.surface,
                    ),
                  ),
                ),
              ),
              if (run != null && !AppMotion.reduceMotion(context))
                _Ring(key: ValueKey(run.id), length: run.length),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatefulWidget {
  const _Ring({required this.length, super.key});

  /// How long the word is said: the ring is full at its end.
  final Duration length;

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final _fill = AnimationController(vsync: this, duration: widget.length)
    ..forward();

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _fill,
        builder: (_, _) => CustomPaint(
          painter: _RingPainter(
            share: _fill.value,
            color: context.colors.info.fill,
            track: context.colors.info.surface,
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.share,
    required this.color,
    required this.track,
  });

  final double share;
  final Color color;
  final Color track;

  static const _stroke = 3.0;
  static const _gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 + _gap + _stroke / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(rect, 0, math.pi * 2, false, paint..color = track)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * share,
        false,
        paint..color = color,
      );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.share != share ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class _SayExampleButton extends StatelessWidget {
  const _SayExampleButton({
    required this.playing,
    required this.failed,
    required this.onTap,
  });

  final bool playing;
  final bool failed;
  final VoidCallback? onTap;

  static const _circle = 40.0;
  static const _icon = 18.0;
  static const _halo = 4.0;

  @override
  Widget build(BuildContext context) {
    final info = context.colors.info;
    return Semantics(
      button: true,
      toggled: playing,
      label: 'vocab_listen_example'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppSizes.minTapTarget,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.closeUp),
              width: _circle,
              height: _circle,
              decoration: BoxDecoration(
                color: info.fill,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: playing ? info.surface : Colors.transparent,
                    spreadRadius: playing ? _halo : 0,
                  ),
                ],
              ),
              child: Center(
                child: AppIconView(
                  failed ? AppIcon.volumeOff : AppIcon.volume,
                  size: _icon,
                  color: context.colors.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «اضغط لترى الترجمة»: the meaning is the learner's to ask for.
class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.onTap});

  final VoidCallback onTap;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'vocab_reveal_said'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: AppSizes.minTapTarget,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: DashedBorder(
              color: colors.border,
              radius: _height / 2,
              width: 1.5,
              child: Container(
                height: _height,
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.md,
                  end: AppSpacing.md + AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconView(
                      AppIcon.eye,
                      size: AppSizes.iconSm + AppSpacing.xxs,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'vocab_reveal'.tr(),
                      style: context.texts.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The example, the word in it marked, and a mark sliding along the words as
/// its sound says them, as in the reader.
class VocabExampleText extends StatefulWidget {
  const VocabExampleText({required this.example, this.run, super.key});

  final VocabExample example;
  final SoundRun? run;

  @override
  State<VocabExampleText> createState() => _VocabExampleTextState();
}

class _VocabExampleTextState extends State<VocabExampleText>
    with SingleTickerProviderStateMixin {
  final _stage = GlobalKey();
  final _keys = <int, GlobalKey>{};
  late final _clock = AnimationController(vsync: this)..addListener(_follow);
  int? _said;
  Rect? _mark;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(VocabExampleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.run != widget.run) _start();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// The sound's own time: not motion, so reduce motion leaves it be.
  void _start() {
    final run = widget.run;
    if (run == null) {
      _clock.stop();
      if (_said != null) {
        setState(() {
          _said = null;
          _mark = null;
        });
      }
      return;
    }
    _clock
      ..duration = run.length
      ..forward(from: 0);
    _follow();
  }

  void _follow() {
    final run = widget.run;
    if (run == null) return;
    final said = widget.example.tokenAt(run.length * _clock.value, run.length);
    if (said == _said) return;
    _said = said;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final said = _said;
    final stage = _stage.currentContext?.findRenderObject();
    final box = said == null ? null : _keys[said]?.currentContext;
    final word = box?.findRenderObject();
    setState(() {
      _mark = stage is RenderBox && word is RenderBox
          ? word.localToGlobal(Offset.zero, ancestor: stage) & word.size
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.texts.reading.copyWith(color: colors.textPrimary);
    final strong = TextStyle(
      fontFamily: context.texts.bodyStrong.fontFamily,
      color: colors.reader.selectedWord,
    );
    final mark = _mark;
    final tokens = widget.example.tokens;
    return Stack(
      key: _stage,
      clipBehavior: Clip.none,
      children: [
        if (mark != null)
          AnimatedPositionedDirectional(
            duration: AppMotion.resolve(context, AppMotion.closeUp),
            curve: AppMotion.linear,
            start: mark.left - AppSpacing.xs,
            top: mark.top,
            width: mark.width + AppSpacing.sm,
            height: mark.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.reader.karaokeBackground,
                borderRadius: BorderRadius.circular(AppSpacing.sm - 2),
              ),
            ),
          ),
        Wrap(
          spacing:
              MediaQuery.textScalerOf(context).scale(style.fontSize ?? 20) *
              .28,
          children: [
            for (final (i, token) in tokens.indexed)
              Text(
                token.text,
                key: _keys.putIfAbsent(i, GlobalKey.new),
                locale: const Locale('en'),
                style: widget.example.highlighted.contains(token.id)
                    ? style.merge(strong)
                    : style,
              ),
          ],
        ),
      ],
    );
  }
}
