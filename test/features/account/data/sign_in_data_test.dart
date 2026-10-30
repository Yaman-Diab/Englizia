import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/auth_interceptor.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/models/sign_in_model.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';

final _memberBody =
    jsonDecode(File(AccountFakeDataSource.registerAsset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  late FakeHttpAdapter adapter;

  AccountRepositoryImpl repository(FakeResponse Function() answer) {
    adapter = FakeHttpAdapter((_) => answer());
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        // A guest about to sign in to another account.
        tokens: FakeTokenStorage(
          const AuthTokens(
            accessToken: 'guest',
            refreshToken: 'r',
            kind: AccountKind.guest,
          ),
        ),
        refresher: FakeTokenRefresher((current) async => current),
        retry: dio.fetch<Object?>,
        onSessionExpired: () async {},
      ),
    );
    return AccountRepositoryImpl(
      AccountRemoteDataSourceImpl(ApiClient(dio)),
      tokens: FakeTokenStorage(),
      installationId: () async => 'install-1',
      devicePlatform: 'android',
    );
  }

  test('sends LoginRequest, trimmed, with no device id yet', () {
    expect(
      SignInModel.request(
        email: ' user@example.com ',
        password: ' p ',
        platform: null,
      ),
      {
        'email': 'user@example.com',
        'password': ' p ',
        'deviceId': null,
        'platform': null,
      },
    );
  });

  test('POST /api/v1/auth/login without the session token', () async {
    final result = await repository(
      () => FakeResponse(200, body: _memberBody),
    ).signIn(email: 'user@example.com', password: 'password1');

    final request = adapter.requests.single;
    expect(request.path, '/api/v1/auth/login');
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect((result as Ok<AuthTokens>).value.kind, AccountKind.member);
  });

  test('a refused try is unauthorized, with no refresh attempt', () async {
    final result = await repository(
      () => const FakeResponse(401),
    ).signIn(email: 'user@example.com', password: 'wrong');
    expect((result as Err).failure, isA<UnauthorizedFailure>());
    expect(adapter.requests, hasLength(1));
  });

  test('too many tries carry the server\'s wait', () async {
    final result = await repository(
      () => const FakeResponse(
        429,
        headers: {
          'retry-after': ['120'],
        },
      ),
    ).signIn(email: 'user@example.com', password: 'wrong');
    final failure = (result as Err).failure as RateLimitFailure;
    expect(failure.retryAfter, const Duration(minutes: 2));
  });

  group('mock mode', () {
    AccountFakeDataSource source() =>
        AccountFakeDataSource(_DiskBundle(), latency: Duration.zero);

    test('the example pair signs in', () async {
      final tokens = await source().signIn(const {
        'email': AccountFakeDataSource.signInEmail,
        'password': AccountFakeDataSource.signInPassword,
      });
      expect(tokens.kind, AccountKind.member);
    });

    test('anything else is refused, and the locked email waits', () async {
      final repo = AccountRepositoryImpl(
        source(),
        tokens: FakeTokenStorage(),
        installationId: () async => 'i',
        devicePlatform: null,
      );
      final wrong = await repo.signIn(
        email: AccountFakeDataSource.signInEmail,
        password: 'nope',
      );
      expect((wrong as Err).failure, isA<UnauthorizedFailure>());

      final locked = await repo.signIn(
        email: AccountFakeDataSource.lockedEmail,
        password: 'any',
      );
      expect(
        ((locked as Err).failure as RateLimitFailure).retryAfter,
        AccountFakeDataSource.lockedFor,
      );
    });
  });
}
