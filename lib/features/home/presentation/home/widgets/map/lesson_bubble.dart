import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/ai_spark.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:flutter/material.dart';

/// What the bubble says (bubble §2.4).
enum BubbleMode { next, first, resume, suggested, extra, reviewFirst, kids }

/// The bubble's mode for [state], first match: kids, the review first (back
/// after a while), the first day, a lesson left half done, a suggested one
/// (a track whose lessons are all open), today's goal already reached, and
/// otherwise the next lesson.
BubbleMode bubbleModeOf(HomeState state) {
  final home = state.home;
  if (home == null) return BubbleMode.next;
  if (home.kids) return BubbleMode.kids;
  if (HomeRules.reviewFirst(home)) return BubbleMode.reviewFirst;
  if (home.learner.lessonsDone == 0) return BubbleMode.first;
  if (_currentLesson(home)?.resume != null) return BubbleMode.resume;
  if (!home.enrollment.ordered) return BubbleMode.suggested;
  if (!home.v01 && state.status.kind == HomeStatusKind.goalReached) {
    return BubbleMode.extra;
  }
  return BubbleMode.next;
}

HomeLesson? _currentLesson(HomeSnapshot home) {
  final unit = home.currentUnit;
  if (unit == null) return null;
  final index = unit.currentLesson;
  return index < unit.lessons.length ? unit.lessons[index] : null;
}

/// The next lesson's card on the map, the one saturated block, its tail
/// towards the current stone (bubble §2): what the lesson is, where in the
/// unit, and «تابع»; for kids its picture, its English name and ▶. One
/// button: the label is the screen reader's, the drawing hidden.
///
/// Put it straight in the map's (or the island's) stack: it lays itself out
/// across [frame] and centred on [centerY] there. In a box of its own width
/// it just fills it.
class LessonBubble extends StatelessWidget {
  const LessonBubble({
    required this.mode,
    required this.home,
    required this.lesson,
    required this.frame,
    required this.centerY,
    required this.overrides,
    required this.onPressed,
    this.opacity = 1,
    super.key,
  });

  final BubbleMode mode;
  final HomeSnapshot home;

  /// The bubble's lesson; null with nothing to show (the review first needs
  /// none).
  final HomeLesson? lesson;

  /// Across the island and its tail (RTL frame space, D1).
  final BubbleFrame frame;

  /// Its vertical centre in the stack it is placed in.
  final double centerY;
  final MapOverrides overrides;
  final VoidCallback onPressed;

  /// The island's own fade of it while its rows move (09ب, `bubbleOpacity`).
  final double opacity;

  /// The design's heights for the bubble's gap.
  static const reserved = (normal: 170.0, partial: 182.0, kids: 148.0);

  /// The card's rect in the stack it lays itself out in, [stackWidth] wide
  /// (mirrored in English), [height] as [measure] gives it: where M4's
  /// container transform starts.
  static Rect rectIn({
    required BubbleFrame frame,
    required double centerY,
    required double height,
    required double stackWidth,
    required TextDirection direction,
  }) => Rect.fromLTWH(
    direction == TextDirection.rtl ? frame.x0 : stackWidth - frame.x1,
    centerY - height / 2,
    frame.width,
    height,
  );

