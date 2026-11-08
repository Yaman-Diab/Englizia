import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/device_platform.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/models/reset_password_model.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';

/// A real response of the dev server, saved as it came.
Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync())
        as Map<String, Object?>;

/// The account's endpoints as the dev server publishes them
/// (docs/api/openapi.json), checked against its own answers.
void main() {
  late FakeHttpAdapter adapter;
  late AccountRepositoryImpl repository;

  void answer(int status, Map<String, Object?>? body) {
    adapter = FakeHttpAdapter((_) => FakeResponse(status, body: body));
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );
    repository = AccountRepositoryImpl(
      AccountRemoteDataSourceImpl(client),
      tokens: FakeTokenStorage(),
      installationId: () async => 'install-1',
      savedDeviceId: () => 'device-1',
      saveDeviceId: (_) async {},
      devicePlatform: 'android',
    );
  }

  group('a recovery link', () {
    test('is checked at /password/reset/check with its token', () async {
      answer(200, {
        'statusCode': 200,
        'message': 'OK',
        'data': {'email': 'user@example.com'},
        'error': null,
        'traceId': 't',
      });

      expect(await repository.verifyPasswordLink('token-1'), isA<Ok<void>>());
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/auth/password/reset/check');
      expect(request.data, {'token': 'token-1'});
    });

    test('out of date reads as expired, not as a form error', () async {
      // The server refuses it with a 400, not the 410 once proposed.
      answer(400, fixture('auth_link_invalid'));

      final result = await repository.verifyPasswordLink('old');

      expect(result, isA<Err<void>>());
      expect((result as Err<void>).failure, isA<LinkExpiredFailure>());
    });

    test('saving sends the new password as newPassword', () async {
      expect(
        ResetPasswordModel.request(
          token: 't',
          password: 'secret-1',
          platform: 'android',
          deviceId: 'device-1',
        ),
        {
          'token': 't',
          'newPassword': 'secret-1',
          'deviceId': 'device-1',
          'platform': 'android',
        },
      );
    });

    test('the field the server names is newPassword', () {
      // Sending `password` instead is what it answered with.
      final details =
          (fixture('auth_password_reset_validation_failed')['error']!
                  as Map<String, Object?>)['details']!
              as List<Object?>;

      expect((details.single! as Map<String, Object?>)['field'], 'newPassword');
    });
  });

  group('the email', () {
    test('a confirming link out of date reads as expired', () async {
      answer(400, fixture('auth_email_verify_link_invalid'));

      final result = await repository.verifyEmail('old');

      expect((result as Err<void>).failure, isA<LinkExpiredFailure>());
    });

    test('is corrected with newEmail', () async {
      answer(202, null);

      expect(
        await repository.changeEmail(' user@example.com '),
        isA<Ok<void>>(),
      );
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/auth/email');
      expect(request.data, {'newEmail': 'user@example.com'});
    });
  });

  group('signing in', () {
    test('a wrong password is the server\'s invalid credentials', () async {
      answer(401, fixture('auth_login_invalid_credentials'));

      final result = await repository.signIn(
        email: 'user@example.com',
        password: 'wrong-1',
      );

      final failure = (result as Err<Object?>).failure;
      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.code, 'auth.invalid_credentials');
    });

    test('a refused form names each field, as the server does', () async {
      answer(400, fixture('auth_register_validation_failed'));

      final result = await repository.signIn(
        email: 'not-an-email',
        password: 'short',
      );

      final failure = (result as Err<Object?>).failure as ValidationFailure;
      expect(failure.firstCodeFor('email'), 'email');
      expect(failure.firstCodeFor('password'), 'minimum_length');
    });
  });

  group('this phone', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('an iPhone is ios, an Android phone android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(devicePlatform(), 'ios');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(devicePlatform(), 'android');
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(devicePlatform(), isNull);
    });
  });
}
