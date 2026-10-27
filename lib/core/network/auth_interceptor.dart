import 'package:dio/dio.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/token_storage.dart';

typedef RequestRetrier = Future<Response<Object?>> Function(RequestOptions);

/// Attaches the bearer token and keeps it valid: refreshes it shortly before
/// it expires, and recovers from a 401 anyway — one shared refresh for all
/// concurrent requests, one retry per request, and a session expiry only
/// when the server rejects the refresh token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokens,
    required TokenRefresher refresher,
    required RequestRetrier retry,
    required Future<void> Function() onSessionExpired,
    DateTime Function()? now,
  }) : _tokens = tokens,
       _refresher = refresher,
       _retry = retry,
       _onSessionExpired = onSessionExpired,
       _now = now ?? DateTime.now;

  /// Set `extra[skipAuthKey] = true` for public endpoints (login, register).
  static const skipAuthKey = 'auth.skip';
  static const _retriedKey = 'auth.retried';

  /// How long before the access token expires it is refreshed.
  static const refreshMargin = Duration(seconds: 30);

  final TokenStorage _tokens;
  final TokenRefresher _refresher;
  final RequestRetrier _retry;
  final Future<void> Function() _onSessionExpired;
  final DateTime Function() _now;

  Future<_RefreshOutcome>? _inFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      var tokens = await _tokens.read();
      if (tokens != null &&
          tokens.expiresSoon(_now().toUtc(), margin: refreshMargin)) {
        switch (await _refreshShared(tokens)) {
          case _Refreshed(tokens: final fresh):
            tokens = fresh;
          case _Rejected():
            await _onSessionExpired();
            tokens = null;
          case _Unavailable():
            // Send the current token; a 401 takes the usual recovery path.
            break;
        }
      }
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isRecoverable =
        err.response?.statusCode == ApiStatusCodes.unauthorized &&
        request.extra[skipAuthKey] != true &&
        request.extra[_retriedKey] != true;
    if (!isRecoverable) {
      handler.next(err);
      return;
    }

    final outcome = await _refreshOnce(request.headers['Authorization']);
    switch (outcome) {
      case _Refreshed(:final tokens):
        request
          ..headers['Authorization'] = 'Bearer ${tokens.accessToken}'
          ..extra[_retriedKey] = true;
        try {
          handler.resolve(await _retry(request));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      case _Rejected():
        await _onSessionExpired();
        handler.next(err);
      case _Unavailable():
        handler.next(err);
    }
  }

  /// Joins an in-flight refresh, or reuses tokens another request already
  /// rotated since this one was sent.
  Future<_RefreshOutcome> _refreshOnce(Object? sentAuthorization) async {
    final current = await _tokens.read();
    if (current == null) return const _Rejected();
    if (sentAuthorization != 'Bearer ${current.accessToken}') {
      return _Refreshed(current);
    }
    return _refreshShared(current);
  }

  Future<_RefreshOutcome> _refreshShared(AuthTokens current) =>
      _inFlight ??= _refresh(current).whenComplete(() => _inFlight = null);

  Future<_RefreshOutcome> _refresh(AuthTokens current) async {
    try {
      final next = await _refresher.refresh(current);
      await _tokens.write(next);
      return _Refreshed(next);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // Signing out is irreversible for the user, so only a definitive
      // rejection of the refresh token ends the session. A 5xx/429 or no
      // response says nothing about the token; the next refresh retries.
      // The server answers an invalid, expired or revoked refresh token with
      // 401 `auth.refresh_token_invalid`; 400 and 403 are its other refusals
      // (docs/api/openapi.json).
      if (status == ApiStatusCodes.badRequest ||
          status == ApiStatusCodes.unauthorized ||
          status == ApiStatusCodes.forbidden) {
        AppLogger.info('Refresh rejected: $status');
        return const _Rejected();
      }
      AppLogger.warning('Refresh unavailable', status ?? error.type.name);
      return const _Unavailable();
    } catch (error, stackTrace) {
      // A malformed refresh response is a server/contract bug, not proof
      // the token is revoked: keep the session, fail the request.
      AppLogger.error(error, stackTrace, 'Refresh failed');
      return const _Unavailable();
    }
  }
}

sealed class _RefreshOutcome {
  const _RefreshOutcome();
}

final class _Refreshed extends _RefreshOutcome {
  const _Refreshed(this.tokens);

  final AuthTokens tokens;
}

/// The server refused the refresh token: the session is over.
final class _Rejected extends _RefreshOutcome {
  const _Rejected();
}

/// No usable answer (offline, timeout, 5xx, malformed response): keep the
/// session, surface the error; a later request refreshes again.
final class _Unavailable extends _RefreshOutcome {
  const _Unavailable();
}