  /// Its height at [width], for the island's gap: what it lays out to.
  ///
  /// ASSUMPTION(design): a taller bubble (two-line title, large text) widens
  /// its gap instead of covering the rows (D4, bubble A3).
  static double measure(
    BuildContext context, {
    required BubbleMode mode,
    required HomeLesson? lesson,
    required HomeSnapshot home,
    required double width,
  }) {
    final content = _Content.of(mode: mode, lesson: lesson, home: home);
    if (content == null) return 0;
    final styles = _Styles.of(context, content, width);
    final measure = _Measure(context);
    final inner = width - 2 * _Bubble.padX;
    if (content.kids) {
      final textWidth = inner - _Bubble.gap - _Bubble.picture;
      final column =
          measure.height(content.label, styles.kidLabel, textWidth, 1) +
          measure.height(
            content.title,
            styles.kidTitle,
            textWidth,
            _Bubble.titleLines,
            ltr: true,
          );
      return 2 * _Bubble.padY +
          math.max(_Bubble.picture, column) +
          _Bubble.ctaGap +
          _Bubble.kidCta;
    }
    final textWidth = inner - _Bubble.gap - _Bubble.disk;
    final column =
        measure.height(
          content.label,
          styles.label,
          textWidth,
          _Bubble.labelLines,
        ) +
        AppSpacing.xxs +
        measure.height(
          content.title,
          styles.title,
          textWidth,
          _Bubble.titleLines,
        ) +
        measure.height(
          content.meta,
          styles.meta,
          textWidth - (content.ai ? _Bubble.spark + AppSpacing.xs : 0),
          _Bubble.metaLines,
        );
    final question = content.question;
    final questionWidth = question == null
        ? 0.0
        : measure.width(question, styles.question) + AppSpacing.sm;
    final unitRow = math.max(
      measure.height(content.unitLine, styles.unit, inner - questionWidth, 1),
      question == null
          ? 0.0
          : measure.height(question, styles.question, inner, 1),
    );
    final padY = content.partial ? _Bubble.partialPadY : _Bubble.padY;
    return 2 * padY +
        math.max(_Bubble.disk, column) +
        AppSpacing.xxs +
        unitRow +
        (content.partial ? _Bubble.barGap + _Bubble.bar : 0) +
        _Bubble.ctaGap +
        _Bubble.cta;
  }

  @override
  Widget build(BuildContext context) {
    if (!overrides.bubbleVisible) return const SizedBox.shrink();
    final content = _Content.of(mode: mode, lesson: lesson, home: home);
    if (content == null) return const SizedBox.shrink();
    final bubble = _Bubble(
      content: content,
      frame: frame,
      overrides: overrides,
      opacity: opacity,
      onPressed: onPressed,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final inStack =
            constraints.hasBoundedWidth &&
            constraints.hasBoundedHeight &&
            constraints.maxWidth > frame.width + 1;
        final sized = SizedBox(width: frame.width, child: bubble);
        if (!inStack) return sized;
        return CustomSingleChildLayout(
          delegate: _Placement(
            x0: frame.x0,
            x1: frame.x1,
            centerY: centerY,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
          child: sized,
        );
      },
    );
  }
}

/// Lays the bubble at its frame across the stack (mirrored in English) and
/// centred on its y.
class _Placement extends SingleChildLayoutDelegate {
  const _Placement({
    required this.x0,
    required this.x1,
    required this.centerY,
    required this.rtl,
  });

  final double x0;
  final double x1;
  final double centerY;
  final bool rtl;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: x1 - x0);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(rtl ? x0 : size.width - x1, centerY - childSize.height / 2);

  @override
  bool shouldRelayout(_Placement oldDelegate) =>
      oldDelegate.x0 != x0 ||
      oldDelegate.x1 != x1 ||
      oldDelegate.centerY != centerY ||
      oldDelegate.rtl != rtl;
}

/// The bubble's words and marks for one mode.
final class _Content {
  const _Content({
    required this.kids,
    required this.label,
    required this.title,
    required this.meta,
    required this.unitLine,
    required this.cta,
    required this.semantics,
    required this.icon,
    this.ai = false,
    this.question,
    this.share = 0,
    this.partial = false,
    this.picture = '',
    this.lesson,
  });

