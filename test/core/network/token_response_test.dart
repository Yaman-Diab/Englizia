import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);

  /// The shape of docs/api/openapi.json `ApiResponseOfTokenResponse`.
  Map<String, Object?> enveloped(Map<String, Object?> data) => {
    'statusCode': 200,
    'message': 'OK',
    'data': data,
    'error': null,
    'traceId': 'abc',
  };

  test('a new session needs both tokens and counts expiresIn from now', () {
    final tokens = TokenResponse.parse(
      enveloped({
        'accessToken': 'a',
        'expiresIn': 900,
        'tokenType': 'Bearer',
        'refreshToken': 'r',
        'refreshTokenExpiresAt': '2026-11-27T12:00:00Z',
      }),
      now: now,
      kind: AccountKind.guest,
    );

    expect(tokens.kind, AccountKind.guest);
    expect(tokens.accessExpiresAt, now.add(const Duration(minutes: 15)));
    expect(tokens.refreshExpiresAt, DateTime.utc(2026, 11, 27, 12));
  });

  test('a new session without a refresh token is rejected', () {
    expect(
      () => TokenResponse.parse(enveloped({'accessToken': 'a'}), now: now),
      throwsFormatException,
    );
  });

  test('a refresh keeps what it did not return', () {
    final current = AuthTokens(
      accessToken: 'old',
      refreshToken: 'r1',
      kind: AccountKind.guest,
      refreshExpiresAt: DateTime.utc(2026, 11, 1),
    );

    final tokens = TokenResponse.parse(
      enveloped({'accessToken': 'new'}),
      now: now,
      current: current,
    );

    expect(tokens.refreshToken, 'r1');
    expect(tokens.kind, AccountKind.guest);
    expect(tokens.refreshExpiresAt, DateTime.utc(2026, 11, 1));
    expect(tokens.accessExpiresAt, isNull);
  });

  test('expiresSoon looks ahead by the margin', () {
    final tokens = AuthTokens(
      accessToken: 'a',
      refreshToken: 'r',
      accessExpiresAt: now.add(const Duration(seconds: 20)),
    );
    expect(
      tokens.expiresSoon(now, margin: const Duration(seconds: 30)),
      isTrue,
    );
    expect(
      tokens.expiresSoon(now, margin: const Duration(seconds: 10)),
      isFalse,
    );
    expect(
      const AuthTokens(
        accessToken: 'a',
        refreshToken: 'r',
      ).expiresSoon(now, margin: const Duration(hours: 1)),
      isFalse,
    );
  });
}
