import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/models/guest_account_model.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/onboarding/domain/entities/learning_reason.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';

/// The contract's example response: the same file mock mode serves.
final exampleBody =
    jsonDecode(File(AccountFakeDataSource.asset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _RecordingDataSource implements AccountRemoteDataSource {
  _RecordingDataSource({this.fail = false});

  final bool fail;
  final requests = <Map<String, Object?>>[];

  @override
  Future<AuthTokens> createGuestAccount(Map<String, Object?> request) async {
    requests.add(request);
    if (fail) throw const NetworkException('connectionError');
    return const AuthTokens(
      accessToken: 'a',
      refreshToken: 'r',
      kind: AccountKind.guest,
    );
  }

  @override
  Future<AuthTokens> createAccount(Map<String, Object?> request) async {
    requests.add(request);
    if (fail) throw const NetworkException('connectionError');
    return const AuthTokens(accessToken: 'a', refreshToken: 'r');
  }
}

void main() {
  const adult = OnboardingPath(
    audience: TrackAudience.self,
    trackId: 'trk_general',
    trackTitle: LocalizedText(ar: 'الإنجليزية العامة'),
    entryMethod: TrackEntryMethod.placementTest,
    reasons: [LearningReason.travel, LearningReason.career],
    dailyGoalMinutes: 15,
    challengeDays: 14,
    startLevel: TrackLevel(
      id: 'lvl_gen_prea1',
      order: 1,
      name: LocalizedText(ar: 'Pre-A1'),
    ),
    reminder: ReminderTime(8, 5),
  );

  test('the answers are sent as the contract says', () {
    expect(
      GuestAccountModel.request(
        installationId: 'install-1',
        answers: adult,
        languageCode: 'ar',
        utcOffsetMinutes: 180,
      ),
      {
        'installationId': 'install-1',
        'language': 'ar',
        'utcOffsetMinutes': 180,
        'onboarding': {
          'audience': 'self',
          'trackId': 'trk_general',
          'child': null,
          'gradeLevelId': null,
          'reasons': ['travel', 'career'],
          'dailyGoalMinutes': 15,
          'challengeDays': 14,
          'startLevelId': 'lvl_gen_prea1',
          'placementTest': false,
          'reminderTime': '08:05',
        },
      },
    );
  });

  test('a parent sends the child; no reminder is null', () {
    final onboarding = GuestAccountModel.onboarding(
      const OnboardingPath(
        audience: TrackAudience.child,
        trackId: 'trk_kids',
        childName: 'سارة',
        childAge: 7,
      ),
    );
    expect(onboarding['audience'], 'child');
    expect(onboarding['child'], {'name': 'سارة', 'age': 7});
    expect(onboarding['reminderTime'], isNull);
  });

  test('the example response is a guest session', () {
    final now = DateTime.utc(2026, 10, 28);
    final tokens = GuestAccountModel.tokens(exampleBody, now: now);
    expect(tokens.kind, AccountKind.guest);
    expect(tokens.accessToken, 'mock-guest-access-token');
    expect(tokens.accessExpiresAt, now.add(const Duration(seconds: 900)));
  });

  test('a response without tokens is rejected', () {
    expect(
      () => GuestAccountModel.tokens(const {
        'accessToken': 'a',
      }, now: DateTime.utc(2026)),
      throwsFormatException,
    );
  });

  test('POST /api/v1/auth/guest', () async {
    final adapter = FakeHttpAdapter(
      (_) => FakeResponse(200, body: exampleBody),
    );
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    final tokens = await AccountRemoteDataSourceImpl(
      client,
    ).createGuestAccount(const {'installationId': 'install-1'});

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/auth/guest');
    expect(request.data, {'installationId': 'install-1'});
    expect(tokens.kind, AccountKind.guest);
  });

  test('mock mode serves the bundled example', () async {
    final tokens = await AccountFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    ).createGuestAccount(const {});
    expect(tokens.kind, AccountKind.guest);
  });

  group('AccountRepositoryImpl', () {
    test('ties the guest to this install', () async {
      final source = _RecordingDataSource();
      final result =
          await AccountRepositoryImpl(
            source,
            installationId: () async => 'install-1',
            devicePlatform: 'android',
          ).createGuestAccount(
            answers: adult,
            languageCode: 'en',
            utcOffsetMinutes: -300,
          );

      expect(result, isA<Ok<AuthTokens>>());
      final sent = source.requests.single;
      expect(sent['installationId'], 'install-1');
      expect(sent['language'], 'en');
      expect(sent['utcOffsetMinutes'], -300);
    });

    test('maps errors through the error funnel', () async {
      final result =
          await AccountRepositoryImpl(
            _RecordingDataSource(fail: true),
            installationId: () async => 'install-1',
            devicePlatform: 'android',
          ).createGuestAccount(
            answers: adult,
            languageCode: 'ar',
            utcOffsetMinutes: 0,
          );
      expect((result as Err).failure, isA<NetworkFailure>());
    });
  });
}
