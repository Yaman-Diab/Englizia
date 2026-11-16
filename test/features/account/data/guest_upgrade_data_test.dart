import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/auth_interceptor.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';

void main() {
  const guest = AuthTokens(
    accessToken: 'guest-access',
    refreshToken: 'guest-refresh',
    kind: AccountKind.guest,
  );
  const account = NewAccount(
    name: 'Learner',
    email: 'user@example.com',
    password: 'password1',
  );

  late FakeTokenStorage storage;
  late FakeHttpAdapter adapter;
  String? savedDevice;

  /// The app's own setup: the auth interceptor adds the stored token.
  AccountRepositoryImpl repository(FakeResponse Function() answer) {
    adapter = FakeHttpAdapter((_) => answer());
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        tokens: storage,
        refresher: FakeTokenRefresher((current) async => current),
        retry: dio.fetch<Object?>,
        onSessionExpired: () async {},
      ),
    );
    return AccountRepositoryImpl(
      AccountRemoteDataSourceImpl(ApiClient(dio)),
      tokens: storage,
      savedDeviceId: () => savedDevice,
      saveDeviceId: (id) async => savedDevice = id,
      devicePlatform: 'android',
    );
  }

  setUp(() {
    storage = FakeTokenStorage(guest);
    savedDevice = null;
  });

  group('upgradeGuest', () {
    test('POST /api/v1/auth/guest/upgrade/email with the guest token; the '
        'session carries on as a member session', () async {
      final result = await repository(
        () => FakeResponse(200, body: apiFixture('app_me_guest')),
      ).upgradeGuest(account);

      final request = adapter.requests.single;
      expect(request.path, '/api/v1/auth/guest/upgrade/email');
      expect(request.headers['Authorization'], 'Bearer guest-access');
      expect(request.data, {
        'email': 'user@example.com',
        'password': 'password1',
        'displayName': 'Learner',
      });
      final tokens = (result as Ok<AuthTokens>).value;
      expect(tokens.kind, AccountKind.member);
      expect(tokens.accessToken, 'guest-access');
    });

    test('an email with an account is a conflict', () async {
      final result = await repository(
        () => const FakeResponse(
          409,
          body: {
            'statusCode': 409,
            'data': null,
            'error': {'code': 'auth.email_taken', 'details': null},
          },
        ),
      ).upgradeGuest(account);
      expect((result as Err).failure, isA<ConflictFailure>());
    });

    test('not a guest any more: upgraded already, by a lost answer', () async {
      final result = await repository(
        () => const FakeResponse(
          409,
          body: {
            'statusCode': 409,
            'data': null,
            'error': {'code': 'auth.not_guest', 'details': null},
          },
        ),
      ).upgradeGuest(account);
      expect((result as Ok<AuthTokens>).value.kind, AccountKind.member);
    });
  });

  group('logOut', () {
    test('sends the refresh token, without the session token', () async {
      await repository(() => const FakeResponse(200)).logOut();

      final request = adapter.requests.single;
      expect(request.path, '/api/v1/auth/logout');
      expect(request.data, {'refreshToken': 'guest-refresh'});
      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('with no session there is nothing to send', () async {
      storage = FakeTokenStorage();
      final result = await repository(() => const FakeResponse(200)).logOut();
      expect(result, isA<Ok<void>>());
      expect(adapter.requests, isEmpty);
    });

    test('a failure is reported, for the caller to ignore', () async {
      final result = await repository(() => const FakeResponse(500)).logOut();
      expect((result as Err).failure, isA<ServerFailure>());
    });
  });
}
