import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Holds a one-shot motion back until the learner can see it: [builder] gets
/// `false` while the child is out of sight, then `true` once [fraction] of its
/// height is inside the scroll view, and stays `true` from then on. A page
/// that builds its whole length at once (a `SingleChildScrollView`) would
/// otherwise play everything below the fold while nobody is looking, and the
/// learner would scroll down to motion that has already finished.
///
/// Outside a scroll view, or taller than the viewport, the child is treated as
/// seen at once, so a motion is never lost waiting for a moment that can't
/// come.
class WhenSeen extends StatefulWidget {
  const WhenSeen({
    required this.builder,
    this.fraction = defaultFraction,
    super.key,
  });

  /// Draws the child, animating once [seen] is true.
  final Widget Function(BuildContext context, bool seen) builder;

  /// How much of the child must be inside the viewport. The designs ask for
  /// a third of it ("Me v2", "Home Archipelago").
  final double fraction;
  static const defaultFraction = .35;

  @override
  State<WhenSeen> createState() => _WhenSeenState();
}

class _WhenSeenState extends State<WhenSeen> {
  var _seen = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seen) return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) {
      // Nothing scrolls it into sight, so it is already as seen as it gets.
      _position?.removeListener(_check);
      _position = null;
      _seen = true;
      return;
    }
    if (position == _position) return;
    _position?.removeListener(_check);
    _position = position;
    position.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_seen || !mounted) return;
    if (!_isSeen()) return;
    _position?.removeListener(_check);
    setState(() => _seen = true);
  }

  /// How much of the child the viewport shows, down its scrolling axis.
  bool _isSeen() {
    final position = _position;
    if (position == null || !position.hasViewportDimension) return true;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return false;
    final height = box.size.height;
    if (height <= 0) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return true;
    final extent = position.viewportDimension;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final shown = (top + height).clamp(0.0, extent) - top.clamp(0.0, extent);
    // A child taller than the viewport can never show [fraction] of itself.
    final wanted = (height * widget.fraction).clamp(0.0, extent);
    return shown >= wanted;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _seen);
}
