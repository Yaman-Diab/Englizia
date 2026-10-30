import 'dart:async';

/// Ticks once a second until a moment, for waits counted down on a button
/// (too many sign-ins, resending a link). Cancel it when its owner closes.
final class WaitCountdown {
  WaitCountdown({DateTime Function()? now}) : now = now ?? DateTime.now;

  final DateTime Function() now;
  Timer? _timer;

  /// Calls [onTick] each second until [until], then [onEnd] once. Starting
  /// again replaces the wait under way.
  void start(
    DateTime until, {
    required void Function(DateTime now) onTick,
    required void Function(DateTime now) onEnd,
  }) {
    cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = now();
      if (current.isBefore(until)) {
        onTick(current);
      } else {
        cancel();
        onEnd(current);
      }
    });
  }

  void cancel() => _timer?.cancel();
}
