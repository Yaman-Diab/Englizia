import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/core/session/auth_tokens.dart';

abstract interface class TokenRefresher {
  /// Exchanges [current] for a new pair. Throws `DioException` on failure.
  Future<AuthTokens> refresh(AuthTokens current);
}

/// Calls the refresh endpoint on a bare Dio (no auth interceptor). The
/// server needs only the refresh token in the body (`RefreshRequest`); the
/// expired access token rides along in `Authorization` for its logs.
final class TokenRefreshService implements TokenRefresher {
  TokenRefreshService(this._dio, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _now;

  @override
  Future<AuthTokens> refresh(AuthTokens current) async {
    final response = await _dio.post<Object?>(
      ApiEndpoints.refreshToken,
      data: {'refreshToken': current.refreshToken},
      options: Options(
        headers: {'Authorization': 'Bearer ${current.accessToken}'},
      ),
    );
    return TokenResponse.parse(response.data, now: _now(), current: current);
  }
}
