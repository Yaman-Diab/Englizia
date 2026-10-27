import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/auth_interceptor.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/models/register_model.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';

/// The register example: the same file mock mode serves.
final exampleBody =
    jsonDecode(File(AccountFakeDataSource.registerAsset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  const account = NewAccount(
    name: ' Learner ',
    email: ' user@example.com ',
    password: 'password1',
  );

  group('AccountRules', () {
    test('an email needs a name, an @ and a domain', () {
      expect(AccountRules.isEmail('user@example.com'), isTrue);
      expect(AccountRules.isEmail(' user@example.com '), isTrue);
      expect(AccountRules.isEmail('user'), isFalse);
      expect(AccountRules.isEmail('user@example'), isFalse);
      expect(AccountRules.isEmail('user@example.c'), isFalse);
      expect(AccountRules.isEmail('us er@example.com'), isFalse);
    });

    test('a password needs the minimum length', () {
      expect(AccountRules.isPassword('1234567'), isFalse);
      expect(AccountRules.isPassword('12345678'), isTrue);
    });

    test('a name is more than spaces', () {
      expect(AccountRules.isName('  '), isFalse);
      expect(AccountRules.isName('أحمد'), isTrue);
    });

    test('the password never prints', () {
      expect(account.toString(), isNot(contains('password1')));
    });
  });

  group('RegisterModel', () {
    test('sends RegisterRequest, trimmed, with no device id yet', () {
      expect(RegisterModel.request(account, platform: 'android'), {
        'email': 'user@example.com',
        'password': 'password1',
        'displayName': 'Learner',
        'deviceId': null,
        'platform': 'android',
      });
    });

    test('the response is a member session with its expiry', () {
      final now = DateTime.utc(2026, 10, 28);
      final tokens = RegisterModel.tokens(exampleBody, now: now);
      expect(tokens.kind, AccountKind.member);
      expect(tokens.accessExpiresAt, now.add(const Duration(seconds: 900)));
    });
  });

  group('AccountRemoteDataSourceImpl.createAccount', () {
    test('POST /api/v1/auth/register without the session token', () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeResponse(201, body: exampleBody),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(
          tokens: FakeTokenStorage(
            const AuthTokens(accessToken: 'stale', refreshToken: 'r'),
          ),
          refresher: FakeTokenRefresher((current) async => current),
          retry: dio.fetch<Object?>,
          onSessionExpired: () async {},
        ),
      );

      final tokens = await AccountRemoteDataSourceImpl(
        ApiClient(dio),
      ).createAccount(const {'email': 'user@example.com'});

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/auth/register');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(tokens.accessToken, 'mock-member-access-token');
    });

    test('an email with an account is a conflict', () async {
      final client = ApiClient(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = FakeHttpAdapter(
            (_) => const FakeResponse(
              409,
              body: {
                'statusCode': 409,
                'message': 'Conflict',
                'data': null,
                'error': {'code': 'auth.email_taken', 'details': null},
                'traceId': '00000000000000000000000000000000',
              },
            ),
          ),
      );
      final result = await AccountRepositoryImpl(
        AccountRemoteDataSourceImpl(client),
        installationId: () async => 'install-1',
        devicePlatform: null,
      ).createAccount(account);
      expect((result as Err).failure, isA<ConflictFailure>());
    });
  });

  group('mock mode', () {
    AccountFakeDataSource source() =>
        AccountFakeDataSource(_DiskBundle(), latency: Duration.zero);

    test('creates a member from the bundled example', () async {
      final tokens = await source().createAccount(const {
        'email': 'user@example.com',
      });
      expect(tokens.kind, AccountKind.member);
    });

    test('the taken email answers like the server', () async {
      final result =
          await AccountRepositoryImpl(
            source(),
            installationId: () async => 'install-1',
            devicePlatform: 'android',
          ).createAccount(
            const NewAccount(
              name: 'Learner',
              email: AccountFakeDataSource.takenEmail,
              password: 'password1',
            ),
          );
      expect((result as Err).failure, isA<ConflictFailure>());
    });
  });
}
