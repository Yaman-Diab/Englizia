import 'package:dio/dio.dart';
import 'package:englizia/app/app.dart';
import 'package:englizia/app/di.dart';
import 'package:englizia/app/shell/foundation_page.dart';
import 'package:englizia/app/shell/splash_page.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_http_adapter.dart';
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
        'boots from splash to home (${locale.languageCode}, ${size.width.toInt()}dp)',
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
          expect(find.byType(FoundationPage), findsOneWidget);
          final expectedName = locale == AppLocales.arabic
              ? 'إنجليزيا'
              : 'Engleazia';
          expect(find.text(expectedName), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.byType(FoundationPage))),
            locale == AppLocales.arabic ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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
