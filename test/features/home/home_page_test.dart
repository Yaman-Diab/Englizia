import 'dart:async';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/pages/home_page.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/goal_ring.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/back_to_lesson_button.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/stone.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/stone_card.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/compact_island.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/home_map.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/horizon_flag.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/level_header.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/locked_toast.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/connection_strip.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/switch_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/home_harness.dart';
import '../../helpers/pump_app.dart';

/// The design's main area: 800 less the status bar, home indicator and tab
/// bar; the map's view is then 624.
const _design = Size(360, 680);

HomeSnapshot _home({
  HomeMockScenario scenario = HomeMockScenario.general,
  bool kids = false,
  bool emar = false,
}) => mockHome(scenario: scenario, kids: kids, emar: emar, now: homeMorning);

ScrollPosition _map(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

Future<void> _steps(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// A page over home, as a lesson opens; the navigator pops it.
Future<NavigatorState> _pushLesson(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
    ),
  );
  await _steps(tester, const Duration(milliseconds: 600));
  return navigator;
}

/// Scrolls the map by [dy] (down the map when positive) and lets it settle.
Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(CustomScrollView), Offset(0, -dy));
  await _steps(tester, const Duration(milliseconds: 900));
}

void main() {
  setUpAll(initLocalizationForTests);

  group('every track fits', () {
    for (final (name, home) in [
      ('general', () => _home()),
      ('emar', () => _home(emar: true)),
      ('kids', () => _home(kids: true)),
      ('level complete', () => _home(scenario: HomeMockScenario.levelComplete)),
      ('ten lessons', () => _home(scenario: HomeMockScenario.lessons10)),
    ]) {
      // The app's largest text scale (lib/app/app.dart) as well.
      for (final scale in const [1.0, 1.3]) {
        testLayouts(scale == 1 ? name : '$name, text ×$scale', (
          tester,
          layout,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpHome(
            tester,
            home(),
            locale: layout.locale,
            themeMode: layout.themeMode,
            size: layout.size,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(HomeMap), findsOneWidget);
          expect(find.byType(LevelHeader), findsOneWidget);
          await _scroll(tester, 600);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('the stage (header §5)', () {
    testWidgets('opens on today\'s island with the header open', (
      tester,
    ) async {
      await pumpHome(tester, _home(), size: _design);
      // The design's worked anchor: the island at 310, the box at its exit,
      // rel 42 (map §9).
      expect(_map(tester).pixels, 352);
      final ring = tester.widget<GoalRingOverlay>(find.byType(GoalRingOverlay));
      expect(ring.metrics.collapse, 0);
      expect(ring.metrics.head, 114);
      expect(tester.getTopLeft(find.byType(LevelHeader)).dy, 56 + 114);
    });

    testWidgets('folds as the map scrolls; the level header sticks', (
      tester,
    ) async {
      await pumpHome(tester, _home(), size: _design);
      await _scroll(tester, 300);
      final ring = tester.widget<GoalRingOverlay>(find.byType(GoalRingOverlay));
      expect(ring.metrics.collapse, 114);
      expect(ring.metrics.ringScale, closeTo(28 / 96, 1e-9));
      expect(tester.getTopLeft(find.byType(LevelHeader)).dy, 56);
      await _scroll(tester, -100);
      final back = tester.widget<GoalRingOverlay>(find.byType(GoalRingOverlay));
      expect(back.metrics.collapse, 0, reason: 'back, then snapped open');
    });

    for (final (locale, x) in [
      (const Locale('ar'), 80.0),
      (const Locale('en'), 360 - 80.0),
    ]) {
      testWidgets('places the current stone at $x in '
          '${locale.languageCode} (D1)', (tester) async {
        await pumpHome(tester, _home(), size: _design, locale: locale);
        final stone = tester.getCenter(_currentStone());
        expect(stone.dx, closeTo(x, .5));
        // Row 1 at 354 of the island at 310, under the header's 154 (the
        // English header wraps: measured taller, anchored again).
        if (locale.languageCode == 'ar') {
          expect(stone.dy, closeTo(56 + 154 + 310 + 354 - 352, .5));
        }
      });
    }

    testWidgets('the back button shows when today\'s stone is off screen', (
      tester,
    ) async {
      await pumpHome(tester, _home(), size: _design);
      expect(find.byType(BackToLessonButton), findsNothing);
      await _scroll(tester, 900);
      final button = tester.widget<BackToLessonButton>(
        find.byType(BackToLessonButton),
      );
      expect(button.direction, BackDirection.up);
      expect(button.lessonTitle, isNotEmpty);

      await tester.tap(find.byType(BackToLessonButton));
      await _steps(tester, const Duration(milliseconds: 1200));
      // Today's island just under the folded header (bubble §13.3): its top
      // 310 at the header's 114 less 10.
      expect(_map(tester).pixels, 114 + 310 - 10);
      expect(
        tester
            .widget<BackToLessonButton>(find.byType(BackToLessonButton))
            .direction,
        isNull,
      );
    });

    testWidgets('a pull at the top asks the server again', (tester) async {
      final repository = FakeHomeRepository(_home());
      await pumpHome(tester, _home(), size: _design, repository: repository);
      final before = repository.fetches;
      await _scroll(tester, -2000);
      expect(_map(tester).pixels, 0);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await _steps(tester, const Duration(seconds: 2));
      expect(repository.fetches, before + 1);
      final ring = tester.widget<GoalRingOverlay>(find.byType(GoalRingOverlay));
      expect(ring.metrics.pull, 0, reason: 'back once let go');
    });

    testWidgets('a pull that fails says so, then the strip goes', (
      tester,
    ) async {
      final repository = FakeHomeRepository(_home());
      await pumpHome(tester, _home(), size: _design, repository: repository);
      repository.failure = const ServerFailure(statusCode: 500);
      await _scroll(tester, -2000);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await _steps(tester, const Duration(seconds: 1));
      expect(find.byType(ConnectionStrip), findsOneWidget);
      await _steps(tester, const Duration(seconds: 4));
      expect(find.byType(ConnectionStrip), findsNothing);
    });

    testWidgets('back from a lesson, what it changed plays (§4.3)', (
      tester,
    ) async {
      final repository = FakeHomeRepository(_home());
      final cubit = await pumpHome(
        tester,
        _home(),
        size: _design,
        repository: repository,
      );
      final navigator = await _pushLesson(tester);
      repository.home = mockHomeAfterLesson(now: homeMorning);
      navigator.pop();
      await _steps(tester, const Duration(milliseconds: 600));
      expect(cubit.state.momentId, 1);
      expect(cubit.state.moment, isA<LessonDoneMoment>());

      await _steps(tester, const Duration(milliseconds: 3500));
      expect(cubit.state.moment, isNull, reason: 'played');
      expect(
        find.byWidgetPredicate(
          (w) => w is Stone && w.index == 3 && w.state == StoneState.done,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a refresh while a lesson is on top keeps its moment', (
      tester,
    ) async {
      final repository = FakeHomeRepository(_home());
      final cubit = await pumpHome(
        tester,
        _home(),
        size: _design,
        repository: repository,
      );
      final navigator = await _pushLesson(tester);
      repository.home = mockHomeAfterLesson(now: homeMorning);
      final before = repository.fetches;
      // The phone locked and unlocked on the result screen.
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repository.fetches, before + 1);
      expect(cubit.state.home, _home(), reason: 'home stays as drawn');

      navigator.pop();
      await _steps(tester, const Duration(milliseconds: 600));
      expect(cubit.state.moment, isA<LessonDoneMoment>());
    });

    testWidgets('closing a sheet over home is no return', (tester) async {
      final repository = FakeHomeRepository(_home());
      await pumpHome(tester, _home(), size: _design, repository: repository);
      await _scroll(tester, 500);
      final before = repository.fetches;
      await tester.tap(
        find.byWidgetPredicate((w) => w is CompactIsland && w.unit.number == 4),
      );
      await _steps(tester, const Duration(milliseconds: 1500));
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await _steps(tester, const Duration(milliseconds: 1500));
      expect(find.byType(BottomSheet), findsNothing);
      expect(repository.fetches, before);
    });

    testWidgets('a track switch says so for a while (M11)', (tester) async {
      final cubit = await pumpHome(tester, _home(), size: _design);
      final emar = mockProfile().tracks.firstWhere((t) => t.isSchool);
      await cubit.switchTrack(emar);
      await tester.pump();
      expect(
        tester.widget<SwitchStrip>(find.byType(SwitchStrip)).title,
        emar.title,
      );
      await _steps(tester, const Duration(milliseconds: 3200));
      expect(
        tester.widget<SwitchStrip>(find.byType(SwitchStrip)).title,
        isNull,
      );
    });
  });

  group('the map\'s buttons', () {
    testWidgets('a done island opens its unit', (tester) async {
      final actions = RecordedActions();
      final home = _home();
      await pumpHome(tester, home, size: _design, actions: actions);
      await _scroll(tester, -2000);
      await tester.tap(find.byType(CompactIsland).first);
      await tester.pump();
      expect(actions.units, [home.units.first.id]);
    });

    testWidgets('a locked island shakes, says when it opens, then previews', (
      tester,
    ) async {
      await pumpHome(tester, _home(), size: _design);
      await _scroll(tester, 500);
      final locked = find.byWidgetPredicate(
        (w) => w is CompactIsland && w.unit.number == 4,
      );
      await tester.tap(locked);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LockedToast), findsOneWidget);
      expect(find.text('تُفتح بعد الوحدة 3'), findsWidgets);
      await _steps(tester, const Duration(milliseconds: 900));
      expect(find.byType(LockedToast), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('a done stone opens its card; a scroll closes it', (
      tester,
    ) async {
      await pumpHome(tester, _home(), size: _design);
      final done = find.byWidgetPredicate(
        (w) => w is Stone && w.state == StoneState.done,
      );
      await tester.tap(done.at(1));
      await _steps(tester, const Duration(milliseconds: 300));
      expect(find.byType(StoneCard), findsOneWidget);
      await _scroll(tester, 80);
      expect(find.byType(StoneCard), findsNothing);
    });

    testWidgets('«تابع» opens today\'s lesson', (tester) async {
      final actions = RecordedActions();
      final home = _home();
      await pumpHome(tester, home, size: _design, actions: actions);
      await tester.tap(find.bySemanticsLabel(RegExp('تابع')).first);
      await _steps(tester, const Duration(seconds: 1));
      final current = home.currentUnit!;
      expect(actions.lessons, [current.lessons[current.currentLesson].id]);
    });
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('a stone\'s chips stay on screen at 320dp '
        '(${locale.languageCode})', (tester) async {
      await pumpHome(
        tester,
        _home(emar: true),
        locale: locale,
        size: narrowViewport,
      );
      final chips = find.descendant(
        of: find.byType(StoneLabel),
        matching: find.byType(DecoratedBox),
      );
      expect(chips, findsWidgets);
      for (final chip in chips.evaluate()) {
        final rect = tester.getRect(find.byWidget(chip.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(narrowViewport.width));
      }
    });
  }

  group('the screen reader', () {
    testWidgets('reads the map, the level and the horizon', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, _home(), size: _design);
      expect(find.bySemanticsLabel('خريطة المستوى A2'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('2 من 8 وحدات')),
        matchesSemantics(
          label: '2 من 8 وحدات',
          value: '2',
          minValue: '0',
          maxValue: '8',
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('^الوحدة 1، التحيات والتعارف، مكتملة')),
        findsOneWidget,
      );
      await _scroll(tester, 3000);
      expect(find.byType(HorizonFlag), findsOneWidget);
      expect(find.bySemanticsLabel('المستوى التالي: B1'), findsOneWidget);
      handle.dispose();
    });

    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets('reads the header first, then the level and the map '
          '(header §14, ${locale.languageCode})', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpHome(
          tester,
          _home(scenario: HomeMockScenario.freezeUsed),
          size: _design,
          locale: locale,
        );
        final read = [
          for (final node in tester.semantics.simulatedAccessibilityTraversal())
            if (node.label.isNotEmpty) node.label,
        ];
        int at(String start) => read.indexWhere((l) => l.startsWith(start));
        final ar = locale.languageCode == 'ar';
        final order = [
          at(ar ? 'تبديل المسار' : 'Switch track'),
          at(ar ? 'صباح الخير' : 'Good morning'),
          at(ar ? 'استخدمنا تجميدًا' : 'We used a freeze'),
          at(ar ? '7 أيام متتالية،' : '7 days in a row,'),
          at(ar ? 'A2، ما قبل المتوسط' : 'A2, '),
          at(ar ? '2 من 8 وحدات' : '2 of 8 units'),
          at(ar ? 'خريطة المستوى' : 'Map of level'),
          at(ar ? 'الوحدة 1،' : 'Unit 1,'),
        ];
        expect(order, everyElement(isNonNegative), reason: '$read');
        expect(order, orderedEquals([...order]..sort()), reason: '$read');
        handle.dispose();
      });
    }

    testWidgets('the guide comes after the flame and before the level', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, _home(), size: _design);
      final read = [
        for (final node in tester.semantics.simulatedAccessibilityTraversal())
          if (node.label.isNotEmpty) node.label,
      ];
      int at(String start) => read.indexWhere((l) => l.startsWith(start));
      final flame = at('7 أيام متتالية،');
      final guide = at('بلبل');
      expect(flame, isNonNegative);
      expect(guide, greaterThan(flame));
      expect(at('A2، ما قبل المتوسط'), greaterThan(guide));
      handle.dispose();
    });

    testWidgets('meets the tap target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, _home(), size: _design);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  test('kids and every track pick their sea', () {
    expect(
      HomePage.isKids(HomeState(now: homeMorning, kidsHint: true)),
      isTrue,
    );
    expect(toneOf(_home(kids: true).enrollment).name, 'kids');
    expect(toneOf(_home(emar: true).enrollment).name, 'emar');
    expect(toneOf(_home().enrollment).name, 'general');
  });
}

Finder _currentStone() =>
    find.byWidgetPredicate((w) => w is Stone && w.state == StoneState.current);
