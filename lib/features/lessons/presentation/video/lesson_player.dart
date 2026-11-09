import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/timed_value.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/core/security/protected_video.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/presentation/grammar/widgets/option_sheet.dart';
import 'package:englizia/features/lessons/presentation/video/player_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The app's direction, as the player itself is always left to right.
TextDirection _appDirection(BuildContext context) =>
    context.locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

/// `1`, `0.75`.
String _speedText(double speed) =>
    speed == speed.truncateToDouble() ? '${speed.toInt()}' : '$speed';

/// `2:14`.
String videoTime(Duration time) {
  final seconds = time.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// A lesson's player, black in any theme, its controls left to right in any app
/// language as Material recommends (designs "Grammar Video", "Interactive Video").
/// They hide 3 seconds into playing and a thin line stays; a double tap on a side
/// skips 10 seconds.
class LessonPlayer extends StatefulWidget {
  const LessonPlayer({
    required this.state,
    required this.actions,
    required this.fullscreen,
    required this.onToggleFullscreen,
    this.titleInFullscreen = true,
    this.onSettings,
    this.held = false,
    super.key,
  });

  final PlayerState state;
  final PlayerActions actions;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final bool titleInFullscreen;

  /// `Aa` among its buttons, for how a text beside it shows.
  final VoidCallback? onSettings;

  /// Something else stopped it, and it says so over the picture.
  final bool held;

  @override
  State<LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends State<LessonPlayer> {
  static const _hideAfter = Duration(seconds: 3);

  PlayerActions get _actions => widget.actions;
  late final Widget _picture = _actions.engine.view();
  bool _controls = true;
  Timer? _hide;
  bool _rippleStart = true;
  var _ripples = 0;

  @override
  void didUpdateWidget(LessonPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.held && widget.held) {
      _hideControls();
    } else if (oldWidget.state.playing != widget.state.playing) {
      _showControls();
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _hideControls() {
    _hide?.cancel();
    setState(() => _controls = false);
  }

  void _showControls() {
    _hide?.cancel();
    setState(() => _controls = true);
    if (widget.state.playing) {
      _hide = Timer(_hideAfter, () {
        if (mounted && widget.state.playing) {
          setState(() => _controls = false);
        }
      });
    }
  }

  void _tap() {
    if (_controls) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _doubleTap(double x, double width) {
    final back = x < width / 2;
    unawaited(back ? _actions.skipBack() : _actions.skipForward());
    setState(() {
      _rippleStart = back;
      _ripples++;
    });
  }

  Future<void> _pickSpeed() async {
    _hide?.cancel();
    final current = widget.state.speed;
    final speed = await showOptionSheet<double>(
      context,
      title: 'lesson_gv_speed_title'.tr(),
      selected: current,
      options: [
        for (final value in _actions.speeds)
          SheetOption(
            value: value,
            label: value == 1
                ? 'lesson_gv_speed_normal'.tr(
                    namedArgs: {'speed': _speedText(value)},
                  )
                : 'lesson_gv_speed'.tr(namedArgs: {'speed': _speedText(value)}),
          ),
      ],
    );
    if (speed != null) await _actions.setSpeed(speed);
    if (mounted) _showControls();
  }

  Future<void> _pickQuality() async {
    _hide?.cancel();
    final sources = widget.state.video?.sources ?? const <VideoSource>[];
    final quality = await showOptionSheet<VideoQuality>(
      context,
      title: 'lesson_gv_quality_title'.tr(),
      selected: widget.state.quality,
      options: [
        for (final source in sources)
          SheetOption(
            value: source.quality,
            label: switch (source.quality) {
              VideoQuality.auto => 'lesson_gv_quality_auto'.tr(),
              VideoQuality.low => 'lesson_gv_quality_low'.tr(),
              VideoQuality.medium => 'lesson_gv_quality_medium'.tr(),
              VideoQuality.high => 'lesson_gv_quality_high'.tr(),
            },
            detail: source.quality == VideoQuality.auto
                ? 'lesson_gv_quality_auto_detail'.tr()
                : source.sizeMb == null
                ? null
                : 'lesson_gv_quality_size'.tr(
                    namedArgs: {'size': '${source.sizeMb}'},
                  ),
          ),
      ],
    );
    if (quality != null) await _actions.setQuality(quality);
    if (mounted) _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final media = MediaQuery.of(context);
    return MediaQuery(
      // The app's text grows with the screen's width, and only this screen
      // ever turns sideways.
      data: widget.fullscreen
          ? media.copyWith(textScaler: TextScaler.linear(1 / 1.sp))
          : media,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: context.colors.reader.videoBackground,
          child: switch (state.stage) {
            VideoStage.cover => _Cover(state: state, actions: _actions),
            VideoStage.failed => _Failed(onRetry: _actions.retry),
            VideoStage.playing => ProtectedVideo(
              onCaptured: () => unawaited(_actions.engine.pause()),
              child: _frame(state),
            ),
          },
        ),
      ),
    );
  }

  Widget _frame(PlayerState state) {
    final reader = context.colors.reader;
    final caption = state.caption;
    final big = widget.fullscreen;
    final buffering = state.buffering;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        fit: StackFit.expand,
        children: [
          _picture,
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            onDoubleTapDown: (details) =>
                _doubleTap(details.localPosition.dx, box.maxWidth),
            onDoubleTap: () {},
          ),
          if (_ripples > 0)
            _Ripple(
              key: ValueKey(_ripples),
              atStart: _rippleStart,
              width: box.maxWidth * .4,
            ),
          AnimatedOpacity(
            opacity: _controls ? 1 : 0,
            duration: AppMotion.resolve(context, AppMotion.closeUp),
            child: IgnorePointer(
              ignoring: !_controls,
              child: _Controls(
                state: state,
                actions: _actions,
                fullscreen: big,
                showsTitle: big && widget.titleInFullscreen,
                onSettings: widget.onSettings,
                onTap: _tap,
                onActivity: _showControls,
                onSpeed: _pickSpeed,
                onQuality: _pickQuality,
                onFullscreen: widget.onToggleFullscreen,
              ),
            ),
          ),
          if (caption != null)
            AnimatedPositionedDirectional(
              duration: AppMotion.resolve(context, AppMotion.closeUp),
              curve: AppMotion.out,
              start: AppSpacing.md,
              end: AppSpacing.md,
              bottom: _controls
                  ? (big ? _Controls.tallFullscreen : _Controls.tall)
                  : AppSpacing.md,
              child: IgnorePointer(
                child: _Caption(text: caption, big: big),
              ),
            ),
          if (buffering)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSpinner(size: AppSizes.iconLg + 8, color: reader.onVideo),
                  if (state.slowConnection) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SlowNote(onLower: _actions.lowerQuality),
                  ],
                ],
              ),
            ),
          if (widget.held) const Center(child: _HeldBadge()),
          if (!_controls)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              height: 2,
              child: _Line(state: state),
            ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text, required this.big});

  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: reader.captionBackground,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          child: Text(
            text,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: (big ? context.texts.title : context.texts.bodyStrong)
                .copyWith(color: reader.captionArabic),
          ),
        ),
      ),
    );
  }
}

