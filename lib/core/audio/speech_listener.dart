import 'dart:async';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Turns what the learner says into text, for a sentence to repeat. Only text
/// comes out: nothing is recorded or kept (S §7.5). Screens depend on this
/// interface, so the package and the engine change in one place (ADR 13).
abstract interface class SpeechListener {
  /// Listens until [silence] passes, [limit] is reached or [stop] is called,
  /// and returns what it understood: empty when it heard nothing, null when the
  /// phone can't do this at all. [onLevel] gets the microphone's level, 0 to 1.
  Future<String?> listen({
    required Duration silence,
    required Duration limit,
    required void Function(double level) onLevel,
  });

  /// Ends the listening now; what was heard so far still counts.
  Future<void> stop();
}

/// On the phone's own speech engine.
final class DeviceSpeechListener implements SpeechListener {
  final _speech = SpeechToText();
  Completer<String?>? _done;
  String _words = '';

  /// English sentences, whatever the app's or the phone's language.
  static const _locale = 'en_US';

  /// The engines report roughly -2 to 10.
  static const _quietest = -2.0;
  static const _loudest = 10.0;

  @override
  Future<String?> listen({
    required Duration silence,
    required Duration limit,
    required void Function(double level) onLevel,
  }) async {
    final done = _done = Completer<String?>();
    _words = '';
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus) _finish();
        },
        onError: (error) {
          AppLogger.info('Speech ended: ${error.errorMsg}');
          _finish();
        },
      );
      if (!ready) {
        _done = null;
        return null;
      }
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: (level) => onLevel(
          ((level - _quietest) / (_loudest - _quietest)).clamp(0.0, 1.0),
        ),
        listenOptions: SpeechListenOptions(
          listenFor: limit,
          pauseFor: silence,
          localeId: _locale,
          listenMode: ListenMode.dictation,
          autoPunctuation: false,
          cancelOnError: true,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Speech recognition failed');
      _done = null;
      return null;
    }
    return done.future;
  }

  void _onResult(SpeechRecognitionResult result) {
    _words = result.recognizedWords;
    if (result.finalResult) _finish();
  }

  void _finish() {
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete(_words);
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    _finish();
  }
}
