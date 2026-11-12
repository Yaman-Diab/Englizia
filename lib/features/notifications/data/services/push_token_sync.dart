import 'dart:async';

import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/notifications/notification_permission.dart';
import 'package:englizia/core/notifications/push_channel.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/notifications/domain/repositories/push_token_repository.dart';

/// Keeps the server told where this account's notifications go: once an
/// account is on the phone and the phone allows notifications, and again
/// when the address changes or another account signs in.
final class PushTokenSync {
  PushTokenSync(
    this._channel,
    this._tokens,
    this._session,
    this._permission,
    this._storage,
  );

  final PushChannel _channel;
  final PushTokenRepository _tokens;
  final AppSessionController _session;
  final NotificationPermission _permission;
  final SettingsStorageService _storage;
  StreamSubscription<String>? _changes;
  Future<void>? _running;

  void start() {
    _session.addListener(_onSession);
    _changes ??= _channel.tokenChanges.listen((token) => _send(token));
    unawaited(sync());
  }

  void _onSession() => unawaited(sync());

  /// Sends the address if the server hasn't it yet; one at a time.
  Future<void> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<void> _sync() async {
    if (!_session.hasSession) return;
    try {
      if (await _permission.status() != NotificationAccess.granted) return;
    } catch (error, stackTrace) {
      // No way to ask the phone (a test or desktop run): nothing to send.
      AppLogger.error(error, stackTrace, 'Reading the notification permission');
      return;
    }
    final token = await _channel.token();
    if (token == null || token == _storage.pushTokenSent) return;
    await _send(token);
  }

  Future<void> _send(String token) async {
    if (!_session.hasSession) return;
    switch (await _tokens.register(token)) {
      case Ok():
        await _storage.setPushTokenSent(token);
      case Err(:final failure):
        // Tried again on the next open, sign-in or allowance.
        AppLogger.info('Push token not sent: ${failure.runtimeType}');
    }
  }

  Future<void> dispose() async {
    _session.removeListener(_onSession);
    await _changes?.cancel();
  }
}