/// A double tap's answer: a soft arc on that side, gone in a moment.
class _Ripple extends StatelessWidget {
  const _Ripple({required this.atStart, required this.width, super.key});

  final bool atStart;
  final double width;

  static const _peakAt = .3;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    final round = Radius.elliptical(width / 2, 400);
    return PositionedDirectional(
      top: 0,
      bottom: 0,
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      width: width,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: TimedValue(
            delay: Duration.zero,
            duration: AppMotion.pairWrongHold,
            builder: (_, value) => Opacity(
              opacity: value < _peakAt
                  ? value / _peakAt
                  : 1 - (value - _peakAt) / (1 - _peakAt),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: reader.videoRipple,
                  borderRadius: BorderRadiusDirectional.only(
                    topEnd: atStart ? round : Radius.zero,
                    bottomEnd: atStart ? round : Radius.zero,
                    topStart: atStart ? Radius.zero : round,
                    bottomStart: atStart ? Radius.zero : round,
                  ),
                ),
                child: Center(
                  child: Icon(
                    atStart
                        ? Icons.replay_10_rounded
                        : Icons.forward_10_rounded,
                    size: AppSizes.iconLg,
                    color: reader.onVideo,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Said over the picture while a word's card has stopped the video.
class _HeldBadge extends StatelessWidget {
  const _HeldBadge();

  static const _size = 56.0;
  static const _dim = .45;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: context.colors.reader.videoBackground.withValues(alpha: _dim),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.pause_rounded,
          size: AppSizes.iconLg,
          color: context.colors.reader.onVideo,
        ),
      ),
    ),
  );
}

class _SlowNote extends StatelessWidget {
  const _SlowNote({required this.onLower});

