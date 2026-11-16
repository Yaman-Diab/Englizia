import 'package:dio/dio.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';
import 'package:englizia/features/me/data/repositories/profile_repository_impl.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/api_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';

/// The live account calls «أنا» and the settings make
/// (docs/api/openapi.json): enrollments by track, `/me` and `/me/learning`.
void main() {
  late FakeHttpAdapter adapter;
  late SettingsStorageService settings;
  late ProfileRepositoryImpl repository;

  Future<void> answer(FakeResponse Function() response) async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStorageService(await SharedPreferences.getInstance());
    adapter = FakeHttpAdapter((_) => response());
    repository = ProfileRepositoryImpl(
      ProfileRemoteDataSourceImpl(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = adapter,
        ),
      ),
      settings: settings,
      tokens: FakeTokenStorage(),
      devicePlatform: 'android',
    );
  }

  group('enrollments, by their track', () {
    test('PUT /api/v1/app/enrollments/{trackId}/active', () async {
      await answer(() => const FakeResponse(200));
      expect(await repository.switchTrack('trk_emar'), isA<Ok<void>>());

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/app/enrollments/trk_emar/active');
    });

    test('PUT /api/v1/app/enrollments/{trackId}/level', () async {
      await answer(() => const FakeResponse(200));
      await repository.changeLevel('trk_emar', 'lvl_emar_08');

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/app/enrollments/trk_emar/level');
      expect(request.data, {'levelId': 'lvl_emar_08'});
    });
  });

  group('the goal and the reminder', () {
    test('read from the account: the dev server answer', () async {
      await answer(() => FakeResponse(200, body: apiFixture('app_me_guest')));
      final result = await repository.getPreferences();

      expect(adapter.requests.single.path, '/api/v1/app/me');
      expect(
        (result as Ok<Preferences>).value,
        const Preferences(dailyGoalMinutes: 10, notifications: true),
      );
    });

    test('the reminder reads "HH:mm:ss"', () async {
      final me = apiFixture('app_me_guest');
      final user = {...me['data']! as Map<String, Object?>};
      user['reminderTime'] = '19:30:00';
      await answer(() => FakeResponse(200, body: {...me, 'data': user}));

      final preferences = (await repository.getPreferences() as Ok).value;
      expect(
        preferences,
        const Preferences(
          dailyGoalMinutes: 10,
          notifications: true,
          reminderHour: 19,
          reminderMinute: 30,
        ),
      );
    });

    test('PUT /api/v1/app/me/learning, the reminder as "HH:mm:ss"', () async {
      await answer(() => const FakeResponse(200));
      await repository.savePreferences(
        const Preferences(
          dailyGoalMinutes: 15,
          notifications: true,
          reminderHour: 8,
          reminderMinute: 5,
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/app/me/learning');
      expect(request.data, {
        'dailyGoalMinutes': 15,
        'reminderTime': '08:05:00',
      });
    });

    test('no reminder is null', () async {
      await answer(() => const FakeResponse(200));
      await repository.savePreferences(
        const Preferences(dailyGoalMinutes: 5, notifications: true),
      );
      expect(adapter.requests.single.data, {
        'dailyGoalMinutes': 5,
        'reminderTime': null,
      });
    });

    test('the notifications switch is kept on the phone', () async {
      await answer(() => FakeResponse(200, body: apiFixture('app_me_guest')));
      await repository.savePreferences(
        const Preferences(dailyGoalMinutes: 10, notifications: false),
      );
      expect(settings.notifications, isFalse);

      final preferences = (await repository.getPreferences() as Ok).value;
      expect((preferences as Preferences).notifications, isFalse);
    });
  });
}
