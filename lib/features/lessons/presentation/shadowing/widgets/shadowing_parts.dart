import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/widgets/karaoke_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// How many bars a waveform has across its row.
const waveBars = 44;

/// [levels] spread over [waveBars] bars, each the loudest it covers.
List<double> barsOf(List<double> levels) {
  if (levels.isEmpty) return List.filled(waveBars, 0);
  return [
    for (var i = 0; i < waveBars; i++)
      levels
          .sublist(
            i * levels.length ~/ waveBars,
            math.max(
              i * levels.length ~/ waveBars + 1,
              (i + 1) * levels.length ~/ waveBars,
            ),
          )
          .reduce(math.max),
  ];
}

/// The model's waveform: the server's, or drawn from when its words are said,
/// each word a hump the size of its letters.
List<double> modelBars(ReaderSentence sentence) {
  if (sentence.waveform.isNotEmpty) return barsOf(sentence.waveform);
  final span = sentence.end - sentence.start;
  if (span <= Duration.zero) return List.filled(waveBars, 0);
  return [
    for (var i = 0; i < waveBars; i++)
      () {
        final at = sentence.start + span * ((i + .5) / waveBars);
        for (final word in sentence.words) {
          if (at >= word.start && at < word.end) {
            final into =
                (at - word.start).inMicroseconds /
                (word.end - word.start).inMicroseconds;
            final size = math.min(1, .35 + word.text.length * .08);
            return size * (.55 + .45 * math.sin(math.pi * into));
          }
        }
        return 0.0;
      }(),
  ];
}

/// Bars standing on a middle line, left to right whatever the language.
class WaveBars extends StatelessWidget {
  const WaveBars({
    required this.bars,
    required this.color,
    this.shown = 1,
    super.key,
  });

  final List<double> bars;
  final Color color;

