import 'dart:async';

import 'package:englizia/core/config/app_info.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/links/app_store.dart';
import 'package:englizia/core/links/external_link.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/router/app_redirect.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_state.dart';
import 'package:englizia/features/settings/domain/entities/app_version.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_settings_repository.dart';
import '../../helpers/fakes.dart';

/// Opens what it is told to, and records every try.
class FakeLinks implements ExternalLink {
  FakeLinks({this.opens = const {}});

  /// Schemes that open ("market", "https").
  Set<String> opens;
  final tried = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    tried.add(uri);
    return opens.contains(uri.scheme);
  }
}

/// A server's versions for an installed 1.2.0.
const _installed = '1.2.0';
const _tooOld = VersionPolicy(minimum: AppVersion(1, 3));
const _behind = VersionPolicy(recommended: AppVersion(1, 3));
final _storePage = Uri.parse('https://apps.example.com/engleazia');

void main() {
  late FakeSettingsRepository settings;
  late FakeConnectivityService connectivity;
  late FakeLinks links;

  setUp(() {
    settings = FakeSettingsRepository();
    connectivity = FakeConnectivityService();
    links = FakeLinks();
  });

  Future<AppSessionController> session({AuthTokens? tokens}) async {
    SharedPreferences.setMockInitialValues({'app.has_launched': true});
    final session = AppSessionController(
      tokens: FakeTokenStorage(tokens),
      settings: SettingsStorageService(await SharedPreferences.getInstance()),
    );
    await session.bootstrap();
    return session;
  }

  SplashCubit cubit(
    AppSessionController session, {
    String platform = 'android',
  }) => SplashCubit(
    session: session,
    settings: settings,
    connectivity: connectivity,
    app: const AppInfo(version: _installed),
    store: AppStore(
      links,
      packageName: 'com.example.englizia',
      platform: platform,
    ),
  );

  const member = AuthTokens(accessToken: 'a', refreshToken: 'r');

  test('nothing to stop it: the app goes on once loaded', () async {
    final splash = cubit(await session());
    await splash.start();

    expect(splash.state.mode, SplashMode.done);
    expect(splash.state.launch, LaunchStatus.ready);
    expect(splash.state.need, UpdateNeed.none);
  });

  test('waits for the intro the splash plays, never cuts it off', () async {
    final splash = cubit(await session())..introStarted();
    await splash.start();
    expect(splash.state.mode, SplashMode.loading);

    splash.introShown();
    expect(splash.state.mode, SplashMode.done);
  });

  test('waits for the session to be known', () async {
    SharedPreferences.setMockInitialValues({'app.has_launched': true});
    final unknown = AppSessionController(
      tokens: FakeTokenStorage(member),
      settings: SettingsStorageService(await SharedPreferences.getInstance()),
    );
    final splash = cubit(unknown);
    final started = splash.start();
    await pumpEventQueue();
    expect(splash.state.mode, SplashMode.loading);

    await unknown.bootstrap();
    await started;
    expect(splash.state.mode, SplashMode.done);
  });

  group('the update gate', () {
    test('older than the minimum: the update screen, for everyone', () async {
      settings.versions = const Ok(_tooOld);
      for (final tokens in [null, member]) {
        final splash = cubit(await session(tokens: tokens));
        await splash.start();
        expect(splash.state.mode, SplashMode.update);
        expect(splash.state.launch, LaunchStatus.updateRequired);
      }
    });

    test(
      'older than the recommended only: on, with a reminder for home',
      () async {
        settings.versions = const Ok(_behind);
        final splash = cubit(await session(tokens: member));
        await splash.start();

        expect(splash.state.mode, SplashMode.done);
        expect(splash.state.need, UpdateNeed.suggested);
      },
    );

    test(
      'without a connection, the versions kept from an earlier open',
      () async {
        connectivity.online = false;
        settings
          ..versions = const Ok(VersionPolicy.none)
          ..kept = _tooOld;
        final splash = cubit(await session(tokens: member));
        await splash.start();

        expect(splash.state.mode, SplashMode.update);
      },
    );

    test('no connection and nothing kept: nothing stops the app', () async {
      connectivity.online = false;
      settings.versions = const Err(NetworkFailure());
      final splash = cubit(await session(tokens: member));
      await splash.start();

      expect(splash.state.mode, SplashMode.done);
    });

    testWidgets('a server too slow: the kept versions decide', (tester) async {
      final late = Completer<Result<VersionPolicy>>();
      final slow = _SlowSettings(late.future)..kept = _tooOld;
      final splash = SplashCubit(
        session: await tester.runAsync(session) as AppSessionController,
        settings: slow,
        connectivity: connectivity,
        app: const AppInfo(version: _installed),
        store: AppStore(links, packageName: 'x', platform: 'android'),
      );
      unawaited(splash.start());
      await tester.pump(SplashCubit.slowAfter);
      expect(splash.state.slow, isTrue);

      await tester.pump(SplashCubit.versionsWait - SplashCubit.slowAfter);
      expect(splash.state.mode, SplashMode.update);
      expect(splash.state.slow, isFalse);
      unawaited(splash.close());
    });
  });

  group('the store', () {
    test('Google Play\'s app first', () async {
      settings.versions = Ok(
        VersionPolicy(minimum: const AppVersion(2), updateUrl: _storePage),
      );
      links.opens = {'market'};
      final splash = cubit(await session());
      await splash.start();

      await splash.openStore();

      expect(links.tried, [
        Uri.parse('market://details?id=com.example.englizia'),
      ]);
      expect(splash.state.storeFailed, isFalse);
    });

    test('then the server\'s page', () async {
      settings.versions = Ok(
        VersionPolicy(minimum: const AppVersion(2), updateUrl: _storePage),
      );
      links.opens = {'https'};
      final splash = cubit(await session());
      await splash.start();

      await splash.openStore();

      expect(links.tried.last, _storePage);
      expect(splash.state.storeFailed, isFalse);
    });

    test('neither opened: the page to copy, Google Play\'s without the '
        'server\'s', () async {
      settings.versions = const Ok(_tooOld);
      final splash = cubit(await session());
      await splash.start();

      await splash.openStore();

      expect(splash.state.storeFailed, isTrue);
      expect(
        splash.state.storePage,
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.example.englizia',
        ),
      );
      expect(splash.state.mode, SplashMode.update);
    });

    test('iOS knows only the server\'s page', () async {
      settings.versions = const Ok(_tooOld);
      final splash = cubit(await session(), platform: 'ios');
      await splash.start();

      await splash.openStore();

      expect(links.tried, isEmpty);
      expect(splash.state.storeFailed, isTrue);
      expect(splash.state.storePage, isNull);
    });
  });

  group('a first open without a connection', () {
    test('waits for one, signed out only', () async {
      connectivity.online = false;
      final first = cubit(await session());
      await first.start();
      expect(first.state.mode, SplashMode.offline);
      expect(first.state.launch, LaunchStatus.starting);

      final registered = cubit(await session(tokens: member));
      await registered.start();
      expect(registered.state.mode, SplashMode.done);
    });

    testWidgets('a retry that finds none shows it tried, and stays', (
      tester,
    ) async {
      connectivity.online = false;
      final splash = cubit(
        await tester.runAsync(session) as AppSessionController,
      );
      unawaited(splash.start());
      await tester.pump();

      unawaited(splash.retry());
      await tester.pump();
      expect(splash.state.retrying, isTrue);
      await tester.pump(SplashCubit.retryAtLeast);
      expect(splash.state.retrying, isFalse);
      expect(splash.state.mode, SplashMode.offline);
      unawaited(splash.close());
    });

    test('goes on by itself once connected', () async {
      connectivity.online = false;
      final splash = cubit(await session());
      await splash.start();

      connectivity.online = true;
      await pumpEventQueue();

      expect(splash.state.mode, SplashMode.done);
    });
  });
}

/// The server answers only when told to; the phone kept [kept].
class _SlowSettings extends FakeSettingsRepository {
  _SlowSettings(this._answer);

  final Future<Result<VersionPolicy>> _answer;

  @override
  Future<Result<VersionPolicy>> getVersionPolicy({bool keptOnly = false}) =>
      keptOnly ? Future.value(Ok(kept!)) : _answer;
}
