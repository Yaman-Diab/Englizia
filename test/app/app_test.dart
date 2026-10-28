import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/app/app.dart';
import 'package:englizia/app/di.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/shell/foundation_page.dart';
import 'package:englizia/app/shell/splash_page.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/session/auth_tokens.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/features/account/domain/repositories/account_repository.dart';
import 'package:englizia/features/account/presentation/sign_up/pages/sign_up_page.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/preparing/pages/preparing_page.dart';
import 'package:englizia/features/onboarding/presentation/preparing/preparing_args.dart';
import 'package:englizia/features/onboarding/presentation/welcome/pages/welcome_page.dart';
import 'package:englizia/features/settings/domain/repositories/settings_repository.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/repositories/track_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_accounts.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_settings_repository.dart';
import '../helpers/fake_track_repository.dart';
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
