import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/app/app.dart';
import 'package:englizia/app/di.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/shell/foundation_page.dart';
import 'package:englizia/app/shell/splash_page.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/network/connectivity_service.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/account/presentation/forgot_password/pages/forgot_password_page.dart';
import 'package:englizia/features/account/presentation/new_password/pages/new_password_page.dart';
import 'package:englizia/features/account/presentation/password_changed/pages/password_changed_page.dart';
import 'package:englizia/features/account/presentation/sign_in/pages/sign_in_page.dart';
import 'package:englizia/features/account/presentation/sign_up/pages/sign_up_page.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/preparing/pages/preparing_page.dart';
import 'package:englizia/features/onboarding/presentation/preparing/preparing_args.dart';
import 'package:englizia/features/onboarding/presentation/welcome/pages/welcome_page.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';
import 'package:englizia/features/placement/presentation/intro/pages/placement_intro_page.dart';
import 'package:englizia/features/placement/presentation/result/pages/placement_result_page.dart';
import 'package:englizia/features/placement/presentation/test/pages/placement_test_page.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_accounts.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_placement_repository.dart';
import '../helpers/fake_settings_repository.dart';
import '../helpers/fake_track_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/platform_mocks.dart';
import '../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  setUp(() async {
    mockPlatformPlugins();
    await configureDependencies();
  });
  tearDown(() => sl.reset());

  for (final locale in AppLocales.supported) {
    for (final size in [defaultViewport, narrowViewport]) {
      testWidgets(
        'a new visitor boots from splash to welcome (${locale.languageCode}, ${size.width.toInt()}dp)',
        (tester) async {
          tester.setViewport(size);
          await tester.pumpWidget(
            localizedTestRoot(locale: locale, child: const App()),
          );
          await tester.pumpUntilLocalized();
          expect(find.byType(SplashPage), findsOneWidget);

          await sl<AppSessionController>().bootstrap();
          await tester.pumpUntilLocalized();
          // Let the page transition finish so the splash leaves the tree.
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(SplashPage), findsNothing);
          expect(find.byType(WelcomePage), findsOneWidget);
          final expectedName = locale == AppLocales.arabic
              ? 'إنجليزيا'
              : 'Engleazia';
          expect(find.text(expectedName), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.byType(WelcomePage))),
            locale == AppLocales.arabic ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

  group('the link in a recovery email', () {
    late FakeAccountRepository accounts;

    setUp(() {
      accounts = FakeAccountRepository();
      sl
        ..unregister<AccountRepository>()
        ..registerLazySingleton<AccountRepository>(() => accounts);
    });

    testWidgets('opens the app on its screen, through the session check', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/reset-password?token=t-1&email=user@example.com';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      expect(find.byType(SplashPage), findsNothing);
      expect(find.byType(NewPasswordPage), findsOneWidget);

      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NewPasswordPage), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(accounts.linkChecks, ['t-1']);
    });

    testWidgets('reaches the app when it is already open', (tester) async {
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.navigation.name,
        SystemChannels.navigation.codec.encodeMethodCall(
          const MethodCall('pushRouteInformation', {
            'location': 'https://engleazia.com/reset-password?token=t-2',
            'state': null,
          }),
        ),
        (_) {},
      );
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NewPasswordPage), findsOneWidget);
      expect(accounts.linkChecks, ['t-2']);
    });

    testWidgets('closing goes where the session belongs', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/reset-password?token=t-1';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('common_close'.tr()));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WelcomePage), findsOneWidget);
    });

    testWidgets('expired: a new link starts from its email, and Google is '
        'on sign-in', (tester) async {
      accounts = FakeAccountRepository(
        linkResults: const [Err(LinkExpiredFailure())],
      );
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/reset-password?token=t-1&email=user@example.com';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('new_password_new_link'.tr()));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);

      await tester.tap(find.text('forgot_google'.tr()));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SignInPage), findsOneWidget);
    });

    testWidgets('saving goes on to the next step', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/reset-password?token=t-1';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'password1');
      await tester.pump();
      await tester.tap(find.text('new_password_submit'.tr()));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NewPasswordPage), findsNothing);
      expect(find.byType(PasswordChangedPage), findsOneWidget);
      expect(find.text('password_changed_signed_in'.tr()), findsOneWidget);
      expect(sl<AppSessionController>().status, SessionStatus.member);

      await tester.tap(find.text('password_changed_continue'.tr()));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FoundationPage), findsOneWidget);
    });

    testWidgets('no session: sign in by hand, with the email there', (
      tester,
    ) async {
      accounts = FakeAccountRepository(newPasswordResults: const [Ok(null)]);
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/reset-password?token=t-1&email=user@example.com';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'password1');
      await tester.pump();
      await tester.tap(find.text('new_password_submit'.tr()));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PasswordChangedPage), findsOneWidget);
      expect(find.text('password_changed_sign_in'.tr()), findsOneWidget);
      expect(sl<AppSessionController>().status, SessionStatus.signedOut);

      await tester.tap(find.byType(AppButton));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('no session ends this phone\'s member session', (tester) async {
      accounts = FakeAccountRepository(newPasswordResults: const [Ok(null)]);
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/reset-password?token=t-1';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await sl<AppSessionController>().signIn(tokens);
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'password1');
      await tester.pump();
      await tester.tap(find.text('new_password_submit'.tr()));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(PasswordChangedPage), findsOneWidget);
      expect(sl<AppSessionController>().status, SessionStatus.signedOut);
    });

    testWidgets('the system\'s back leaves for home, not the password', (
      tester,
    ) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/reset-password?token=t-1';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'password1');
      await tester.pump();
      await tester.tap(find.text('new_password_submit'.tr()));
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 2));

      await tester.binding.handlePopRoute();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PasswordChangedPage), findsNothing);
      expect(find.byType(NewPasswordPage), findsNothing);
      expect(find.byType(FoundationPage), findsOneWidget);
    });
  });

  testWidgets('signing in leaves welcome for home', (tester) async {
    await tester.pumpWidget(
      localizedTestRoot(locale: AppLocales.arabic, child: const App()),
    );
    await tester.pumpUntilLocalized();
    await sl<AppSessionController>().bootstrap();
    await tester.pumpUntilLocalized();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WelcomePage), findsOneWidget);

    await sl<AppSessionController>().signIn(tokens);
    await tester.pumpUntilLocalized();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(FoundationPage), findsOneWidget);
  });

  testWidgets('a guest account leaves welcome for home too', (tester) async {
    await tester.pumpWidget(
      localizedTestRoot(locale: AppLocales.arabic, child: const App()),
    );
    await tester.pumpUntilLocalized();
    await sl<AppSessionController>().bootstrap();
    await tester.pumpUntilLocalized();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WelcomePage), findsOneWidget);

    await sl<AppSessionController>().signIn(
      const AuthTokens(
        accessToken: 'g',
        refreshToken: 'r',
        kind: AccountKind.guest,
      ),
    );
    await tester.pumpUntilLocalized();
    await tester.pump(const Duration(seconds: 1));

    expect(sl<AppSessionController>().status, SessionStatus.guest);
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(FoundationPage), findsOneWidget);
  });

  testWidgets(
    'a new account goes through preparing, which starts its session',
    (tester) async {
      sl
        ..unregister<TrackRepository>()
        ..registerLazySingleton<TrackRepository>(FakeTrackRepository.new)
        ..unregister<SettingsRepository>()
        ..registerLazySingleton<SettingsRepository>(FakeSettingsRepository.new);
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      GoRouter.of(tester.element(find.byType(WelcomePage))).go(
        AppRoutes.onboardingPreparing,
        extra: const PreparingArgs(
          path: OnboardingPath(audience: TrackAudience.self),
          session: tokens,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The session started, and preparing stayed open.
      expect(sl<AppSessionController>().status, SessionStatus.member);
      expect(find.byType(PreparingPage), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FoundationPage), findsOneWidget);
    },
  );

  group('the placement test\'s intro', () {
    setUp(() {
      sl
        ..unregister<TrackRepository>()
        ..registerLazySingleton<TrackRepository>(FakeTrackRepository.new)
        ..unregister<SettingsRepository>()
        ..registerLazySingleton<SettingsRepository>(FakeSettingsRepository.new)
        ..unregister<PlacementRepository>()
        ..registerLazySingleton<PlacementRepository>(
          FakePlacementRepository.new,
        )
        ..unregister<ConnectivityService>()
        ..registerLazySingleton<ConnectivityService>(
          FakeConnectivityService.new,
        );
    });

    Future<void> boot(WidgetTester tester) async {
      await tester.pumpWidget(
        localizedTestRoot(locale: AppLocales.arabic, child: const App()),
      );
      await tester.pumpUntilLocalized();
      await sl<AppSessionController>().bootstrap();
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('opens for a guest, who has a session', (tester) async {
      await boot(tester);
      await sl<AppSessionController>().signIn(guestTokens);
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));

      GoRouter.of(
        tester.element(find.byType(FoundationPage)),
      ).go(AppRoutes.onboardingPlacement);
      await tester.pump();
      await tester.settleEntrance(const Duration(seconds: 2));
      expect(find.byType(PlacementIntroPage), findsOneWidget);
      expect(find.text('preparing_start_test'.tr()), findsOneWidget);
    });

    testWidgets('a guest reaches it from preparing', (tester) async {
      await boot(tester);
      GoRouter.of(tester.element(find.byType(WelcomePage))).go(
        AppRoutes.onboardingPreparing,
        extra: const PreparingArgs(
          path: OnboardingPath(
            audience: TrackAudience.self,
            placementTest: true,
          ),
          session: guestTokens,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(sl<AppSessionController>().status, SessionStatus.guest);

      await tester.tap(find.text('preparing_start_test'.tr()));
      await tester.pump();
      await tester.settleEntrance(const Duration(seconds: 2));
      expect(find.byType(PlacementIntroPage), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
    });

    testWidgets('a guest\'s skip goes home', (tester) async {
      await boot(tester);
      await sl<AppSessionController>().signIn(guestTokens);
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      GoRouter.of(
        tester.element(find.byType(FoundationPage)),
      ).go(AppRoutes.onboardingPlacement);
      await tester.pump();
      await tester.settleEntrance(const Duration(seconds: 2));

      await tester.tap(find.text('placement_skip_plain'.tr()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FoundationPage), findsOneWidget);
    });

    testWidgets('a whole test: questions, then the result, then home', (
      tester,
    ) async {
      await boot(tester);
      await sl<AppSessionController>().signIn(guestTokens);
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      GoRouter.of(
        tester.element(find.byType(FoundationPage)),
      ).go(AppRoutes.placementQuestions);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlacementTestPage), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('placement_dont_know'.tr()));
        await tester.pump();
        await tester.tap(find.text('placement_next'.tr()));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      // The test is gone from the stack.
      expect(find.byType(PlacementTestPage), findsNothing);
      expect(find.byType(PlacementResultPage), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(FoundationPage), findsOneWidget);
      expect(find.byType(PlacementResultPage), findsNothing);
    });

    testWidgets('the result with no attempt to show goes home', (tester) async {
      await boot(tester);
      await sl<AppSessionController>().signIn(guestTokens);
      await tester.pumpUntilLocalized();
      await tester.pump(const Duration(seconds: 1));
      GoRouter.of(
        tester.element(find.byType(FoundationPage)),
      ).go(AppRoutes.placementResult);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlacementResultPage), findsNothing);
      expect(find.byType(FoundationPage), findsOneWidget);
    });

    testWidgets('with no session, it sends to welcome', (tester) async {
      await boot(tester);
      GoRouter.of(
        tester.element(find.byType(WelcomePage)),
      ).go(AppRoutes.onboardingPlacement);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(PlacementIntroPage), findsNothing);
      expect(find.byType(WelcomePage), findsOneWidget);
    });
  });

  testWidgets('a guest who creates an account keeps it and stays home', (
    tester,
  ) async {
    final accounts = FakeAccountRepository();
    sl
      ..unregister<AccountRepository>()
      ..registerLazySingleton<AccountRepository>(() => accounts);
    // Tall enough for the whole temporary home, account card included.
    tester.setViewport(const Size(400, 1400));
    await tester.pumpWidget(
      localizedTestRoot(locale: AppLocales.arabic, child: const App()),
    );
    await tester.pumpUntilLocalized();
    await sl<AppSessionController>().bootstrap();
    await sl<AppSessionController>().signIn(guestTokens);
    await tester.pumpUntilLocalized();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('account_guest_create'.tr()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SignUpPage), findsOneWidget);
    expect(find.text('account_upgrade_subtitle'.tr()), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Learner');
    await tester.enterText(fields.at(1), 'user@example.com');
    await tester.enterText(fields.at(2), 'password1');
    await tester.pump();
    await tester.tap(find.text('account_create_submit'.tr()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(accounts.upgrades, hasLength(1));
    expect(accounts.accounts, isEmpty);
    expect(sl<AppSessionController>().status, SessionStatus.member);
    expect(find.byType(FoundationPage), findsOneWidget);
    expect(find.byType(PreparingPage), findsNothing);
  });

  testWidgets('signing in from welcome goes home as a member', (tester) async {
    final accounts = FakeAccountRepository();
    sl
      ..unregister<AccountRepository>()
      ..registerLazySingleton<AccountRepository>(() => accounts);
    await tester.pumpWidget(
      localizedTestRoot(locale: AppLocales.arabic, child: const App()),
    );
    await tester.pumpUntilLocalized();
    await sl<AppSessionController>().bootstrap();
    await tester.pumpUntilLocalized();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('welcome_have_account'.tr()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SignInPage), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'user@example.com');
    await tester.enterText(fields.at(1), 'password1');
    await tester.pump();
    await tester.tap(find.text('sign_in_submit'.tr()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(accounts.signIns.single, ('user@example.com', 'password1'));
    expect(sl<AppSessionController>().status, SessionStatus.member);
    expect(find.byType(FoundationPage), findsOneWidget);
  });

  testWidgets('preparing without its arguments goes elsewhere', (tester) async {
    await tester.pumpWidget(
      localizedTestRoot(locale: AppLocales.arabic, child: const App()),
    );
    await tester.pumpUntilLocalized();
    await sl<AppSessionController>().bootstrap();
    await tester.pumpUntilLocalized();
    await tester.pump(const Duration(seconds: 1));

    GoRouter.of(
      tester.element(find.byType(WelcomePage)),
    ).go(AppRoutes.onboardingPreparing);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PreparingPage), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('switching the language updates Accept-Language', (tester) async {
    /// Accept-Language as sent by the app's own Dio (DI-registered interceptors).
    Future<Object?> sentLanguage() async {
      final adapter = FakeHttpAdapter((_) => const FakeResponse(200));
      sl<Dio>().httpClientAdapter = adapter;
      await tester.runAsync(
        () => sl<Dio>().get<Object?>('https://api.test/ping'),
      );
      return adapter.requests.single.headers['Accept-Language'];
    }

    await tester.pumpWidget(
      localizedTestRoot(locale: AppLocales.arabic, child: const App()),
    );
    await tester.pumpUntilLocalized();
    await sl<AppSessionController>().bootstrap();
    await sl<AppSessionController>().signIn(tokens);
    await tester.pumpUntilLocalized();
    await tester.pump(const Duration(seconds: 1));
    expect(await sentLanguage(), 'ar');

    await tester.tap(find.text('English'));
    await tester.pumpUntilLocalized();

    expect(find.text('Engleazia'), findsOneWidget);
    expect(sl<CurrentLanguage>().code, 'en');
    expect(await sentLanguage(), 'en');
  });

  testWidgets('home has no undersized or unlabeled tap targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(
      BlocProvider(
        create: (_) => sl<SettingsCubit>(),
        child: const FoundationPage(),
      ),
      size: narrowViewport,
    );

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