  final VoidCallback onLower;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    return Directionality(
      textDirection: _appDirection(context),
      child: Container(
        height: _height,
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          end: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: reader.videoChip,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'lesson_gv_slow'.tr(),
              style: context.texts.caption.copyWith(color: reader.onVideo),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onLower,
              style: TextButton.styleFrom(
                foregroundColor: reader.videoBackground,
                backgroundColor: reader.onVideo,
                minimumSize: const Size(0, AppSpacing.xxl),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                ),
              ),
              child: Text('lesson_gv_lower_quality'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.actions,
    required this.fullscreen,
    required this.showsTitle,
    required this.onSettings,
    required this.onTap,
    required this.onActivity,
    required this.onSpeed,
    required this.onQuality,
    required this.onFullscreen,
  });

  final PlayerState state;
  final PlayerActions actions;
  final bool fullscreen;
  final bool showsTitle;
  final VoidCallback? onSettings;
  final VoidCallback onTap;

  /// Something was pressed: stay a while longer.
  final VoidCallback onActivity;
  final VoidCallback onSpeed;
  final VoidCallback onQuality;
  final VoidCallback onFullscreen;

  /// How far above the bottom a caption rises while they show.
  static const tall = 68.0;
  static const tallFullscreen = 92.0;
  static const _skip = AppSizes.minTapTarget;
  static const _main = 56.0;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    final title = state.lessonTitle;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ColoredBox(color: reader.videoDim),
        ),
        if (showsTitle && title != null)
          PositionedDirectional(
            top: AppSpacing.md,
            start: AppSpacing.xl,
            end: AppSpacing.xl,
            child: Text(
              title,
              textDirection: TextDirection.rtl,
              style: context.texts.bodyStrong.copyWith(color: reader.onVideo),
            ),
          ),
        // The spinner takes this place while it loads.
        if (!state.buffering)
          Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xxl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundButton(
                    size: _skip,
                    icon: Icons.replay_10_rounded,
                    tooltip: 'lesson_gv_back10'.tr(),
                    onTap: () {
                      unawaited(actions.skipBack());
                      onActivity();
                    },
                  ),
                  SizedBox(width: fullscreen ? AppSpacing.xxl : AppSpacing.xl),
                  _RoundButton(
                    size: _main,
                    filled: true,
                    icon: state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: state.playing
                        ? 'lesson_gv_pause'.tr()
                        : 'lesson_gv_play'.tr(),
                    onTap: actions.togglePlay,
                  ),
                  SizedBox(width: fullscreen ? AppSpacing.xxl : AppSpacing.xl),
                  _RoundButton(
                    size: _skip,
                    icon: Icons.forward_10_rounded,
                    tooltip: 'lesson_gv_forward10'.tr(),
                    onTap: () {
                      unawaited(actions.skipForward());
                      onActivity();
                    },
                  ),
                ],
              ),
            ),
          ),
        PositionedDirectional(
          start: fullscreen ? AppSpacing.xl : AppSpacing.md,
          end: fullscreen ? AppSpacing.xl : AppSpacing.md,
          bottom: AppSpacing.xxs,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SeekBar(state: state, onSeek: actions.seekTo),
              _BottomRow(
                state: state,
                fullscreen: fullscreen,
                onCaptions: actions.toggleCaptions,
                onSpeed: onSpeed,
                onQuality: onQuality,
                onSettings: onSettings,
                onFullscreen: onFullscreen,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
  });

  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    return PressScale(
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        color: reader.onVideo,
        iconSize: size * .6,
        style: IconButton.styleFrom(
          backgroundColor: filled ? reader.videoTrack : null,
          fixedSize: Size.square(size),
          padding: EdgeInsetsDirectional.zero,
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.state,
    required this.fullscreen,
    required this.onCaptions,
    required this.onSpeed,
    required this.onQuality,
    required this.onSettings,
    required this.onFullscreen,
  });

  final PlayerState state;
  final bool fullscreen;
  final VoidCallback onCaptions;
  final VoidCallback onSpeed;
  final VoidCallback onQuality;
  final VoidCallback? onSettings;
  final VoidCallback onFullscreen;

  static const _height = 36.0;
  static const _buttonWidth = 40.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    final texts = context.texts;
    final on = reader.onVideo;
    Widget button({
      required String label,
      required VoidCallback onTap,
      required Widget child,
      bool? pressed,
    }) => Semantics(
      button: true,
      label: label,
      toggled: pressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _buttonWidth,
          height: _height,
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    );
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${videoTime(state.position)} / ${videoTime(state.duration)}',
              style: texts.captionStrong.copyWith(
                color: on,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (state.video?.captions.isNotEmpty ?? false)
            button(
              label: state.captions
                  ? 'lesson_gv_captions_on'.tr()
                  : 'lesson_gv_captions_off'.tr(),
              pressed: state.captions,
              onTap: onCaptions,
              child: Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: state.captions ? on : null,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  border: Border.all(color: on, width: 1.5),
                ),
                child: Text(
                  'lesson_gv_captions_badge'.tr(),
                  style: texts.captionStrong.copyWith(
                    color: state.captions ? reader.videoBackground : on,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          button(
            label: 'lesson_gv_speed_now'.tr(
              namedArgs: {'speed': _speedText(state.speed)},
            ),
            onTap: onSpeed,
            child: Text(
              '${_speedText(state.speed)}×',
              style: texts.captionStrong.copyWith(color: on),
            ),
          ),
          button(
            label: 'lesson_gv_quality_title'.tr(),
            onTap: onQuality,
            child: Icon(Icons.settings_outlined, size: _iconSize, color: on),
          ),
          if (onSettings case final onSettings?)
            button(
              label: 'reader_mode_title'.tr(),
              onTap: onSettings,
              child: Text(
                'reader_size_sample'.tr(),
                style: texts.captionStrong.copyWith(color: on),
              ),
            ),
          button(
            label: fullscreen
                ? 'lesson_gv_fullscreen_exit'.tr()
                : 'lesson_gv_fullscreen'.tr(),
            onTap: onFullscreen,
            child: Icon(
              fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              size: _iconSize + AppSpacing.xs,
              color: on,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the video is, and how far it has loaded. Moving it is only looking:
/// watching is counted from what played.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.state, required this.onSeek});

  final PlayerState state;
  final ValueChanged<Duration> onSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  static const _height = 20.0;
  static const _knob = 14.0;
  static const _step = Duration(seconds: 10);

  double? _dragging;

  double _share(Duration time) {
    final total = widget.state.duration.inMilliseconds;
    return total == 0 ? 0 : (time.inMilliseconds / total).clamp(0, 1);
  }

  Duration _at(double share) => widget.state.duration * share;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reader = colors.reader;
    final state = widget.state;
    final shown = _dragging ?? _share(state.position);
    final thick = _dragging == null ? 4.0 : 6.0;
    return Semantics(
      slider: true,
      label: 'lesson_gv_position'.tr(),
      value: videoTime(state.position),
      increasedValue: videoTime(state.position + _step),
      decreasedValue: videoTime(
        state.position > _step ? state.position - _step : Duration.zero,
      ),
      onIncrease: () => widget.onSeek(state.position + _step),
      onDecrease: () => widget.onSeek(state.position - _step),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          double shareAt(double x) => (x / box.maxWidth).clamp(0, 1);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) =>
                widget.onSeek(_at(shareAt(details.localPosition.dx))),
            onHorizontalDragStart: (details) =>
                setState(() => _dragging = shareAt(details.localPosition.dx)),
            onHorizontalDragUpdate: (details) =>
                setState(() => _dragging = shareAt(details.localPosition.dx)),
            onHorizontalDragEnd: (_) {
              final share = _dragging;
              setState(() => _dragging = null);
              if (share != null) widget.onSeek(_at(share));
            },
            child: SizedBox(
              height: _height,
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                clipBehavior: Clip.none,
                children: [
                  _bar(box.maxWidth, thick, reader.videoTrack),
                  _bar(
                    box.maxWidth * _share(state.bufferedTo),
                    thick,
                    reader.videoBuffered,
                  ),
                  _bar(box.maxWidth * shown, thick, colors.primary.fill),
                  if (_dragging != null)
                    PositionedDirectional(
                      start: box.maxWidth * shown - _knob / 2,
                      child: Container(
                        width: _knob,
                        height: _knob,
                        decoration: BoxDecoration(
                          color: colors.primary.fill,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: reader.onVideo,
                            width: 3,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bar(double width, double height, Color color) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.state});

  final PlayerState state;

  @override
  Widget build(BuildContext context) {
    final total = state.duration.inMilliseconds;
    return ColoredBox(
      color: context.colors.reader.videoTrack,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          heightFactor: 1,
          widthFactor: total == 0
              ? 0
              : (state.position.inMilliseconds / total).clamp(0, 1),
          child: ColoredBox(color: context.colors.primary.fill),
        ),
      ),
    );
  }
}

/// Before it plays: the cover, the length, and nothing plays by itself. With a
/// place saved, the choice to carry on or start over.
class _Cover extends StatelessWidget {
  const _Cover({required this.state, required this.actions});

  final PlayerState state;
  final PlayerActions actions;

  static const _button = 64.0;
  static const _buttonIcon = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reader = colors.reader;
    final cover = state.video?.coverUrl;
    final resume = state.resumeFrom;
    final title = state.lessonTitle;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: reader.videoBoard,
          child: cover != null
              ? Image.network(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              : title == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.topCenter,
                    child: Text(
                      title,
                      textDirection: TextDirection.rtl,
                      style: context.texts.title.copyWith(
                        color: reader.onVideo,
                      ),
                    ),
                  ),
                ),
        ),
        Center(
          child: PressScale(
            child: Semantics(
              button: true,
              label: 'lesson_gv_play_video'.tr(),
              excludeSemantics: true,
              child: Material(
                color: reader.onVideo,
                shape: const CircleBorder(),
                elevation: AppSpacing.xs,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: actions.play,
                  child: SizedBox.square(
                    dimension: _button,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: _buttonIcon,
                      color: colors.primaryStrong,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (resume == null)
          PositionedDirectional(
            end: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: reader.videoChip,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                child: Text(
                  videoTime(state.duration),
                  style: context.texts.captionStrong.copyWith(
                    color: reader.onVideo,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          )
        else
          PositionedDirectional(
            start: AppSpacing.sm,
            end: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Directionality(
              textDirection: _appDirection(context),
              child: Container(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.md,
                  end: AppSpacing.xs,
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: reader.videoCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'lesson_gv_stopped_at'.tr(
                          namedArgs: {'time': videoTime(resume)},
                        ),
                        style: context.texts.captionStrong.copyWith(
                          color: reader.onVideo,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: actions.playFromStart,
                      style: TextButton.styleFrom(
                        foregroundColor: reader.onVideo,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                      ),
                      child: Text('lesson_gv_from_start'.tr()),
                    ),
                    TextButton(
                      onPressed: actions.play,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.primaryStrong,
                        backgroundColor: reader.onVideo,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                      ),
                      child: Text('lesson_gv_continue'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// «تعذّر تشغيل الفيديو»: the summary under it stays usable.
class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  static const _icon = 36.0;

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: _icon,
              color: reader.onVideo,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'lesson_gv_failed'.tr(),
              style: context.texts.captionStrong.copyWith(
                color: reader.onVideo,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: reader.onVideo,
                side: BorderSide(color: reader.videoBuffered, width: 1.5),
                minimumSize: const Size(0, AppSpacing.xxxl - AppSpacing.sm),
              ),
              child: Text('lesson_gv_retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
