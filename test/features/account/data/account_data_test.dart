import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_exception.dart';
import 'package:englizia/core/network/api_status_codes.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/core/network/token_response.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/models/guest_account_model.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/entities/account_email.dart';
import 'package:englizia/features/account/domain/entities/new_account.dart';
import 'package:englizia/features/account/domain/entities/social_session.dart';
import 'package:englizia/features/onboarding/domain/entities/learning_reason.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';

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
  _RecordingDataSource({
    this.fail = false,
    this.answersFail = 0,
    this.answersConflict = false,
  });

  final bool fail;
  int answersFail;
  final bool answersConflict;
  final requests = <Map<String, Object?>>[];
  final onboardings = <(Map<String, Object?>, String)>[];

  @override
  Future<void> submitOnboarding(
    Map<String, Object?> request, {
    required String accessToken,
  }) async {
    if (answersFail-- > 0) throw const NetworkException('connectionError');
    if (answersConflict) {
      throw const ApiException(statusCode: ApiStatusCodes.conflict);
    }
    onboardings.add((request, accessToken));
  }

  @override
  Future<void> upgradeGuestWithEmail(Map<String, Object?> request) async =>
      requests.add(request);

  @override
  Future<void> upgradeGuestWithGoogle(String idToken) async =>
      requests.add({'idToken': idToken});

  @override
  Future<AuthTokens> createGuestAccount(Map<String, Object?> request) async {
    requests.add(request);
    if (fail) throw const NetworkException('connectionError');
    return const AuthTokens(
      accessToken: 'a',
      refreshToken: 'r',
      kind: AccountKind.guest,
      deviceId: 'device-1',
    );
  }

  @override
  Future<AuthTokens> createAccount(Map<String, Object?> request) async {
    requests.add(request);
    if (fail) throw const NetworkException('connectionError');
    return const AuthTokens(accessToken: 'a', refreshToken: 'r');
  }

  @override
  Future<AuthTokens> signIn(Map<String, Object?> request) =>
      createAccount(request);

  @override
  Future<SocialSession> signInWithGoogle(Map<String, Object?> request) async =>
      SocialSession(tokens: await createAccount(request), isNewAccount: true);

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<AccountEmail> getEmail() => throw UnimplementedError();

  @override
  Future<void> resendEmailLink() async {}

  @override
  Future<void> changeEmail(String email) async {}

  @override
  Future<void> verifyEmail(String token) async {}

  @override
  Future<void> verifyPasswordLink(String token) async {}

  @override
  Future<AuthTokens?> resetPassword(Map<String, Object?> request) =>
      createAccount(request);

  @override
  Future<void> logOut(String refreshToken) async {
    if (fail) throw const NetworkException('connectionError');
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

  test('the answers go as OnboardingRequest', () {
    expect(
      OnboardingModel.request(adult, language: 'ar', timeZone: 'Etc/GMT-3'),
      {
        'uiLanguage': 'ar',
        'timeZone': 'Etc/GMT-3',
        'learnerKind': 'adult',
        'trackId': 'trk_general',
        // A placement track's first level is the server's to choose.
        'start': 'beginner',
        'learningReasons': ['travel', 'career'],
        'dailyGoalMinutes': 15,
        'streakGoalDays': 14,
        'reminderTime': '08:05:00',
      },
    );
  });

  test('a parent sends the child; no reminder is null', () {
    final request = OnboardingModel.request(
      const OnboardingPath(
        audience: TrackAudience.child,
        trackId: 'trk_kids',
        childName: 'سارة',
        childAge: 7,
      ),
      language: 'ar',
      timeZone: 'UTC',
    );
    expect(request['learnerKind'], 'child');
    expect(request['child'], {'name': 'سارة', 'age': 7});
    expect(request['reminderTime'], isNull);
  });

  group('each kind of track sends only what it takes', () {
    const grade7 = TrackLevel(
      id: 'grade_7',
      order: 7,
      name: LocalizedText(ar: '7'),
    );

    (Object?, Object?, bool, bool) startOf(OnboardingPath path) {
      final request = OnboardingModel.request(
        path,
        language: 'ar',
        timeZone: 'UTC',
      );
      return (
        request['start'],
        request['levelId'],
        request.containsKey('start'),
        request.containsKey('levelId'),
      );
    }

    test('a placement track: the test, or the beginning, and no level', () {
      expect(startOf(adult.copyWith(placementTest: true)), (
        'placement',
        null,
        true,
        false,
      ));
      expect(startOf(adult), ('beginner', null, true, false));
    });

    test('a grade track: the grade, and no start', () {
      expect(
        startOf(
          const OnboardingPath(
            audience: TrackAudience.schoolStudent,
            entryMethod: TrackEntryMethod.gradeSelection,
            grade: grade7,
          ),
        ),
        (null, 'grade_7', false, true),
      );
    });

    test('a direct track: neither', () {
      expect(
        startOf(
          const OnboardingPath(
            audience: TrackAudience.child,
            trackId: 'trk_kids',
            entryMethod: TrackEntryMethod.directStart,
            startLevel: grade7,
          ),
        ),
        (null, null, false, false),
      );
    });

    test('no kind known: what the answers chose', () {
      expect(
        startOf(
          const OnboardingPath(
            audience: TrackAudience.schoolStudent,
            grade: grade7,
          ),
        ),
        (null, 'grade_7', false, true),
      );
    });

    test('no child is left out, not null', () {
      expect(
        OnboardingModel.request(
          adult,
          language: 'ar',
          timeZone: 'UTC',
        ).containsKey('child'),
        isFalse,
      );
    });
  });

  test('the phone\'s offset as an IANA zone', () {
    expect(OnboardingModel.timeZoneOf(const Duration(hours: 3)), 'Etc/GMT-3');
    expect(OnboardingModel.timeZoneOf(const Duration(hours: -5)), 'Etc/GMT+5');
    expect(OnboardingModel.timeZoneOf(Duration.zero), 'UTC');
    expect(
      OnboardingModel.timeZoneOf(const Duration(hours: 5, minutes: 30)),
      'UTC',
    );
  });

  test('a guest is made bare: CreateGuestRequest', () {
    expect(
      GuestAccountModel.request(deviceId: 'device-1', platform: 'android'),
      {'deviceId': 'device-1', 'platform': 'android', 'displayName': null},
    );
  });

  test('the dev server\'s answer is a guest session', () {
    final now = DateTime.utc(2026, 11, 16);
    final tokens = GuestAccountModel.tokens(
      apiFixture('auth_guest_created'),
      now: now,
    );
    expect(tokens.kind, AccountKind.guest);
    expect(tokens.accessToken, 'guest-access-token');
    expect(tokens.deviceId, '00000000-0000-4000-8000-000000000000');
    expect(tokens.accessExpiresAt, now.add(const Duration(seconds: 900)));
  });

  test('any session says whose it is: the account type', () {
    final tokens = TokenResponse.parse(
      apiFixture('auth_guest_created'),
      now: DateTime.utc(2026),
    );
    expect(tokens.kind, AccountKind.guest);
  });

  test('a response without tokens is rejected', () {
    expect(
      () => GuestAccountModel.tokens(const {
        'accessToken': 'a',
      }, now: DateTime.utc(2026)),
      throwsFormatException,
    );
  });

  test('POST /api/v1/auth/guest, without a session', () async {
    final adapter = FakeHttpAdapter(
      (_) => FakeResponse(201, body: apiFixture('auth_guest_created')),
    );
    final client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );

    final tokens = await AccountRemoteDataSourceImpl(client).createGuestAccount(
      GuestAccountModel.request(deviceId: null, platform: 'android'),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/auth/guest');
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(tokens.kind, AccountKind.guest);
  });

  test(
    'POST /api/v1/app/me/onboarding with the new account\'s token',
    () async {
      final adapter = FakeHttpAdapter((_) => const FakeResponse(200));
      final client = ApiClient(
        Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = adapter,
      );

      await AccountRemoteDataSourceImpl(
        client,
      ).submitOnboarding(const {'uiLanguage': 'ar'}, accessToken: 'new-token');

      final request = adapter.requests.single;
      expect(request.path, '/api/v1/app/me/onboarding');
      expect(request.headers['Authorization'], 'Bearer new-token');
      expect(request.data, {'uiLanguage': 'ar'});
    },
  );

  test('mock mode serves the bundled example', () async {
    final tokens = await AccountFakeDataSource(
      _DiskBundle(),
      latency: Duration.zero,
    ).createGuestAccount(const {});
    expect(tokens.kind, AccountKind.guest);
  });

  group('AccountRepositoryImpl', () {
    AccountRepositoryImpl repository(_RecordingDataSource source) =>
        AccountRepositoryImpl(
          source,
          tokens: FakeTokenStorage(),
          savedDeviceId: () => null,
          saveDeviceId: (_) async {},
          devicePlatform: 'android',
          language: () => 'en',
          timeZone: () => 'Etc/GMT-3',
        );

    test('keeps the device id a new guest gets', () async {
      String? saved;
      await AccountRepositoryImpl(
        _RecordingDataSource(),
        tokens: FakeTokenStorage(),
        savedDeviceId: () => saved,
        saveDeviceId: (id) async => saved = id,
        devicePlatform: 'android',
      ).createGuestAccount(answers: adult);
      expect(saved, 'device-1');
    });

    test('a guest, then its answers with its own token', () async {
      final source = _RecordingDataSource();
      final result = await repository(
        source,
      ).createGuestAccount(answers: adult);

      expect(result, isA<Ok<AuthTokens>>());
      expect(source.requests.first, {
        'deviceId': null,
        'platform': 'android',
        'displayName': null,
      });
      final (answers, token) = source.onboardings.single;
      expect(answers['uiLanguage'], 'en');
      expect(answers['timeZone'], 'Etc/GMT-3');
      expect(answers['trackId'], 'trk_general');
      expect(token, 'a');
    });

    test('answers that failed are sent again, with no second guest', () async {
      final source = _RecordingDataSource(answersFail: 1);
      final repo = repository(source);

      final first = await repo.createGuestAccount(answers: adult);
      expect((first as Err).failure, isA<NetworkFailure>());
      final second = await repo.createGuestAccount(answers: adult);

      expect(second, isA<Ok<AuthTokens>>());
      expect(source.requests, hasLength(1));
      expect(source.onboardings, hasLength(1));
    });

    test('answered already is answered', () async {
      final source = _RecordingDataSource(answersConflict: true);
      final result = await repository(
        source,
      ).createGuestAccount(answers: adult);
      expect(result, isA<Ok<AuthTokens>>());
    });

    test('an email account takes the answers too, when it has them', () async {
      final source = _RecordingDataSource();
      await repository(source).createAccount(
        const NewAccount(
          name: 'Learner',
          email: 'user@example.com',
          password: 'password1',
        ),
        answers: adult,
      );
      expect(source.onboardings, hasLength(1));

      await repository(source).createAccount(
        const NewAccount(
          name: 'Learner',
          email: 'user@example.com',
          password: 'password1',
        ),
      );
      expect(source.onboardings, hasLength(1));
    });

    test('maps errors through the error funnel', () async {
      final result = await repository(
        _RecordingDataSource(fail: true),
      ).createGuestAccount(answers: adult);
      expect((result as Err).failure, isA<NetworkFailure>());
    });
  });
}