  static _Content? of({
    required BubbleMode mode,
    required HomeLesson? lesson,
    required HomeSnapshot home,
  }) {
    if (mode == BubbleMode.kids) {
      if (lesson == null) return null;
      return _Content(
        kids: true,
        label: 'home_bubble_next'.tr(),
        title: lesson.title,
        meta: '',
        unitLine: '',
        cta: '',
        semantics: 'home_kid_bubble_semantics'.tr(args: [lesson.title]),
        icon: null,
        picture: lesson.base.imageUrl ?? '',
      );
    }
    final unit = home.currentUnit;
    final unitLine = unit == null
        ? ''
        : 'home_bubble_unit'.tr(
            namedArgs: {'number': '${unit.number}', 'name': unit.title},
          );
    if (mode == BubbleMode.reviewFirst) {
      final review = home.review;
      if (review == null) return null;
      final label = 'home_bubble_review'.tr();
      final title = 'home_review_title'.tr();
      final meta = reviewLine(review);
      final cta = 'home_review_action'.tr();
      return _Content(
        kids: false,
        label: label,
        title: title,
        meta: meta,
        unitLine: unitLine,
        cta: cta,
        semantics: 'home_bubble_semantics'.tr(
          namedArgs: {
            'label': label,
            'title': title,
            'meta': meta,
            'action': cta,
          },
        ),
        icon: AppIcon.reviewCycle,
      );
    }
    if (lesson == null) return null;
    final label = switch (mode) {
      BubbleMode.first => 'home_bubble_first'.tr(),
      BubbleMode.resume => 'home_bubble_resume'.tr(),
      BubbleMode.suggested => 'home_bubble_suggested'.tr(),
      BubbleMode.extra => 'home_bubble_extra'.tr(),
      _ => 'home_bubble_next'.tr(),
    };
    final cta = mode == BubbleMode.first
        ? 'unit_start'.tr()
        : 'unit_continue'.tr();
    final meta = lessonMeta(lesson);
    final page = lesson.page;
    final resume = lesson.resume;
    final questions = lesson.questions;
    return _Content(
      kids: false,
      label: label,
      title: lesson.title,
      meta: meta,
      unitLine: unit != null && page != null
          ? 'home_bubble_unit_page'.tr(
              namedArgs: {
                'number': '${unit.number}',
                'name': unit.title,
                'page': '$page',
              },
            )
          : unitLine,
      cta: cta,
      semantics: page != null
          ? 'home_bubble_semantics_page'.tr(
              namedArgs: {
                'label': label,
                'title': lesson.title,
                'meta': meta,
                'page': '$page',
                'action': cta,
              },
            )
          : 'home_bubble_semantics'.tr(
              namedArgs: {
                'label': label,
                'title': lesson.title,
                'meta': meta,
                'action': cta,
              },
            ),
      icon: null,
      ai: lesson.ai,
      partial: resume != null,
      question: resume != null && questions != null
          ? 'home_question_of'.tr(
              namedArgs: {'q': '${resume.question}', 'n': '$questions'},
            )
          : null,
      share: resume == null
          ? 0
          : questions != null && questions > 0
          ? resume.question / questions
          : resume.share,
      lesson: lesson,
    );
  }

  final bool kids;
  final String label;
  final String title;
  final String meta;
  final String unitLine;
  final String cta;
  final String semantics;

  /// The disk's icon when it isn't the lesson's kind (the review).
  final AppIcon? icon;
  final bool ai;

  /// «السؤال 3 من 6», when the lesson's questions are known.
  final String? question;

  /// How much of a lesson left half done is behind, for the thin bar.
  final double share;
  final bool partial;

  /// Kids: the lesson's picture.
  final String picture;

  /// The lesson whose kind the disk shows.
  final HomeLesson? lesson;
}

/// The bubble's text roles (bubble §2.3, §2.5): white on the strong blue.
final class _Styles {
  const _Styles({
    required this.label,
    required this.title,
    required this.meta,
    required this.unit,
    required this.question,
    required this.cta,
    required this.kidLabel,
    required this.kidTitle,
  });

  /// The roles for [content] in a bubble [width] wide. The label and the
  /// meta keep the design's line on one line, so the design's 170 holds the
  /// bubble, and the running floor where large text wraps them.
  factory _Styles.of(BuildContext context, _Content content, double width) {
    final texts = context.texts;
    final colors = context.colors;
    final white = colors.onPrimaryStrong;
    final soft = white.withValues(alpha: .9);
    final textWidth = width - 2 * _Bubble.padX - _Bubble.gap - _Bubble.disk;
    TextStyle fitted(String text, double size, double line, double width) =>
        texts
            .sizedFor(
              context,
              texts.caption,
              text: text,
              width: width,
              size: size,
              line: line,
            )
            .copyWith(color: soft);

    return _Styles(
      label: fitted(content.label, 13, 18, textWidth),
      title: texts
          .sized(texts.title, size: 20, line: 26, running: false)
          .copyWith(color: white),
      meta: fitted(
        content.meta,
        13,
        20,
        textWidth - (content.ai ? _Bubble.spark + AppSpacing.xs : 0),
      ),
      unit: texts
          .sized(texts.caption, size: 12, line: 16, running: false)
          .copyWith(color: soft),
      question: texts
          .sized(texts.captionStrong, size: 12, line: 16, running: false)
          .copyWith(color: white),
      cta: texts
          .sized(texts.button, size: 16, line: 16, running: false)
          .copyWith(color: colors.primaryStrong),
      kidLabel: texts
          .sized(texts.caption, size: 15, line: 20, running: false)
          .copyWith(color: white.withValues(alpha: .92)),
      kidTitle: texts
          .sized(texts.kidsWord, size: 26, line: 34, running: false)
          .copyWith(color: white),
    );
  }

