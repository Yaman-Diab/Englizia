import 'package:flutter/services.dart';

/// Fullscreen turns the phone sideways and hides the system's bars: only a lesson's
/// video ever does.
Future<void> setVideoFullscreen({required bool fullscreen}) async {
  await SystemChrome.setPreferredOrientations(
    fullscreen
        ? const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : const [DeviceOrientation.portraitUp],
  );
  await SystemChrome.setEnabledSystemUIMode(
    fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
  );
}
