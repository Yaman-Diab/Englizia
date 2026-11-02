import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/smooth_size.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/word_line.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/reader_cubit.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Where each sentence and word sits, for the sound to follow and a card to point at.
final class ReaderKeys {
  final _sentences = <int, GlobalKey>{};
  final _words = <String, GlobalKey>{};

  GlobalKey sentence(int index) => _sentences.putIfAbsent(index, GlobalKey.new);

  GlobalKey word(int sentence, int word) =>
      _words.putIfAbsent('$sentence-$word', GlobalKey.new);
}

/// The text's look for the size chosen.
TextStyle readerTextStyle(BuildContext context, ReaderTextSize size) {
  final base = context.texts.reading;
  final share = switch (size) {
    ReaderTextSize.small => 18 / 20,
    ReaderTextSize.medium => 1.0,
    ReaderTextSize.large => 24 / 20,
  };
  return base.copyWith(
    fontSize: base.fontSize! * share,
    color: context.colors.textPrimary,
  );
}

/// What a sentence needs from the state. Its own widget and values, so moving
/// from word to word redraws the current sentence only (design's note).
final class SentenceView extends Equatable {
  const SentenceView({
    required this.current,
    required this.saidWord,
    required this.saidFor,
    required this.open,
    required this.revealed,
    required this.selection,
    required this.mode,
    required this.size,
    this.dim = false,
  });

  final bool current;

  /// A video's other sentences, around the one it is at.
  final bool dim;
  final int? saidWord;

  /// How long the word said lasts, for the mark to slide along it.
  final Duration saidFor;
  final bool open;
  final bool revealed;
  final ReaderSelection? selection;
  final ReaderMode mode;
  final ReaderTextSize size;

  @override
  List<Object?> get props => [
    current,
    saidWord,
    saidFor,
    open,
    revealed,
    selection,
    mode,
    size,
    dim,
  ];
}

class ReaderSentenceBlock extends StatefulWidget {
  const ReaderSentenceBlock({
    required this.index,
    required this.sentence,
    required this.content,
    required this.view,
    required this.keys,
    required this.onTapSentence,
    required this.onTapWord,
    required this.onListen,
    required this.onToggleTranslation,
    required this.onReveal,
    this.video = false,
    this.compact = false,
    super.key,
  });

  final int index;
  final ReaderSentence sentence;
  final ReaderContent content;
  final SentenceView view;
  final ReaderKeys keys;
  final VoidCallback onTapSentence;

  /// Whether the word took the press.
  final bool Function(int word) onTapWord;
  final VoidCallback onListen;
  final VoidCallback onToggleTranslation;
  final VoidCallback onReveal;

  /// Under a video: its sentences can't be revealed while practising listening, and
  /// the tool says the sentence again in the video.
  final bool video;

  /// Beside a video: only to read along, with no tools.
  final bool compact;

  @override
  State<ReaderSentenceBlock> createState() => _ReaderSentenceBlockState();
}

class _ReaderSentenceBlockState extends State<ReaderSentenceBlock> {
  static const _sameLine = 4.0;

  final _stage = GlobalKey();
  Rect? _said;

  /// The mark changed lines, so it goes there at once and doesn't cross the text.
  bool _saidJumped = false;
  ({Offset from, Offset to})? _arc;

  @override
  void initState() {
    super.initState();
    _measureLater();
  }

