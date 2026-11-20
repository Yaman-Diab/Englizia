import 'dart:async';
import 'dart:math';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';

/// Sends the answers kept on the phone whenever the app can, not only while a
/// lesson is open, so none waits for the learner to come back (S §21): when the
/// app opens with a session, when the connection returns, and every few
/// minutes while it is in use. A send that failed is tried again by itself,
/// after longer and longer (docs/api/lessons.md).
final class AnswersSync {
  AnswersSync(
    this._lessons,
    this._connectivity,
    this._session, {
    Random? random,
  }) : _random = random ?? Random();

  /// How often what the phone kept is sent while the app is in use.
  static const every = Duration(minutes: 3);

  /// The wait after a first failure. It doubles with each one after it.
  static const firstWait = Duration(seconds: 2);

  /// The longest wait between two tries.
  static const longestWait = Duration(minutes: 5);

  final LessonRepository _lessons;
  final ConnectivityService _connectivity;
  final AppSessionController _session;
  final Random _random;
  StreamSubscription<bool>? _connection;
  Timer? _regular;
  Timer? _retry;
  bool _hadSession = false;
  bool _sending = false;
  int _failures = 0;

  void start() {
    _connection ??= _connectivity.onlineChanges.listen(
      (online) {
        if (online) _send();
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error(error, stackTrace, 'Connection changes unavailable');
      },
    );
    _regular ??= Timer.periodic(every, (_) => _send());
    _session.addListener(_followSession);
    _followSession();
  }

  void stop() {
    unawaited(_connection?.cancel());
    _connection = null;
    _regular?.cancel();
    _regular = null;
    _retry?.cancel();
    _retry = null;
    _session.removeListener(_followSession);
  }

  void _followSession() {
    final hasSession = _session.hasSession;
    if (hasSession && !_hadSession) {
      _failures = 0;
      _send();
    }
    _hadSession = hasSession;
  }

  /// One send at a time: a second asked for meanwhile would find the same
  /// answers on their way.
  void _send() {
    if (!_session.hasSession || _sending) return;
    _retry?.cancel();
    _retry = null;
    _sending = true;
    unawaited(_sendNow());
  }

  Future<void> _sendNow() async {
    final SendOutcome outcome;
    try {
      outcome = await _lessons.sendSaved();
    } finally {
      _sending = false;
    }
    if (!outcome.waiting) {
      _failures = 0;
      return;
    }
    // Stopped while it was on its way.
    if (_regular == null) return;
    _retry = Timer(outcome.retryAfter ?? _nextWait(), _send);
    _failures++;
  }

  /// 2, 4, 8, 16… seconds, up to [longestWait], and somewhere in the second
  /// half of it, so phones that failed together don't come back together.
  Duration _nextWait() {
    final step = firstWait * pow(2, _failures.clamp(0, 16)).toInt();
    final wait = step > longestWait ? longestWait : step;
    return wait * (.5 + _random.nextDouble() / 2);
  }
}
