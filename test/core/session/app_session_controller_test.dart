import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

  Future<SettingsStorageService> settings({
    required bool launchedBefore,
  }) async {
    SharedPreferences.setMockInitialValues({
      'app.has_launched': launchedBefore,
    });
    return SettingsStorageService(await SharedPreferences.getInstance());
  }

  test('a fresh install drops tokens left in the keystore', () async {
    final storage = FakeTokenStorage(tokens);
    final session = AppSessionController(
      tokens: storage,
      settings: await settings(launchedBefore: false),
    );

    await session.bootstrap();

    expect(session.status, SessionStatus.signedOut);
    expect(storage.clearCount, 1);
  });

  test('restores a stored session', () async {
    final session = AppSessionController(
      tokens: FakeTokenStorage(tokens),
      settings: await settings(launchedBefore: true),
    );

    await session.bootstrap();

    expect(session.status, SessionStatus.member);
  });

  test('falls back to signed out when storage fails', () async {
    final session = AppSessionController(
      tokens: FakeTokenStorage(tokens)..throwOnRead = true,
      settings: await settings(launchedBefore: true),
    );

    await session.bootstrap();

    expect(session.status, SessionStatus.signedOut);
  });

  test('a guest account restores as a guest', () async {
    final session = AppSessionController(
      tokens: FakeTokenStorage(
        const AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          kind: AccountKind.guest,
        ),
      ),
      settings: await settings(launchedBefore: true),
    );

    await session.bootstrap();

    expect(session.status, SessionStatus.guest);
    expect(session.hasSession, isTrue);
  });

  test('signing in takes the status the tokens carry', () async {
    final session = AppSessionController(
      tokens: FakeTokenStorage(),
      settings: await settings(launchedBefore: true),
    );
    await session.bootstrap();
    expect(session.hasSession, isFalse);

    await session.signIn(
      const AuthTokens(
        accessToken: 'g',
        refreshToken: 'r',
        kind: AccountKind.guest,
      ),
    );
    expect(session.status, SessionStatus.guest);

    await session.signIn(tokens);
    expect(session.status, SessionStatus.member);

    await session.signOut();
    expect(session.status, SessionStatus.signedOut);
  });

  test('parallel expiries sign out once and notify listeners', () async {
    final storage = FakeTokenStorage(tokens);
    final session = AppSessionController(
      tokens: storage,
      settings: await settings(launchedBefore: true),
    );
    await session.bootstrap();
    var notifications = 0;
    session.addListener(() => notifications++);

    await Future.wait([session.expire(), session.expire(), session.expire()]);

    expect(session.status, SessionStatus.signedOut);
    expect(storage.clearCount, 1);
    expect(notifications, 1);
  });

  group('what belongs to the account', () {
    test('starting or ending a session forgets the placement status', () async {
      final saved = await settings(launchedBefore: true);
      final session = AppSessionController(
        tokens: FakeTokenStorage(),
        settings: saved,
      );

      await saved.setPlacementStatus('{}');
      await session.signIn(
        const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
      expect(saved.placementStatus, isNull);

      await saved.setPlacementStatus('{}');
      await session.signOut();
      expect(saved.placementStatus, isNull);
    });
  });
}
