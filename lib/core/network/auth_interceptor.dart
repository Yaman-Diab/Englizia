import 'package:dio/dio.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/token_storage.dart';

typedef RequestRetrier = Future<Response<Object?>> Function(RequestOptions);

/// Attaches the bearer token and recovers from an expired access token:
/// one shared refresh for all concurrent 401s, one retry per request, and a
/// session expiry only when the server rejects the refresh token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokens,
    required TokenRefresher refresher,
    required RequestRetrier retry,
    required Future<void> Function() onSessionExpired,
  }) : _tokens = tokens,
       _refresher = refresher,
       _retry = retry,
       _onSessionExpired = onSessionExpired;

  /// Set `extra[skipAuthKey] = true` for public endpoints (login, register).
  static const skipAuthKey = 'auth.skip';
  static const _retriedKey = 'auth.retried';

  final TokenStorage _tokens;
  final TokenRefresher _refresher;
  final RequestRetrier _retry;
  final Future<void> Function() _onSessionExpired;

  Future<_RefreshOutcome>? _inFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await _tokens.read();
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
    return _inFlight ??= _refresh(current).whenComplete(() => _inFlight = null);
  }

  Future<_RefreshOutcome> _refresh(AuthTokens current) async {
    try {
      final next = await _refresher.refresh(current);
      await _tokens.write(next);
      return _Refreshed(next);
    } on DioException catch (error) {
      if (error.response != null) {
        AppLogger.info('Refresh rejected: ${error.response?.statusCode}');
        return const _Rejected();
      }
      AppLogger.warning('Refresh unavailable', error.type.name);
      return const _Unavailable();
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Refresh failed');
      return const _Rejected();
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

/// No response (offline/timeout): keep the session, surface the error.
final class _Unavailable extends _RefreshOutcome {
  const _Unavailable();
}
