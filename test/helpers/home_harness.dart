import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/pages/home_page.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_home_repository.dart';
import 'fake_lesson_repository.dart';
import 'fake_profile_repository.dart';
import 'fakes.dart';
import 'pump_app.dart';

/// The design's morning: greeting, risk and the week read this clock.
final homeMorning = DateTime(2026, 11, 5, 10);

/// What home's taps did, for the tests to check.
final class RecordedActions {
  final lessons = <String>[];
  final units = <String>[];
  var reviews = 0;
  var placements = 0;
  var me = 0;

  HomeActions get actions => HomeActions(
    openLesson: (UnitLesson lesson, {required bool kids}) =>
        lessons.add(lesson.id),
    openUnit: units.add,
    openReview: () => reviews++,
    openPlacement: () => placements++,
    openMe: () => me++,
    joinTrack: (_) {},
  );
}

/// Home's cubit over [home], loaded without its clock or connection
/// listener (no timers left behind).
Future<HomeCubit> loadedHomeCubit(
  HomeSnapshot home, {
  FakeHomeRepository? repository,
}) async {
  final cubit = HomeCubit(
    repository ?? FakeHomeRepository(home),
    FakeProfileRepository(mockProfile()),
    FakeLessonRepository(),
    FakeConnectivityService(),
    FakeSoundPlayer(),
    now: () => homeMorning,
  );
  await cubit.refresh();
  return cubit;
}

/// [home] on the «تعلّم» tab, as the route shows it (its tab bar left out),
/// told of the pages over it as the router does.
Future<HomeCubit> pumpHome(
  WidgetTester tester,
  HomeSnapshot home, {
  Locale locale = const Locale('ar'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = defaultViewport,
  RecordedActions? actions,
  FakeHomeRepository? repository,
}) async {
  final cubit = await loadedHomeCubit(home, repository: repository);
  addTearDown(cubit.close);
  final pages = RouteObserver<PageRoute<dynamic>>();
  await tester.pumpLocalized(
    BlocProvider.value(
      value: cubit,
      child: Scaffold(
        body: HomePage(
          actions: (actions ?? RecordedActions()).actions,
          pages: pages,
        ),
      ),
    ),
    locale: locale,
    themeMode: themeMode,
    size: size,
    navigatorObservers: [pages],
  );
  await settleHome(tester);
  return cubit;
}

/// Lets the first layout anchor the map and the header measure itself.
Future<void> settleHome(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
