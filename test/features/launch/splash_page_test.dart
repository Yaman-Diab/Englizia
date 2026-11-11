import 'package:bloc_test/bloc_test.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_state.dart';
import 'package:englizia/features/launch/presentation/splash/pages/splash_page.dart';
import 'package:englizia/features/launch/presentation/splash/widgets/loading_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class _Splash extends MockCubit<SplashState> implements SplashCubit {}

final _page = Uri.parse(
  'https://play.google.com/store/apps/details?id=com.example.englizia',
);

void main() {
  setUpAll(initLocalizationForTests);

  late _Splash cubit;

  setUp(() {
    cubit = _Splash();
    when(cubit.retry).thenAnswer((_) async {});
    when(cubit.openStore).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester,
    SplashState state, {
    LayoutCase? layout,
  }) async {
    whenListen(cubit, const Stream<SplashState>.empty(), initialState: state);
    await tester.pumpLocalized(
      BlocProvider<SplashCubit>.value(value: cubit, child: const SplashPage()),
      locale: layout?.locale ?? const Locale('ar'),
      size: layout?.size ?? defaultViewport,
      themeMode: layout?.themeMode ?? ThemeMode.light,
    );
    await tester.pump(SplashIntro.settled + AppMotion.slow);
  }

  testWidgets('plays its intro, then tells the opening', (tester) async {
    await pump(tester, const SplashState());

    verify(cubit.introStarted).called(1);
    verify(cubit.introShown).called(1);
    expect(find.text('Engleazia'), findsOneWidget);
    expect(find.byType(LoadingDots), findsNothing);
  });

  testWidgets('under reduce motion, nothing to wait for', (tester) async {
    whenListen(
      cubit,
      const Stream<SplashState>.empty(),
      initialState: const SplashState(),
    );
    await tester.pumpLocalized(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: BlocProvider<SplashCubit>.value(
          value: cubit,
          child: const SplashPage(),
        ),
      ),
    );

    verifyNever(cubit.introStarted);
  });

  testWidgets('a slow load says so', (tester) async {
    await pump(tester, const SplashState(slow: true));

    expect(find.byType(LoadingDots), findsOneWidget);
    expect(find.text('جاري التحميل…'), findsOneWidget);
  });

  testWidgets('a first open without a connection: the notice and a retry', (
    tester,
  ) async {
    await pump(tester, const SplashState(mode: SplashMode.offline));

    expect(
      find.text('نحتاج الاتصال بالإنترنت في المرة الأولى'),
      findsOneWidget,
    );
    await tester.tap(find.text('إعادة المحاولة'));
    verify(cubit.retry).called(1);
  });

  testWidgets('too old: the update screen, with no way past it', (
    tester,
  ) async {
    await pump(tester, const SplashState(mode: SplashMode.update));

    expect(find.text('نسخة جديدة متاحة'), findsOneWidget);
    expect(find.text('حدّث Engleazia لتتابع التعلّم.'), findsOneWidget);
    // The title takes the name's place.
    expect(find.text('Engleazia'), findsNothing);
    expect(find.text('إعادة المحاولة'), findsNothing);

    await tester.tap(find.text('تحديث الآن'));
    verify(cubit.openStore).called(1);
  });

  testWidgets('no store opened: the page to copy, «نُسخ» for a moment', (
    tester,
  ) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(
      tester,
      SplashState(mode: SplashMode.update, storeFailed: true, storePage: _page),
    );

    expect(
      find.text('لم يُفتح المتجر. انسخ الرابط وافتحه في المتصفح.'),
      findsOneWidget,
    );
    expect(find.text(_page.toString()), findsOneWidget);
    // Still there to try again.
    expect(find.text('تحديث الآن'), findsOneWidget);

    await tester.tap(find.text('نسخ'));
    await tester.pump();
    expect(copied.single, {'text': _page.toString()});
    expect(find.text('نُسخ'), findsOneWidget);

    await tester.pump(AppMotion.copiedHold);
    expect(find.text('نسخ'), findsOneWidget);
  });

  testWidgets('no page known (iOS without the server\'s): the note alone', (
    tester,
  ) async {
    await pump(
      tester,
      const SplashState(mode: SplashMode.update, storeFailed: true),
    );

    expect(find.text('نسخ'), findsNothing);
    expect(
      find.text('لم يُفتح المتجر. افتحه وابحث عن Engleazia.'),
      findsOneWidget,
    );
  });

  for (final state in [
    const SplashState(slow: true),
    const SplashState(mode: SplashMode.offline, retrying: true),
    SplashState(mode: SplashMode.update, storeFailed: true, storePage: _page),
  ]) {
    testLayouts('${state.mode.name} fits', (tester, layout) async {
      await pump(tester, state, layout: layout);
      expect(tester.takeException(), isNull);
    });
  }
}