  final TextStyle label;
  final TextStyle title;
  final TextStyle meta;
  final TextStyle unit;
  final TextStyle question;
  final TextStyle cta;
  final TextStyle kidLabel;
  final TextStyle kidTitle;
}

/// Lays text out as a [Text] in the same place would.
final class _Measure {
  _Measure(BuildContext context)
    : _direction = Directionality.of(context),
      _scaler = MediaQuery.textScalerOf(context),
      _locale = Localizations.maybeLocaleOf(context),
      _base = DefaultTextStyle.of(context).style,
      _heights = DefaultTextHeightBehavior.maybeOf(context);

  final TextDirection _direction;
  final TextScaler _scaler;
  final Locale? _locale;
  final TextStyle _base;
  final TextHeightBehavior? _heights;

  TextPainter _lay(
    String text,
    TextStyle style,
    double width,
    int? lines, {
    bool ltr = false,
  }) => TextPainter(
    text: TextSpan(text: text, style: _base.merge(style)),
    textDirection: ltr ? TextDirection.ltr : _direction,
    textScaler: _scaler,
    maxLines: lines,
    ellipsis: lines == null ? null : '…',
    locale: _locale,
    textHeightBehavior: _heights,
  )..layout(maxWidth: math.max(0, width));

  double height(
    String text,
    TextStyle style,
    double width,
    int lines, {
    bool ltr = false,
  }) {
    final painter = _lay(text, style, width, lines, ltr: ltr);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double width(String text, TextStyle style) {
    final painter = _lay(text, style, double.infinity, 1);
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// The card itself: the fill, its four tails (one shown), the content.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.content,
    required this.frame,
    required this.overrides,
    required this.opacity,
    required this.onPressed,
  });

  final _Content content;
  final BubbleFrame frame;
  final MapOverrides overrides;
  final double opacity;
  final VoidCallback onPressed;

  static const padX = 14.0;
  static const padY = 12.0;
  static const partialPadY = 10.0;
  static const gap = 12.0;
  static const disk = 44.0;
  static const spark = 12.0;
  static const picture = 56.0;
  static const kidPicture = 46.0;
  static const ctaGap = 10.0;
  static const cta = 52.0;
  static const kidCta = 56.0;
  static const barGap = 6.0;
  static const bar = 4.0;
  static const labelLines = 2;
  static const titleLines = 2;
  static const metaLines = 2;
  static const radius = 24.0;
  static const tail = 18.0;

  /// The pop's keyframes (M1, M6): .85 → 1.02 at .7 → 1, opacity in by .7.
  static const _popPeak = 1.02;
  static const _popAt = .7;