  /// The share drawn so far, while it is still being recorded.
  final double shown;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _WavePainter(bars: bars, color: color, shown: shown),
    child: const SizedBox.expand(),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.bars,
    required this.color,
    required this.shown,
  });

  final List<double> bars;
  final Color color;
  final double shown;

  static const _bar = 4.0;
  static const _least = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final step = size.width / bars.length;
    final paint = Paint()
      ..color = color
      ..strokeWidth = _bar
      ..strokeCap = StrokeCap.round;
    final middle = size.height / 2;
    final count = (bars.length * shown).round();
    for (var i = 0; i < count; i++) {
      final height = math.max(_least, bars[i] * (size.height - _bar));
      final x = step * (i + .5);
      canvas.drawLine(
        Offset(x, middle - height / 2 + _bar / 2),
        Offset(x, middle + height / 2 - _bar / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.color != color ||
      oldDelegate.shown != shown;
}

/// A line crossing its row for as long as [run] lasts.
class PlayLine extends StatefulWidget {
  const PlayLine({required this.run, super.key});

  final SoundRun run;

  @override
  State<PlayLine> createState() => _PlayLineState();
}

class _PlayLineState extends State<PlayLine>
    with SingleTickerProviderStateMixin {
  static const _width = 2.0;

  late final _clock = AnimationController(
    vsync: this,
    duration: widget.run.length,
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => AnimatedBuilder(
      animation: _clock,
      builder: (_, _) => Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            PositionedDirectional(
              start: box.maxWidth * _clock.value - _width / 2,
              top: 0,
              bottom: 0,
              width: _width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.textPrimary,
                  borderRadius: BorderRadius.circular(_width / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shadowing with the model: the learner's voice drawn as it comes, from the
/// left, in time with the model, and a small button in its middle to stop.
class LiveWave extends StatefulWidget {
  const LiveWave({
    required this.levels,
    required this.length,
    required this.onStop,
    super.key,
  });

  final Stream<double> levels;

  /// How long it listens: the model and a second after it.
  final Duration length;
  final VoidCallback onStop;

  @override
  State<LiveWave> createState() => _LiveWaveState();
}

class _LiveWaveState extends State<LiveWave>
    with SingleTickerProviderStateMixin {
  static const _height = 56.0;
  static const _stop = 40.0;
  static const _ring = 4.0;
  static const _line = 2.0;

  final _bars = List<double>.filled(waveBars, 0);
  final _share = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final StreamSubscription<double> _subscription;
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.levels.listen((level) => _level = level);
    _ticker = createTicker((elapsed) {
      final share = (elapsed.inMicroseconds / widget.length.inMicroseconds)
          .clamp(0.0, 1.0);
      final bar = math.min(waveBars - 1, (share * waveBars).floor());
      _bars[bar] = math.max(_bars[bar], _level);
      _share.value = share;
    });
    unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_subscription.cancel());
    _share.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: _height,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _share,
              builder: (context, share, _) => LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: WaveBars(
                          bars: List.of(_bars),
                          color: colors.primary.fill,
                          shown: share,
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: box.maxWidth * share - _line / 2,
                      top: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      width: _line,
                      child: ColoredBox(color: colors.primaryStrong),
                    ),
                  ],
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'lesson_mic_stop'.tr(),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: widget.onStop,
                child: Container(
                  width: _stop,
                  height: _stop,
                  decoration: BoxDecoration(
                    color: colors.primaryStrong,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: colors.surface, spreadRadius: _ring),
                    ],
                  ),
                  child: Icon(
                    Icons.stop_rounded,
                    size: AppSizes.iconMd,
                    color: colors.onPrimaryStrong,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «بلا نص» before the try: grey bars the length of the words.
class HiddenWords extends StatelessWidget {
  const HiddenWords({required this.sentence, super.key});

  final ReaderSentence sentence;

  static const _height = 16.0;
  static const _letter = 11.0;
  static const _least = 8.0;
  static const _dim = .55;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'shadow_hidden'.tr(),
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: AppSpacing.md + 1,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm + AppSpacing.xxs,
          children: [
            for (final word in sentence.words)
              Container(
                width:
                    word.text.replaceAll(RegExp(r'\W'), '').length * _letter +
                    _least,
                height: _height,
                decoration: BoxDecoration(
                  color: context.colors.border.withValues(alpha: _dim),
                  borderRadius: BorderRadius.circular(_height / 2),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The three ways, as a switch whose white thumb slides to the one chosen.
class ShadowingModeSwitch extends StatelessWidget {
  const ShadowingModeSwitch({
    required this.mode,
    required this.onPick,
    super.key,
  });

  final ShadowingMode mode;
  final ValueChanged<ShadowingMode> onPick;

  static const _height = 40.0;
  static const _inset = 2.0;

  static String nameOf(ShadowingMode mode) => switch (mode) {
    ShadowingMode.repeat => 'shadow_mode_repeat'.tr(),
    ShadowingMode.together => 'shadow_mode_together'.tr(),
    ShadowingMode.hidden => 'shadow_mode_hidden'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final modes = ShadowingMode.values;
    final index = modes.indexOf(mode);
    return Semantics(
      label: 'shadow_modes'.tr(),
      container: true,
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(_height / 2),
          border: Border.all(color: context.scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: AppMotion.resolve(context, AppMotion.closeUp),
              curve: AppMotion.smoothOut,
              alignment: AlignmentDirectional(
                -1 + 2 * index / (modes.length - 1),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / modes.length,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(_inset),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(_height / 2),
                      border: Border.all(color: colors.border),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final option in modes)
                  Expanded(
                    child: Semantics(
                      inMutuallyExclusiveGroup: true,
                      checked: option == mode,
                      button: true,
                      label: nameOf(option),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onPick(option),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.resolve(
                              context,
                              AppMotion.quick,
                            ),
                            style:
                                (option == mode
                                        ? texts.captionStrong
                                        : texts.caption)
                                    .copyWith(
                                      color: option == mode
                                          ? colors.textPrimary
                                          : colors.textSecondary,
                                    ),
                            child: Text(
                              nameOf(option),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