  @override
  void didUpdateWidget(ReaderSentenceBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) _measureLater();
  }

  void _measureLater() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  Rect? _rectOf(int word) {
    final stage = _stage.currentContext?.findRenderObject();
    final box = widget.keys
        .word(widget.index, word)
        .currentContext
        ?.findRenderObject();
    if (stage is! RenderBox || box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: stage) & box.size;
  }

  void _measure() {
    if (!mounted) return;
    final view = widget.view;
    final word = view.saidWord;
    final said = view.current && word != null ? _rectOf(word) : null;
    final arc = _measureArc();
    if (said != _said || arc != _arc) {
      setState(() {
        final before = _said;
        _saidJumped =
            before != null &&
            said != null &&
            (before.top - said.top).abs() > _sameLine;
        _said = said;
        _arc = arc;
      });
    }
  }

  /// Between the first and last word of a span with others between them, when
  /// they share a line; otherwise the color says enough.
  ({Offset from, Offset to})? _measureArc() {
    final span = widget.view.selection?.span;
    if (span == null || span.sentenceId != widget.sentence.id) return null;
    final words = widget.sentence.words;
    final indices = [
      for (final (i, word) in words.indexed)
        if (span.wordIds.contains(word.id)) i,
    ];
    if (indices.length < 2 || indices.last - indices.first < indices.length) {
      return null;
    }
    final a = _rectOf(indices.first);
    final b = _rectOf(indices.last);
    if (a == null || b == null || (a.top - b.top).abs() > _sameLine) {
      return null;
    }
    return (from: a.topCenter, to: b.topCenter);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final view = widget.view;
    final mode = view.mode;
    final sentence = widget.sentence;
    final hidden = mode == ReaderMode.listening && !view.revealed;
    final image = sentence.imageUrl;
    final speaker = sentence.speaker;
    final translation =
        (mode == ReaderMode.onTap && view.open) ||
        mode == ReaderMode.below ||
        (mode == ReaderMode.currentTranslated && view.current && view.open);
    return Semantics(
      container: true,
      label: speaker == null
          ? sentence.english
          : '$speaker: ${sentence.english}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTapSentence,
        child: AnimatedContainer(
          key: widget.keys.sentence(widget.index),
          duration: AppMotion.resolve(context, AppMotion.fast),
          padding: const EdgeInsetsDirectional.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: view.current
                ? colors.reader.sentenceBand
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (speaker != null) _Speaker(name: speaker),
              if (mode == ReaderMode.arabicFirst ||
                  mode == ReaderMode.arabicOnly) ...[
                _Arabic(
                  text: sentence.arabic,
                  strong: mode == ReaderMode.arabicOnly && !view.dim,
                ),
                if (mode == ReaderMode.arabicFirst)
                  const SizedBox(height: AppSpacing.sm),
              ],
              if (hidden)
                _HiddenLines(
                  english: sentence.english,
                  current: view.current,
                  size: view.size,
                  onReveal: widget.video ? null : widget.onReveal,
                )
              else if (mode != ReaderMode.arabicOnly)
                _words(context),
              if (image != null) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Semantics(
                      image: true,
                      label: sentence.imageAlt,
                      child: ColoredBox(
                        color: colors.primary.surface,
                        child: image.startsWith('http')
                            ? Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              )
                            : SvgPicture.asset(image),
                      ),
                    ),
                  ),
                ),
              ],
              if (mode == ReaderMode.onTap ||
                  mode == ReaderMode.below ||
                  mode == ReaderMode.currentTranslated)
                SmoothSize(
                  child: translation
                      ? _Translation(text: sentence.arabic)
                      : const SizedBox(width: double.infinity),
                ),
              if (view.current &&
                  mode != ReaderMode.listening &&
                  !widget.compact)
                Entrance(
                  key: ValueKey('tools:${widget.index}'),
                  motion: EntranceMotion.down,
                  delay: Duration.zero,
                  duration: AppMotion.fast,
                  distance: AppMotion.distanceMicro,
                  child: _Tools(
                    showsTranslation:
                        mode == ReaderMode.onTap ||
                        mode == ReaderMode.currentTranslated,
                    video: widget.video,
                    open: view.open,
                    onListen: widget.onListen,
                    onToggle: widget.onToggleTranslation,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _words(BuildContext context) {
    final view = widget.view;
    final colors = context.colors;
    final style = readerTextStyle(context, view.size);
    final ink = view.dim ? colors.textSecondary : style.color!;
    final selection = view.selection;
    final said = _said;
    final arc = _arc;
    final space =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 20) * .28;
    final words = widget.sentence.words;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: NotificationListener<SizeChangedLayoutNotification>(
        // Turning the phone moves the words under the mark.
        onNotification: (_) {
          _measureLater();
          return true;
        },
        child: SizeChangedLayoutNotifier(
          child: Stack(
            key: _stage,
            clipBehavior: Clip.none,
            children: [
              if (said != null)
                AnimatedPositionedDirectional(
                  duration: _saidJumped
                      ? Duration.zero
                      : AppMotion.resolve(context, view.saidFor),
                  curve: AppMotion.linear,
                  start: said.left - AppSpacing.xs,
                  top: said.top,
                  width: said.width + AppSpacing.sm,
                  height: said.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.reader.karaokeBackground,
                      borderRadius: BorderRadius.circular(AppSpacing.sm - 2),
                    ),
                  ),
                ),
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: ink),
                duration: AppMotion.resolve(context, AppMotion.fast),
                curve: AppMotion.out,
                builder: (context, color, _) => Wrap(
                  spacing: space,
                  children: [
                    for (final (i, word) in words.indexed)
                      _Word(
                        key: widget.keys.word(widget.index, i),
                        text: word.text,
                        style: style.copyWith(color: color),
                        span: widget.content.spanOf(widget.sentence, word),
                        selected:
                            selection != null &&
                            (selection.span?.wordIds.contains(word.id) ??
                                selection.word == i),
                        said: view.current && view.saidWord == i,
                        onTap: () => widget.onTapWord(i),
                      ),
                  ],
                ),
              ),
              if (arc != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TimedValue(
                      delay: Duration.zero,
                      duration: AppMotion.fast,
                      builder: (context, value) => CustomPaint(
                        painter: _ArcPainter(
                          from: arc.from,
                          to: arc.to,
                          progress: value,
                          color: colors.reader.selectedWord,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A word. Heavier without getting wider, so the line never moves under the sound.
class _Word extends StatelessWidget {
  const _Word({
    required this.text,
    required this.style,
    required this.span,
    required this.selected,
    required this.said,
    required this.onTap,
    super.key,
  });

  final String text;
  final TextStyle style;
  final ReaderSpan? span;
  final bool selected;
  final bool said;
  final VoidCallback onTap;

  static const _heavier = .35;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    final color = selected ? reader.selectedWord : style.color!;
    final span = this.span;
    final label = span == null
        ? null
        : 'reader_span_said'.tr(
            namedArgs: {'base': span.base, 'kind': spanKindName(span.kind)},
          );
    final word = Text(
      text,
      locale: const Locale('en'),
      style: style.copyWith(
        color: color,
        shadows: selected || said
            ? [Shadow(color: color, offset: const Offset(_heavier, 0))]
            : null,
      ),
    );
    return Semantics(
      container: span != null,
      button: span != null,
      label: label,
      excludeSemantics: span != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: span == null || selected
            ? word
            : CustomPaint(
                foregroundPainter: WordLine(
                  color: reader.tappableUnderline,
                  dotted: true,
                ),
                child: word,
              ),
      ),
    );
  }
}

String spanKindName(SpanKind kind) => switch (kind) {
  SpanKind.word => 'reader_kind_word'.tr(),
  SpanKind.phrasalVerb => 'reader_kind_phrasal'.tr(),
  SpanKind.idiom => 'reader_kind_idiom'.tr(),
};

/// A dotted arc over what stands between the words of a span, drawn from the first
/// to the last.
class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final double progress;
  final Color color;

  static const _rise = 14.0;
  static const _stroke = 1.5;
  static const _dot = 3.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = Offset((from.dx + to.dx) / 2, from.dy - _rise);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      final end = metric.length * progress;
      for (var at = 0.0; at < end; at += _dot + _gap) {
        final stop = at + _dot > end ? end : at + _dot;
        canvas.drawPath(metric.extractPath(at, stop), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.color != color;
}

/// Who says it, above the sentence in every way of showing it (S §8.4).
class _Speaker extends StatelessWidget {
  const _Speaker({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xxs),
    child: Text(
      name,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      locale: const Locale('en'),
      style: context.texts.captionStrong.copyWith(
        color: context.colors.textSecondary,
      ),
    ),
  );
}

class _Arabic extends StatelessWidget {
  const _Arabic({required this.text, required this.strong});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textDirection: TextDirection.rtl,
    style: context.texts.body.copyWith(
      color: strong ? context.colors.textPrimary : context.colors.textSecondary,
    ),
  );
}

class _Translation extends StatelessWidget {
  const _Translation({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
    padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.scheme.outline)),
    ),
    child: _Arabic(text: text, strong: false),
  );
}

/// Grey bars the length of the lines, with «أظهر»: listening has nothing to read.
class _HiddenLines extends StatelessWidget {
  const _HiddenLines({
    required this.english,
    required this.current,
    required this.size,
    required this.onReveal,
  });

  final String english;
  final bool current;
  final ReaderTextSize size;
  final VoidCallback? onReveal;

  static const _height = 14.0;

  /// A letter's share of a line of the medium size, near enough for a bar.
  static const _letter = .035;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    final scale = switch (size) {
      ReaderTextSize.small => .9,
      ReaderTextSize.medium => 1.0,
      ReaderTextSize.large => 1.2,
    };
    var left = english.length * _letter * scale;
    final lines = <double>[];
    while (left > 0) {
      lines.add(left >= 1 ? 1 : (left < .18 ? .18 : left));
      left -= 1;
    }
    return Semantics(
      label: 'reader_hidden_sentence'.tr(),
      excludeSemantics: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final share in lines) ...[
              Directionality(
                textDirection: TextDirection.ltr,
                child: FractionallySizedBox(
                  widthFactor: share,
                  child: AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.fast),
                    height: _height,
                    decoration: BoxDecoration(
                      color: current
                          ? reader.karaokeBackground
                          : context.scheme.outline,
                      borderRadius: BorderRadius.circular(_height / 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (onReveal case final onReveal?)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: onReveal,
                  child: Text('reader_reveal'.tr()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.showsTranslation,
    required this.video,
    required this.open,
    required this.onListen,
    required this.onToggle,
  });

  final bool showsTranslation;
  final bool video;
  final bool open;
  final VoidCallback onListen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
    child: Row(
      children: [
        if (video)
          _Tool(
            icon: Icons.replay_rounded,
            label: 'reader_again'.tr(),
            onTap: onListen,
          )
        else
          _Tool(
            icon: Icons.volume_up_outlined,
            label: 'reader_listen'.tr(),
            semantics: 'reader_listen_sentence'.tr(),
            onTap: onListen,
          ),
        if (showsTranslation) ...[
          const SizedBox(width: AppSpacing.xs),
          _Tool(
            icon: Icons.translate_rounded,
            label: 'reader_translation'.tr(),
            selected: open,
            onTap: onToggle,
          ),
        ],
      ],
    ),
  );
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semantics,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String? semantics;
  final bool selected;
  final VoidCallback onTap;

  static const _height = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semantics ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: AppSizes.minTapTarget,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.resolve(context, AppMotion.quick),
              height: _height,
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.md,
                end: AppSpacing.md + AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: selected ? colors.primary.surface : colors.surface,
                borderRadius: BorderRadius.circular(_height / 2),
                border: Border.all(
                  color: selected
                      ? colors.primaryStrong
                      : context.scheme.outline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: AppSizes.iconSm, color: colors.textPrimary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: context.texts.captionStrong.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
