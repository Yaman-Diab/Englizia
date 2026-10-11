import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/session/auth_tokens.dart';

abstract interface class TokenRefresher {
  /// Exchanges [current] for a new pair. Throws `DioException` on failure.
  Future<AuthTokens> refresh(AuthTokens current);
}

/// Calls the refresh endpoint on a bare Dio (no auth interceptor), so it
/// must attach the Authorization header itself.
final class TokenRefreshService implements TokenRefresher {
  TokenRefreshService(this._dio);

  final Dio _dio;

  @override
  Future<AuthTokens> refresh(AuthTokens current) async {
    // ASSUMPTION(api): body `{refreshToken}`, response `{accessToken, refreshToken}`
    // (camelCase, ASP.NET default) — confirm in docs/api/README.md.
    final response = await _dio.post<Object?>(
      ApiEndpoints.refreshToken,
      data: {'refreshToken': current.refreshToken},
      options: Options(
        headers: {'Authorization': 'Bearer ${current.accessToken}'},
      ),
    );
    final json = asJsonMap(response.data);
    final access = json.firstOf([
      'accessToken',
      'access_token',
    ], json.readString);
    if (access == null) {
      throw const FormatException('Refresh response has no access token');
    }
    final refresh =
        json.firstOf(['refreshToken', 'refresh_token'], json.readString) ??
        current.refreshToken;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}
