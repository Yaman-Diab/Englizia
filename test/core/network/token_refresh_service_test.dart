import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  const current = AuthTokens(accessToken: 'old', refreshToken: 'r1');

  TokenRefreshService buildService(FakeHttpAdapter adapter) =>
      TokenRefreshService(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
      );

  test('sends its own Authorization header and the refresh token', () async {
    final adapter = FakeHttpAdapter(
      (_) => const FakeResponse(
        200,
        body: {'accessToken': 'a2', 'refreshToken': 'r2'},
      ),
    );

    final tokens = await buildService(adapter).refresh(current);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, ApiEndpoints.refreshToken);
    expect(request.headers['Authorization'], 'Bearer old');
    expect(request.data, {'refreshToken': 'r1'});
    expect(tokens, const AuthTokens(accessToken: 'a2', refreshToken: 'r2'));
  });

  test('keeps the current refresh token when none is returned', () async {
    final adapter = FakeHttpAdapter(
      (_) => const FakeResponse(200, body: {'accessToken': 'a2'}),
    );

    final tokens = await buildService(adapter).refresh(current);

    expect(tokens.refreshToken, 'r1');
  });

  test('a guest stays a guest after a refresh', () async {
    final adapter = FakeHttpAdapter(
      (_) => const FakeResponse(200, body: {'accessToken': 'a2'}),
    );

    final tokens = await buildService(adapter).refresh(
      const AuthTokens(
        accessToken: 'old',
        refreshToken: 'r1',
        kind: AccountKind.guest,
      ),
    );

    expect(tokens.kind, AccountKind.guest);
  });

  test('throws when the response has no access token', () async {
    final adapter = FakeHttpAdapter(
      (_) => const FakeResponse(200, body: {'token_type': 'Bearer'}),
    );

    expect(buildService(adapter).refresh(current), throwsFormatException);
  });
}