  static ({double scale, double opacity}) _pop(double t) {
    if (t >= 1) return (scale: 1, opacity: 1);
    final e = AppMotion.homePop.transform(t.clamp(0.0, 1.0));
    if (e <= _popAt) {
      final k = e / _popAt;
      return (
        scale: lerpDouble(AppMotion.homeBubbleFrom, _popPeak, k)!,
        opacity: k,
      );
    }
    return (
      scale: lerpDouble(_popPeak, 1, (e - _popAt) / (1 - _popAt))!,
      opacity: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final styles = _Styles.of(context, content, frame.width);
    final pop = _pop(overrides.bubbleIn);
    final scale = overrides.bubbleScale;
    final faded = (scale < .95 ? .85 : 1.0) * opacity * pop.opacity;
    final fill = colors.primaryStrong;
    final slide = overrides.tail != null
        ? Duration.zero
        : AppMotion.resolve(context, AppMotion.homeTail);
    final fade = AppMotion.resolve(context, AppMotion.homeTailSide);
    Widget tailAt(TailSide side) => AnimatedOpacity(
      opacity: frame.side == side ? 1 : 0,
      duration: fade,
      curve: AppMotion.out,
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: tail,
          height: tail,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
    final padY = content.partial && !content.kids ? partialPadY : _Bubble.padY;
    return Opacity(
      opacity: faded.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale * pop.scale,
        child: Semantics(
          button: true,
          label: content.semantics,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: ExcludeSemantics(
              child: PressScale(
                scale: AppMotion.scaleSmall,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Physical left in right-to-left is the end: the tails
                    // mirror with the bubble in English.
                    AnimatedPositionedDirectional(
                      duration: slide,
                      curve: AppMotion.homeEmphasis,
                      top: -tail / 2,
                      end: frame.tailX,
                      child: tailAt(TailSide.top),
                    ),
                    AnimatedPositionedDirectional(
                      duration: slide,
                      curve: AppMotion.homeEmphasis,
                      bottom: -tail / 2,
                      end: frame.tailX,
                      child: tailAt(TailSide.bottom),
                    ),
                    PositionedDirectional(
                      top: 0,
                      bottom: 0,
                      end: -tail / 2,
                      child: Center(child: tailAt(TailSide.left)),
                    ),
                    PositionedDirectional(
                      top: 0,
                      bottom: 0,
                      start: -tail / 2,
                      child: Center(child: tailAt(TailSide.right)),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(
                          content.kids ? kidRadius : radius,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: padX,
                          vertical: padY,
                        ),
                        child: content.kids
                            ? _kidContent(context, styles)
                            : _content(context, styles),
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

  Widget _content(BuildContext context, _Styles styles) {
    final colors = context.colors;
    final white = colors.onPrimaryStrong;
    final lesson = content.lesson;
    final question = content.question;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: overrides.bubbleContent.clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.label,
                          style: styles.label,
                          maxLines: labelLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          content.title,
                          style: styles.title,
                          maxLines: titleLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (content.ai) ...[
                              AiSpark(size: spark, color: styles.meta.color),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            Flexible(
                              child: Text(
                                content.meta,
                                style: styles.meta,
                                maxLines: metaLines,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: gap),
                  Container(
                    width: disk,
                    height: disk,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: white.withValues(alpha: .15),
                    ),
                    alignment: Alignment.center,
                    child: lesson != null
                        ? kindIcon(lesson, color: white, size: AppSizes.iconMd)
                        : AppIconView(
                            content.icon ?? AppIcon.lessonInteractiveText,
                            color: white,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      content.unitLine,
                      style: styles.unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (question != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(question, style: styles.question, maxLines: 1),
                  ],
                ],
              ),
              if (content.partial) ...[
                const SizedBox(height: barGap),
                ClipRRect(
                  borderRadius: BorderRadius.circular(bar / 2),
                  child: SizedBox(
                    height: bar,
                    child: ColoredBox(
                      color: white.withValues(alpha: .3),
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: content.share.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(bar / 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ctaGap),
        Container(
          height: cta,
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(cta / 2),
          ),
          alignment: Alignment.center,
          child: Text(content.cta, style: styles.cta, maxLines: 1),
        ),
      ],
    );
  }

  Widget _kidContent(BuildContext context, _Styles styles) {
    final colors = context.colors;
    final white = colors.onPrimaryStrong;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: overrides.bubbleContent.clamp(0.0, 1.0),
          child: Row(
            children: [
              ClipOval(
                child: Container(
                  width: picture,
                  height: picture,
                  color: colors.primary.surface,
                  alignment: Alignment.center,
                  child: KidPicture(url: content.picture, size: kidPicture),
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.label,
                      style: styles.kidLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      content.title,
                      style: styles.kidTitle,
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ctaGap),
        Container(
          height: kidCta,
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(kidCta / 2),
          ),
          alignment: Alignment.center,
          // A media glyph: never mirrored.
          child: Icon(
            Icons.play_arrow_rounded,
            size: 28,
            color: colors.primaryStrong,
          ),
        ),
      ],
    );
  }
}
