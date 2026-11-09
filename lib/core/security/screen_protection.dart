import 'dart:async';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps a lesson's video out of screenshots and recordings (ADR 18).
abstract interface class ScreenProtection {
  /// Keeps the screen out of screenshots, recordings and the recent apps'
  /// preview until the returned function is called. Each protected view
  /// holds it; the last one to let go lifts it. Android only: iOS can't
  /// stop a screenshot, and hides the video by [captured] instead.
  VoidCallback protect();

  /// Whether the screen is being recorded or mirrored now (iOS).
  bool get captured;

  /// [captured] as it changes.
  Stream<bool> get capturedChanges;
}

/// [ScreenProtection] through a small native channel each way, as for the
/// screen kept awake: `FLAG_SECURE` on Android (`MainActivity.kt`), and
/// `UIScreen.isCaptured` on iOS (`AppDelegate.swift`). Never fails its
/// caller: a platform that can't is simply unprotected.
final class PlatformScreenProtection implements ScreenProtection {
  PlatformScreenProtection({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  static const _secure = MethodChannel('englizia/screen_secure');
  static const _capture = EventChannel('englizia/screen_capture');

  final TargetPlatform _platform;
  var _holds = 0;
  var _captured = false;
  StreamSubscription<Object?>? _watch;

  /// The capture is watched only while a protected view listens; the
  /// platform sends where it stands as soon as it is watched.
  late final _changes = StreamController<bool>.broadcast(
    onListen: _watchCapture,
    onCancel: _stopWatching,
  );

  @override
  VoidCallback protect() {
    if (_holds++ == 0) _setSecure(true);
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (--_holds == 0) _setSecure(false);
    };
  }

  @override
  bool get captured => _captured;

  @override
  Stream<bool> get capturedChanges => _changes.stream;

  void _setSecure(bool on) {
    if (_platform != TargetPlatform.android) return;
    unawaited(
      _secure.invokeMethod<void>('set', on).catchError((Object error) {
        AppLogger.error(error, StackTrace.current, 'Protecting the screen');
      }),
    );
  }

  Future<void> _stopWatching() async {
    await _watch?.cancel();
    _watch = null;
  }

  void _watchCapture() {
    if (_watch != null || _platform != TargetPlatform.iOS) return;
    _watch = _capture.receiveBroadcastStream().listen(
      (value) {
        final captured = value == true;
        if (captured == _captured) return;
        _captured = captured;
        _changes.add(captured);
      },
      onError: (Object error) =>
          AppLogger.error(error, StackTrace.current, 'Watching screen capture'),
    );
  }
}

/// Protects nothing: tests, and where no protection is registered.
final class NoScreenProtection implements ScreenProtection {
  const NoScreenProtection();

  @override
  VoidCallback protect() => () {};

  @override
  bool get captured => false;

  @override
  Stream<bool> get capturedChanges => const Stream.empty();
}
