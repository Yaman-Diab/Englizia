import 'package:bloc_test/bloc_test.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_state.dart';
import 'package:englizia/features/launch/presentation/update_reminder/update_reminder.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class _Splash extends MockCubit<SplashState> implements SplashCubit {}

void main() {
  setUpAll(initLocalizationForTests);

  late _Splash splash;
  late UpdateReminder reminder;
  var today = DateTime(2026, 11, 10, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    reminder = UpdateReminder(
      SettingsStorageService(await SharedPreferences.getInstance()),
      now: () => today,
    );
    splash = _Splash();
    when(splash.openStore).thenAnswer((_) async {});
  });

  test('once a day, from the day it showed', () async {
    today = DateTime(2026, 11, 10, 9);
    expect(reminder.dueToday, isTrue);
    await reminder.shownToday();
    expect(reminder.dueToday, isFalse);

    today = DateTime(2026, 11, 10, 23, 59);
    expect(reminder.dueToday, isFalse);
    today = DateTime(2026, 11, 11, 0, 1);
    expect(reminder.dueToday, isTrue);
  });

  Future<void> pumpHome(WidgetTester tester, UpdateNeed need) async {
    whenListen(
      splash,
      const Stream<SplashState>.empty(),
      initialState: SplashState(mode: SplashMode.done, need: need),
    );
    await _openHome(tester, splash, reminder);
  }

  testWidgets('a newer version: the sheet, and «تحديث» opens the store', (
    tester,
  ) async {
    today = DateTime(2026, 11, 10, 9);
    await pumpHome(tester, UpdateNeed.suggested);

    expect(find.text('نسخة أحدث متاحة'), findsOneWidget);
    expect(
      find.text('حدّث Engleazia لتحصل على آخر التحسينات. تقدّمك محفوظ.'),
      findsOneWidget,
    );
    await tester.tap(find.text('تحديث'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(splash.openStore).called(1);
    expect(find.text('نسخة أحدث متاحة'), findsNothing);
  });

  testWidgets('«لاحقًا» puts it off until the next day', (tester) async {
    today = DateTime(2026, 11, 10, 9);
    await pumpHome(tester, UpdateNeed.suggested);
    await tester.tap(find.text('لاحقًا'));
    await tester.pump(const Duration(milliseconds: 400));
    verifyNever(splash.openStore);

    await tester.tap(find.text('home settled'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('نسخة أحدث متاحة'), findsNothing);
  });

  testWidgets('nothing newer recommended: no sheet', (tester) async {
    await pumpHome(tester, UpdateNeed.none);
    expect(find.text('نسخة أحدث متاحة'), findsNothing);
  });

  testLayouts('the sheet fits', (tester, layout) async {
    whenListen(
      splash,
      const Stream<SplashState>.empty(),
      initialState: const SplashState(
        mode: SplashMode.done,
        need: UpdateNeed.suggested,
      ),
    );
    await _openHome(tester, splash, reminder, layout: layout);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A settled home that asks for the reminder when tapped.
Future<void> _openHome(
  WidgetTester tester,
  SplashCubit splash,
  UpdateReminder reminder, {
  LayoutCase? layout,
}) async {
  await tester.pumpLocalized(
    BlocProvider<SplashCubit>.value(
      value: splash,
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => remindToUpdate(context, reminder),
            child: const Text('home settled'),
          ),
        ),
      ),
    ),
    locale: layout?.locale ?? const Locale('ar'),
    size: layout?.size ?? defaultViewport,
    themeMode: layout?.themeMode ?? ThemeMode.light,
  );
  await tester.tap(find.text('home settled'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
