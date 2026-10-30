import 'dart:async';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';

/// Sends the answers kept on the phone whenever the app can, not only while a
/// lesson is open, so none waits for the learner to come back (S §21): when the
/// app opens with a session, and when the connection returns.
final class AnswersSync {
  AnswersSync(this._lessons, this._connectivity, this._session);

  final LessonRepository _lessons;
  final ConnectivityService _connectivity;
  final AppSessionController _session;
  StreamSubscription<bool>? _connection;
  bool _hadSession = false;

  void start() {
    _connection ??= _connectivity.onlineChanges.listen(
      (online) {
        if (online) _send();
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error(error, stackTrace, 'Connection changes unavailable');
      },
    );
    _session.addListener(_followSession);
    _followSession();
  }

  void stop() {
    unawaited(_connection?.cancel());
    _connection = null;
    _session.removeListener(_followSession);
  }

  void _followSession() {
    final hasSession = _session.hasSession;
    if (hasSession && !_hadSession) _send();
    _hadSession = hasSession;
  }

  void _send() {
    if (_session.hasSession) unawaited(_lessons.sendSaved());
  }
}
