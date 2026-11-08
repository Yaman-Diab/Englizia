import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';
import 'package:englizia/features/me/data/repositories/profile_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';

/// `POST /api/v1/auth/password/change` (docs/api/openapi.json): the server
/// answers with a `TokenResponse`, the session this phone carries on with.
void main() {
  late FakeHttpAdapter adapter;
  late FakeTokenStorage tokens;
  late SettingsStorageService settings;
  late ProfileRepositoryImpl repository;

  Future<void> answer(int status, Map<String, Object?>? body) async {
    SharedPreferences.setMockInitialValues({'account.device_id': 'device-1'});
    settings = SettingsStorageService(await SharedPreferences.getInstance());
    adapter = FakeHttpAdapter((_) => FakeResponse(status, body: body));
    tokens = FakeTokenStorage();
    repository = ProfileRepositoryImpl(
      ProfileRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      ),
      settings: settings,
      tokens: tokens,
      devicePlatform: 'android',
    );
  }

  Map<String, Object?> session({String deviceId = 'device-1'}) => {
    'statusCode': 200,
    'message': 'OK',
    'data': {
      'accessToken': 'access-2',
      'expiresIn': 900,
      'tokenType': 'Bearer',
      'refreshToken': 'refresh-2',
      'refreshTokenExpiresAt': '2026-12-31T00:00:00Z',
      'deviceId': deviceId,
      'isNewUser': false,
      'user': {
        'id': '00000000-0000-0000-0000-000000000000',
        'email': 'user@example.com',
        'displayName': 'Learner',
        'emailVerified': true,
        'roles': ['student'],
        'authMethods': ['password'],
      },
    },
    'error': null,
    'traceId': 't',
  };

  test(
    'sends both passwords with this phone, as the contract has it',
    () async {
      await answer(200, session());

      await repository.changePassword(
        current: 'old-pass-1',
        next: 'new-pass-1',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/auth/password/change');
      expect(request.data, {
        'currentPassword': 'old-pass-1',
        'newPassword': 'new-pass-1',
        'deviceId': 'device-1',
        'platform': 'android',
      });
    },
  );

  test('keeps the new session, as the old one may be over', () async {
    await answer(200, session());

    final result = await repository.changePassword(
      current: 'old-pass-1',
      next: 'new-pass-1',
    );

    expect(result, isA<Ok<void>>());
    expect(tokens.writeCount, 1);
    expect(tokens.tokens?.accessToken, 'access-2');
    expect(tokens.tokens?.refreshToken, 'refresh-2');
  });

  test('keeps the device id the server gives back', () async {
    await answer(200, session(deviceId: 'device-2'));

    await repository.changePassword(current: 'old-pass-1', next: 'new-pass-1');

    expect(settings.deviceId, 'device-2');
  });

  test('an answer with no session changes nothing on the phone', () async {
    await answer(200, {
      'statusCode': 200,
      'message': 'OK',
      'data': null,
      'error': null,
      'traceId': 't',
    });

    final result = await repository.changePassword(
      current: 'old-pass-1',
      next: 'new-pass-1',
    );

    expect(result, isA<Ok<void>>());
    expect(tokens.writeCount, 0);
  });
}
