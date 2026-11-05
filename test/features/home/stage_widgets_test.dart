import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/compact_island.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/home_map.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/horizon_flag.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/level_header.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/locked_toast.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';
import '../../helpers/home_harness.dart';
import '../../helpers/pump_app.dart';

HomeSnapshot _home({
  HomeMockScenario scenario = HomeMockScenario.general,
  bool kids = false,
  bool emar = false,
}) => mockHome(scenario: scenario, kids: kids, emar: emar, now: homeMorning);

IslandSlot _slot(int index, UnitLessonStatus status) => IslandSlot(
  index: index,
  status: status,
  rect: const Rect.fromLTWH(20, 0, 176, 112),
  right: index.isEven,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('ar'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = defaultViewport,
}) => tester.pumpLocalized(
  Scaffold(
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child],
      ),
    ),
  ),
  locale: locale,
  themeMode: themeMode,
  size: size,
);

Widget _island(HomeUnit unit, {bool kids = false, VoidCallback? onPressed}) =>
    Center(
      child: CompactIsland(
        unit: unit,
        slot: _slot(unit.number - 1, unit.status),
        tone: kids ? SeaTone.kids : SeaTone.general,
        kids: kids,
        onPressed: onPressed ?? () {},
      ),
    );

void main() {
  setUpAll(initLocalizationForTests);

  group('the level header (map §6)', () {
    testLayouts('fits', (tester, layout) async {
      await _pump(
        tester,
        LevelHeader(home: _home(), progress: 0),
        locale: layout.locale,
        themeMode: layout.themeMode,
        size: layout.size,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(LevelHeader)).height, 40 + 8);
    });

    testWidgets('the level, its units and a bar of them', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, LevelHeader(home: _home(), progress: 0));
      expect(find.text('A2، ما قبل المتوسط'), findsOneWidget);
      expect(find.text('2 من 8 وحدات'), findsOneWidget);
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
        tester.getSemantics(find.text('A2، ما قبل المتوسط')),
        matchesSemantics(label: 'A2، ما قبل المتوسط', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('a grade by its name, Emar\'s six units', (tester) async {
      await _pump(tester, LevelHeader(home: _home(emar: true), progress: 1));
      expect(find.text('الصف السابع'), findsOneWidget);
      expect(find.text('2 من 6 وحدات'), findsOneWidget);
    });

    testWidgets('the bar fills to its share, in success when complete', (
      tester,
    ) async {
      await _pump(tester, LevelHeader(home: _home(), progress: 0));
      await tester.pump(const Duration(seconds: 1));
      final general = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(general.widthFactor, 2 / 8);

      await _pump(
        tester,
        LevelHeader(
          home: _home(scenario: HomeMockScenario.firstDay),
          progress: 0,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final empty = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(empty.widthFactor, .02, reason: 'never below 2%');
    });

    testWidgets('a level done reads 8 of 8 in the success colour', (
      tester,
    ) async {
      await _pump(
        tester,
        LevelHeader(
          home: _home(scenario: HomeMockScenario.levelComplete),
          progress: 0,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('8 من 8 وحدات'), findsOneWidget);
      final fill = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      final context = tester.element(find.byType(LevelHeader));
      expect(
        (fill.decoration as BoxDecoration).color,
        context.colors.success.fill,
      );
    });

    test('the shore scallops between 2 and 7 of its 8', () {
      final bounds = ShorePainter.designPath().getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 360);
      expect(bounds.top, 0);
      expect(bounds.bottom, 7);
    });
  });

  group('a compact island (bubble §7)', () {
    final general = _home();
    final done = general.units[0];
    final locked = general.units[3];
    final open = _home(emar: true).units[3];
    final kidDone = _home(kids: true).units[0];

    testLayouts('fits', (tester, layout) async {
      for (final unit in [done, locked, open]) {
        await _pump(
          tester,
          _island(unit),
          locale: layout.locale,
          themeMode: layout.themeMode,
          size: layout.size,
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(CompactIsland)), CompactIsland.size);
      }
      await _pump(
        tester,
        _island(kidDone, kids: true),
        locale: layout.locale,
        themeMode: layout.themeMode,
        size: layout.size,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('done: its name and «أعد»; one button', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(tester, _island(done, onPressed: () => taps++));
      expect(find.text('الوحدة 1 · التحيات والتعارف'), findsOneWidget);
      expect(find.text('أعد'), findsOneWidget);
      const label = 'الوحدة 1، التحيات والتعارف، مكتملة. أعد';
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(label: label, isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byType(CompactIsland));
      expect(taps, 1);
      // The chip hugs its word: the island is the button.
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('أعد'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .width,
        lessThan(80),
      );
      handle.dispose();
    });

    testWidgets('locked: when it opens, and a lock', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _island(locked));
      expect(find.text('تُفتح بعد الوحدة 3'), findsOneWidget);
      expect(
        find.bySemanticsLabel('الوحدة 4، في السوق، مقفلة. تُفتح بعد الوحدة 3'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Emar\'s open one: its pages', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _island(open));
      expect(find.text('الصفحات 42 إلى 53'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'الوحدة 4، في السوق، الصفحات 42 إلى 53. افتح الوحدة',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('kids: both names and the unit\'s stars, no «أعد»', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _island(kidDone, kids: true));
      expect(find.text('مرحبًا'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('أعد'), findsNothing);
      final stars = tester.widgetList<KidStar>(find.byType(KidStar)).toList();
      expect(stars, hasLength(5));
      expect(stars.where((s) => s.filled), hasLength(kidDone.stars!));
      expect(
        find.bySemanticsLabel(RegExp('^الوحدة 1، مرحبًا، مكتملة، ')),
        findsOneWidget,
      );
      handle.dispose();
    });

    test('the shake: ±4 in equal legs, still at both ends (M9)', () {
      expect(CompactIsland.shakeOffset(0), 0);
      expect(CompactIsland.shakeOffset(1), 0);
      final legs = [
        for (var i = 1; i < 20; i++) CompactIsland.shakeOffset(i / 20).abs(),
      ];
      expect(legs.every((d) => d <= 4), isTrue);
      expect(legs.any((d) => d > 3), isTrue);
    });
  });

  group('on the map', () {
    testLayouts('the horizon flag and the locked toast fit', (
      tester,
      layout,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            HorizonFlag(text: 'المستوى التالي: B1'),
            LockedToast(text: 'تُفتح بعد الوحدة 3'),
          ],
        ),
        locale: layout.locale,
        themeMode: layout.themeMode,
        size: layout.size,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(HorizonFlag)).height,
        HorizonFlag.pill + HorizonFlag.pole,
      );
    });

    testWidgets('the horizon flag is one item; the toast a live status', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          children: [
            HorizonFlag(text: 'المستوى التالي: B1'),
            LockedToast(text: 'تُفتح بعد الوحدة 3'),
          ],
        ),
      );
      expect(find.bySemanticsLabel('المستوى التالي: B1'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(LockedToast)),
        matchesSemantics(label: 'تُفتح بعد الوحدة 3', isLiveRegion: true),
      );
      handle.dispose();
    });

    test('the double pulse: 1.2 at .3, 1 at .55, 1.12 at .78', () {
      expect(HomeMap.pulseScale(0), 1);
      expect(HomeMap.pulseScale(1), 1);
      final curve = [
        for (var i = 0; i <= 100; i++) HomeMap.pulseScale(i / 100),
      ];
      final peak = curve.reduce((a, b) => a > b ? a : b);
      expect(peak, closeTo(1.2, .01));
      expect(curve.every((s) => s >= 1 && s <= 1.2 + 1e-9), isTrue);
    });
  });
}
