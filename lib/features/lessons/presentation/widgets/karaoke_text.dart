import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// One playing of a sound: its [length], and an [id] so the same sound played
/// again starts its marks over.
final class SoundRun extends Equatable {
  const SoundRun(this.id, this.length);

  final int id;
  final Duration length;

  @override
  List<Object?> get props => [id, length];
}

/// English words in a row, and a mark sliding along them as a sound of [run]'s
/// length says them, as in the reader. [saidAt] tells which word is said a
/// moment into it. The sound's own time leads, as it isn't motion: reduce motion
/// only stops the mark sliding.
class KaraokeText extends StatefulWidget {
  const KaraokeText({
    required this.count,
    required this.word,
    required this.saidAt,
    required this.spacing,
    this.run,
    this.alignment = WrapAlignment.start,
    this.runSpacing = 0,
    super.key,
  });

  final int count;
  final Widget Function(BuildContext context, int index) word;
  final int? Function(Duration elapsed, Duration length) saidAt;
  final double spacing;
  final SoundRun? run;
  final WrapAlignment alignment;
  final double runSpacing;

  @override
  State<KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<KaraokeText>
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
  void didUpdateWidget(KaraokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.run != widget.run) _start();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _start() {
    final run = widget.run;
    if (run == null) {
      _clock.stop();
      if (_said != null || _mark != null) {
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
    final said = widget.saidAt(run.length * _clock.value, run.length);
    if (said == _said) return;
    _said = said;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final said = _said;
    final stage = _stage.currentContext?.findRenderObject();
    final word = said == null
        ? null
        : _keys[said]?.currentContext?.findRenderObject();
    setState(() {
      _mark = stage is RenderBox && word is RenderBox
          ? word.localToGlobal(Offset.zero, ancestor: stage) & word.size
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mark = _mark;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
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
                  color: context.colors.reader.karaokeBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.sm - 2),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: widget.alignment,
              spacing: widget.spacing,
              runSpacing: widget.runSpacing,
              children: [
                for (var i = 0; i < widget.count; i++)
                  KeyedSubtree(
                    key: _keys.putIfAbsent(i, GlobalKey.new),
                    child: widget.word(context, i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
