import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/error/provider_exception.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_error_codes.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/features/account/data/datasources/account_remote_data_source.dart';
import 'package:englizia/features/account/data/datasources/google_identity_source.dart';
import 'package:englizia/features/account/data/models/google_sign_in_model.dart';
import 'package:englizia/features/account/data/repositories/account_repository_impl.dart';
import 'package:englizia/features/account/domain/entities/social_session.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fakes.dart';

/// The mock's answer: a `TokenResponse` of a new account.
final _newAccountBody =
    jsonDecode(File(AccountFakeDataSource.registerAsset).readAsStringSync())
        as Map<String, Object?>;

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

/// Google's sheet: gives [token], or is closed (null), or fails.
class _Google implements GoogleIdentitySource {
  _Google({this.token = 'google-id-token', this.error, this.signOutError});

  final String? token;
  final Object? error;
  final Object? signOutError;
  var asked = 0;
  var signOuts = 0;

  @override
  Future<String?> idToken() async {
    asked++;
    if (error case final error?) throw error;
    return token;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    if (signOutError case final error?) throw error;
  }
}

class _Plugin extends Mock implements GoogleSignIn {}

class _Account extends Mock implements GoogleSignInAccount {}

void main() {
  late FakeHttpAdapter adapter;
  String? savedDevice;

  setUp(() => savedDevice = null);

  AccountRepositoryImpl repository(
    FakeResponse Function() answer, {
    GoogleIdentitySource? google,
    FakeTokenStorage? tokens,
    FakeResponse Function(RequestOptions request)? answers,
  }) {
    adapter = FakeHttpAdapter(answers ?? (_) => answer());
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    return AccountRepositoryImpl(
      AccountRemoteDataSourceImpl(ApiClient(dio)),
      tokens: tokens ?? FakeTokenStorage(),
      savedDeviceId: () => savedDevice,
      saveDeviceId: (id) async => savedDevice = id,
      devicePlatform: 'android',
      google: google,
    );
  }

  group('GoogleSignInModel', () {
    test('sends GoogleSignInRequest', () {
      expect(
        GoogleSignInModel.request(
          idToken: 'token',
          deviceId: 'device-1',
          platform: 'ios',
        ),
        {'idToken': 'token', 'deviceId': 'device-1', 'platform': 'ios'},
      );
    });

    test('reads the session and whether the account is new', () {
      final now = DateTime.utc(2026, 11, 12);
      final session = GoogleSignInModel.session(_newAccountBody, now: now);
      expect(session.tokens.kind, AccountKind.member);
      expect(session.isNewAccount, isTrue);

      final data = Map.of(_newAccountBody['data']! as Map<String, Object?>)
        ..remove('isNewUser');
      expect(
        GoogleSignInModel.session({
          ..._newAccountBody,
          'data': data,
        }, now: now).isNewAccount,
        isFalse,
      );
    });
  });

  group('signing in', () {
    test('POST /api/v1/auth/google with Google\'s token, no session token, '
        'and keeps the device id', () async {
      final result = await repository(
        () => FakeResponse(200, body: _newAccountBody),
        google: _Google(),
      ).signInWithGoogle();

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/auth/google');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.data, {
        'idToken': 'google-id-token',
        'deviceId': null,
        'platform': 'android',
      });
      final session = (result as Ok<SocialSession?>).value!;
      expect(session.isNewAccount, isTrue);
      expect(savedDevice, session.tokens.deviceId);
    });

    test('the sheet closed: nothing is sent, nothing failed', () async {
      final result = await repository(
        () => FakeResponse(200, body: _newAccountBody),
        google: _Google(token: null),
      ).signInWithGoogle();

      expect((result as Ok<SocialSession?>).value, isNull);
      expect(adapter.requests, isEmpty);
    });

    test('Google failing on the phone is a provider failure', () async {
      final result = await repository(
        () => FakeResponse(200, body: _newAccountBody),
        google: _Google(error: const ProviderException('no Play services')),
      ).signInWithGoogle();

      expect((result as Err).failure, isA<ProviderFailure>());
      expect(adapter.requests, isEmpty);
    });

    test('a build without Google is a provider failure', () async {
      final result = await repository(
        () => FakeResponse(200, body: _newAccountBody),
      ).signInWithGoogle();
      expect((result as Err).failure, isA<ProviderFailure>());
    });

    test('a token the server refuses is a provider failure, not a session '
        'that ended', () async {
      final result = await repository(
        () => FakeResponse(401, body: apiFixture('auth_google_token_invalid')),
        google: _Google(),
      ).signInWithGoogle();

      final failure = (result as Err).failure;
      expect(failure, isA<ProviderFailure>());
      expect(failure.code, ApiErrorCodes.googleTokenInvalid);
      expect(savedDevice, isNull);
    });

    test('an empty token is the server\'s validation error', () async {
      final result = await repository(
        () => FakeResponse(
          400,
          body: apiFixture('auth_google_validation_failed'),
        ),
        google: _Google(token: ''),
      ).signInWithGoogle();

      final failure = (result as Err).failure as ValidationFailure;
      expect(failure.firstCodeFor('idToken'), 'not_empty');
    });

    for (final code in [
      ApiErrorCodes.emailTaken,
      ApiErrorCodes.externalLoginConflict,
    ]) {
      test('409 $code keeps its code', () async {
        final result = await repository(
          () => FakeResponse(
            409,
            body: {
              'statusCode': 409,
              'data': null,
              'error': {'code': code, 'details': null},
            },
          ),
          google: _Google(),
        ).signInWithGoogle();

        final failure = (result as Err).failure;
        expect(failure, isA<ConflictFailure>());
        expect(failure.code, code);
      });
    }

    test('403 for a disabled account keeps its code', () async {
      final result = await repository(
        () => const FakeResponse(
          403,
          body: {
            'statusCode': 403,
            'data': null,
            'error': {'code': ApiErrorCodes.accountDisabled, 'details': null},
          },
        ),
        google: _Google(),
      ).signInWithGoogle();

      final failure = (result as Err).failure;
      expect(failure, isA<ForbiddenFailure>());
      expect(failure.code, ApiErrorCodes.accountDisabled);
    });
  });

  group('a new account, a guest', () {
    const answers = OnboardingPath(
      audience: TrackAudience.self,
      trackId: 'trk_general',
      dailyGoalMinutes: 10,
    );
    const guest = AuthTokens(
      accessToken: 'guest-access',
      refreshToken: 'guest-refresh',
      kind: AccountKind.guest,
    );
    const conflict = FakeResponse(
      409,
      body: {
        'statusCode': 409,
        'data': null,
        'error': {'code': 'auth.external_login_conflict', 'details': null},
      },
    );

    test('a new Google account takes the answers with its own token', () async {
      final repo = repository(
        () => const FakeResponse(200),
        google: _Google(),
        answers: (request) => request.path == '/api/v1/auth/google'
            ? FakeResponse(200, body: _newAccountBody)
            : const FakeResponse(200),
      );
      final result = await repo.signInWithGoogle(answers: answers);

      expect((result as Ok<SocialSession?>).value!.isNewAccount, isTrue);
      final onboarding = adapter.requests.last;
      expect(onboarding.path, '/api/v1/app/me/onboarding');
      expect(
        onboarding.headers['Authorization'],
        'Bearer mock-member-access-token',
      );
      expect((onboarding.data! as Map)['trackId'], 'trk_general');
    });

    test('an account that existed keeps its own plan', () async {
      final data = Map.of(_newAccountBody['data']! as Map<String, Object?>)
        ..['isNewUser'] = false;
      await repository(
        () => FakeResponse(200, body: {..._newAccountBody, 'data': data}),
        google: _Google(),
      ).signInWithGoogle(answers: answers);
      expect(adapter.requests.single.path, '/api/v1/auth/google');
    });

    test(
      'answers that failed are sent again: one sheet, one account',
      () async {
        var onboardings = 0;
        final google = _Google();
        final repo = repository(
          () => const FakeResponse(200),
          google: google,
          answers: (request) {
            if (request.path == '/api/v1/auth/google') {
              return FakeResponse(200, body: _newAccountBody);
            }
            return ++onboardings == 1
                ? const FakeResponse(500)
                : const FakeResponse(200);
          },
        );

        expect(
          await repo.signInWithGoogle(answers: answers),
          isA<Err<SocialSession?>>(),
        );
        expect(
          await repo.signInWithGoogle(answers: answers),
          isA<Ok<SocialSession?>>(),
        );
        expect(google.asked, 1);
        expect(
          adapter.requests.where((r) => r.path == '/api/v1/auth/google'),
          hasLength(1),
        );
      },
    );

    test('the guest account takes Google and stays', () async {
      final result = await repository(
        () => FakeResponse(200, body: apiFixture('app_me_guest')),
        google: _Google(),
        tokens: FakeTokenStorage(guest),
      ).signInWithGoogle();

      final request = adapter.requests.single;
      expect(request.path, '/api/v1/auth/guest/upgrade/google');
      expect(request.data, {'idToken': 'google-id-token'});
      final session = (result as Ok<SocialSession?>).value!;
      expect(session.keptGuest, isTrue);
      expect(session.tokens.kind, AccountKind.member);
      expect(session.tokens.accessToken, 'guest-access');
    });

    test('a Google account that has one already is signed in to', () async {
      final result = await repository(
        () => const FakeResponse(200),
        google: _Google(),
        tokens: FakeTokenStorage(guest),
        answers: (request) => request.path == '/api/v1/auth/google'
            ? FakeResponse(200, body: _newAccountBody)
            : conflict,
      ).signInWithGoogle();

      expect(adapter.requests.map((r) => r.path), [
        '/api/v1/auth/guest/upgrade/google',
        '/api/v1/auth/google',
      ]);
      expect((result as Ok<SocialSession?>).value!.keptGuest, isFalse);
    });
  });

  group('signing out', () {
    const session = AuthTokens(accessToken: 'a', refreshToken: 'r');

    test('forgets Google\'s account too', () async {
      final google = _Google();
      await repository(
        () => const FakeResponse(200),
        google: google,
        tokens: FakeTokenStorage(session),
      ).logOut();

      expect(google.signOuts, 1);
      expect(adapter.requests.single.path, '/api/v1/auth/logout');
    });

    test('never depends on Google', () async {
      final result = await repository(
        () => const FakeResponse(200),
        google: _Google(signOutError: StateError('no Play services')),
        tokens: FakeTokenStorage(session),
      ).logOut();

      expect(result, isA<Ok<void>>());
      expect(adapter.requests, hasLength(1));
    });
  });

  test('mock mode: any Google account is a new learner\'s', () async {
    final repo = AccountRepositoryImpl(
      AccountFakeDataSource(_DiskBundle(), latency: Duration.zero),
      tokens: FakeTokenStorage(),
      savedDeviceId: () => null,
      saveDeviceId: (_) async {},
      devicePlatform: null,
      google: const GoogleIdentityFake(),
    );
    final result = await repo.signInWithGoogle();
    expect((result as Ok<SocialSession?>).value!.isNewAccount, isTrue);
  });

  group('Google\'s sheet', () {
    late _Plugin plugin;

    setUp(() {
      plugin = _Plugin();
      when(
        () => plugin.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
        ),
      ).thenAnswer((_) async {});
      when(plugin.supportsAuthenticate).thenReturn(true);
      when(plugin.signOut).thenAnswer((_) async {});
    });

    GoogleIdentitySourceImpl source({String serverClientId = 'server-id'}) =>
        GoogleIdentitySourceImpl(
          plugin,
          serverClientId: serverClientId,
          clientId: 'ios-id',
        );

    void answerWith(String? idToken) {
      final account = _Account();
      when(
        () => account.authentication,
      ).thenReturn(GoogleSignInAuthentication(idToken: idToken));
      when(plugin.authenticate).thenAnswer((_) async => account);
    }

    test(
      'asks for a token made for the server\'s client, set up once',
      () async {
        answerWith('id-token');
        final google = source();

        expect(await google.idToken(), 'id-token');
        expect(await google.idToken(), 'id-token');

        verify(
          () => plugin.initialize(
            clientId: 'ios-id',
            serverClientId: 'server-id',
          ),
        ).called(1);
      },
    );

    test('closed by the learner: no token, no failure', () async {
      when(plugin.authenticate).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );
      expect(await source().idToken(), isNull);
    });

    for (final code in [
      GoogleSignInExceptionCode.clientConfigurationError,
      GoogleSignInExceptionCode.providerConfigurationError,
      GoogleSignInExceptionCode.uiUnavailable,
      GoogleSignInExceptionCode.interrupted,
      GoogleSignInExceptionCode.unknownError,
    ]) {
      test('${code.name} is a provider failure', () {
        when(
          plugin.authenticate,
        ).thenThrow(GoogleSignInException(code: code, description: 'why'));
        expect(source().idToken(), throwsA(isA<ProviderException>()));
      });
    }

    test('no token from Google is a provider failure', () {
      answerWith(null);
      expect(source().idToken(), throwsA(isA<ProviderException>()));
    });

    test('a phone that cannot ask is a provider failure', () {
      when(plugin.supportsAuthenticate).thenReturn(false);
      expect(source().idToken(), throwsA(isA<ProviderException>()));
      verifyNever(plugin.authenticate);
    });

    test('a build with no server client never opens the sheet', () async {
      final google = source(serverClientId: '');

      await expectLater(google.idToken(), throwsA(isA<ProviderException>()));
      await google.signOut();

      verifyNever(
        () => plugin.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
        ),
      );
      verifyNever(plugin.signOut);
    });

    test('a setup that failed is tried again the next time', () async {
      var tries = 0;
      when(
        () => plugin.initialize(
          clientId: any(named: 'clientId'),
          serverClientId: any(named: 'serverClientId'),
        ),
      ).thenAnswer((_) async {
        if (++tries == 1) {
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.providerConfigurationError,
          );
        }
      });
      answerWith('id-token');
      final google = source();

      await expectLater(google.idToken(), throwsA(isA<ProviderException>()));
      expect(await google.idToken(), 'id-token');
    });

    test('signing out forgets the account', () async {
      await source().signOut();
      verify(plugin.signOut).called(1);
    });
  });
}
