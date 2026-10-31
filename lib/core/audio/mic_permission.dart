import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Where the microphone stands. [notAsked] may still show the system prompt;
/// [denied] can only be changed in the phone's settings.
enum MicAccess { granted, notAsked, denied }

/// The system permission to hear the learner, asked for once they have seen why
/// (S §7.5).
abstract interface class MicPermission {
  Future<MicAccess> status();

  /// Shows the system prompt; granted or denied from there.
  Future<MicAccess> request();

  /// Opens this app's page in the phone settings. False if it could not.
  Future<bool> openSettings();
}

final class PlatformMicPermission implements MicPermission {
  const PlatformMicPermission();

  /// iOS asks for speech recognition apart from the microphone.
  static bool get _needsSpeech => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<MicAccess> status() async {
    final microphone = await Permission.microphone.status;
    if (microphone.isPermanentlyDenied || microphone.isRestricted) {
      return MicAccess.denied;
    }
    if (!microphone.isGranted) return MicAccess.notAsked;
    if (!_needsSpeech) return MicAccess.granted;
    final speech = await Permission.speech.status;
    return speech.isGranted
        ? MicAccess.granted
        : speech.isPermanentlyDenied || speech.isRestricted
        ? MicAccess.denied
        : MicAccess.notAsked;
  }

  @override
  Future<MicAccess> request() async {
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) return MicAccess.denied;
    if (!_needsSpeech) return MicAccess.granted;
    final speech = await Permission.speech.request();
    return speech.isGranted ? MicAccess.granted : MicAccess.denied;
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}
