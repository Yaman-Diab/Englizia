import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/paint/bridges_layer.dart';
import 'package:englizia/features/home/presentation/home/paint/fog_layer.dart';
import 'package:englizia/features/home/presentation/home/paint/island_art.dart';
import 'package:englizia/features/home/presentation/home/paint/island_colors.dart';
import 'package:englizia/features/home/presentation/home/paint/sea_layer.dart';
import 'package:englizia/features/home/presentation/home/paint/waves_layer.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// [actual] is [expected] within [tolerance] of 255 on every channel.
void _expectColor(Color actual, int expected, {double tolerance = 1}) {
  final want = Color(expected);
  for (final (name, a, e) in [
    ('r', actual.r, want.r),
    ('g', actual.g, want.g),
    ('b', actual.b, want.b),
  ]) {
    expect(
      a * 255,
      closeTo(e * 255, tolerance),
      reason: '$name of $actual vs ${want.toARGB32().toRadixString(16)}',
    );
  }
}

HomeLesson _lesson(
  String id,
  LessonKind kind, {
  bool levelCheck = false,
  bool done = false,
}) => HomeLesson(
  base: UnitLesson(id: id, kind: kind, title: id, minutes: 5, done: done),
  levelCheck: levelCheck,
);

HomeUnit _unit(List<HomeLesson> lessons) => HomeUnit(
  id: 'unit_1',
  number: 1,
  title: 'Unit',
  status: UnitLessonStatus.current,
  lessons: lessons,
);

/// A second pump builds a new theme, which cross-fades: let it end before
/// asking whether anything still animates.
Future<void> _themeSettles(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  setUpAll(initLocalizationForTests);

  group('island colours (design hexes)', () {
    const light = (
      surface: Color(0xFFFFFFFF),
      reward: Color(0xFFFEF3C7),
      outline: Color(0xFF7F8CA0),
    );
    const dark = (
      surface: Color(0xFF131C2E),
      reward: Color(0xFF3A2A0A),
      outline: Color(0xFF5F6E8A),
    );
    final lightBase = islandGreyBase(
      surface: light.surface,
      rewardSurface: light.reward,
    );
    final darkBase = islandGreyBase(
      surface: dark.surface,
      rewardSurface: dark.reward,
    );

    test('the grey base', () {
      _expectColor(lightBase, 0xFFFFFAE6);
      _expectColor(darkBase, 0xFF252322);
    });

    // [layer, grey %, full light, full dark, grey light, grey dark,
    //  .15 · .5 · .67 light, .15 · .5 · .67 dark]
    const table = [
      (
        'sand',
        14,
        0xFFFEF3C7,
        0xFF7E5E16,
        0xFFECEADC,
        0xFF2D2D2F,
        [0xFFEFEBD9, 0xFFF5EFD2, 0xFFF8F0CE],
        [0xFF38342F, 0xFF54452B, 0xFF624E26],
      ),
      (
        'sand edge',
        26,
        0xFFF8DD9A,
        0xFF9F771A,
        0xFFDCDCD4,
        0xFF33353B,
        [0xFFE0DCCC, 0xFFEADDB8, 0xFFEFDDAF],
        [0xFF423F3B, 0xFF675636, 0xFF7A6131],
      ),
      (
        'grass',
        40,
        0xFFA5CEAF,
        0xFF2C6849,
        0xFFCACDCA,
        0xFF3B4049,
        [0xFFC5CDC6, 0xFFB8CEBD, 0xFFB2CEB8],
        [0xFF3A4649, 0xFF37544A, 0xFF345B4A],
      ),
      (
        'deep grass',
        60,
        0xFF75B286,
        0xFF1B452F,
        0xFFB0B7BC,
        0xFF474F5E,
        [0xFFA8B6B4, 0xFF94B5A1, 0xFF8AB498],
        [0xFF414E57, 0xFF334A47, 0xFF2B493F],
      ),
    ];

    for (final (name, grey, fullL, fullD, greyL, greyD, mixL, mixD) in table) {
      test('$name fades to its grey', () {
        _expectColor(
          islandColor(Color(fullL), lightBase, grey, 0, outline: light.outline),
          greyL,
        );
        _expectColor(
          islandColor(Color(fullD), darkBase, grey, 0, outline: dark.outline),
          greyD,
        );
        for (final (i, sat) in [.15, .5, .67].indexed) {
          _expectColor(
            islandColor(
              Color(fullL),
              lightBase,
              grey,
              sat,
              outline: light.outline,
            ),
            mixL[i],
          );
          _expectColor(
            islandColor(
              Color(fullD),
              darkBase,
              grey,
              sat,
              outline: dark.outline,
            ),
            mixD[i],
          );
        }
        expect(
          islandColor(Color(fullL), lightBase, grey, 1, outline: light.outline),
          Color(fullL),
        );
      });
    }

    test('Emar at .15 and kids at .5', () {
      Color at(int full, int grey, double sat) => islandColor(
        Color(full),
        lightBase,
        grey,
        sat,
        outline: light.outline,
      );
      _expectColor(at(0xFFFBF3D2, 14, .15), 0xFFEEEBDB);
      _expectColor(at(0xFFF8DD9A, 26, .15), 0xFFE0DCCC);
      _expectColor(at(0xFF8DBEB5, 40, .15), 0xFFC1CBC7);
      _expectColor(at(0xFF65AD9A, 60, .15), 0xFFA6B6B7);
      _expectColor(at(0xFFF9DE9D, 14, .5), 0xFFF3E4BE);
      _expectColor(at(0xFFF6CC7A, 26, .5), 0xFFE9D5AA);
      _expectColor(at(0xFF82B991, 40, .5), 0xFFA7C3AD);
      _expectColor(at(0xFF519F6A, 60, .5), 0xFF83AC93);
    });

    testWidgets('shades follow the theme; the shallows never fade', (
      tester,
    ) async {
      late IslandShades full;
      late IslandShades grey;
      late SeaPalette sea;
      await tester.pumpLocalized(
        Builder(
          builder: (context) {
            full = IslandShades.of(context, SeaTone.general, 1);
            grey = IslandShades.of(context, SeaTone.general, 0);
            sea = SeaPalette.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(full.grass, sea.island.grass);
      expect(full.sand, sea.island.sand);
      expect(grey.grass, isNot(sea.island.grass));
      expect(grey.shallow, sea.shallow);
      expect(full.shallow, sea.shallow);
    });
  });

  group('the last stone', () {
    test('a gate for the level check, a lighthouse for a unit review', () {
      final review = _unit([
        _lesson('a', LessonKind.vocabulary),
        _lesson('b', LessonKind.unitReview),
      ]);
      final check = _unit([
        _lesson('a', LessonKind.vocabulary),
        _lesson('b', LessonKind.unitReview, levelCheck: true),
      ]);
      final plain = _unit([
        _lesson('a', LessonKind.vocabulary),
        _lesson('b', LessonKind.conversation),
      ]);
      expect(lastStoneOf(review, kids: false), LastStone.lighthouse);
      expect(lastStoneOf(check, kids: false), LastStone.gate);
      expect(lastStoneOf(plain, kids: false), LastStone.none);
      expect(lastStoneOf(review, kids: true), LastStone.none);
      expect(lastStoneOf(check, kids: true), LastStone.none);
      expect(lastStoneOf(_unit(const []), kids: false), LastStone.none);
    });
  });

  group('the trail', () {
    test('in turn: the way in and each piece up to the current stone', () {
      final done = {0, 1, 2};
      expect(
        [
          for (var j = 0; j <= 6; j++)
            IslandArt.trailShare(j, n: 6, done: done),
        ],
        [1, 1, 1, 1, 0, 0, 0],
      );
      expect(
        IslandArt.trailShare(4, n: 6, done: done, segments: const {4: .5}),
        .5,
      );
      expect(IslandArt.trailShare(6, n: 6, done: done, exit: true), 1);
    });

    test('out of turn (Emar): each piece out of a done stone', () {
      expect(
        [
          for (var j = 0; j <= 6; j++)
            IslandArt.trailShare(j, n: 6, done: const {0, 2}),
        ],
        [1, 1, 0, 1, 0, 0, 0],
      );
    });
  });

  group('sea colours', () {
    test('each level its sea, Emar and kids their own', () {
      const sea = SeaPalette.light;
      expect(SeaLayer.seaOf(sea, SeaTone.general, HomeCefr.preA1), sea.preA1);
      expect(SeaLayer.seaOf(sea, SeaTone.general, HomeCefr.a1), sea.a1);
      expect(SeaLayer.seaOf(sea, SeaTone.general, HomeCefr.a2), sea.general);
      expect(SeaLayer.seaOf(sea, SeaTone.general, HomeCefr.b1), sea.deep);
      expect(SeaLayer.seaOf(sea, SeaTone.general, HomeCefr.b2), sea.b2);
      expect(SeaLayer.seaOf(sea, SeaTone.general, null), sea.general);
      expect(SeaLayer.seaOf(sea, SeaTone.emar, HomeCefr.b1), sea.emar);
      expect(SeaLayer.seaOf(sea, SeaTone.kids, HomeCefr.a1), sea.kids);
      expect(SeaLayer.openHorizonOf(sea, HomeCefr.b1), sea.deep);
      expect(SeaLayer.openHorizonOf(sea, HomeCefr.b2), sea.b2);
      expect(SeaLayer.openHorizonOf(sea, null), sea.deep);
    });
  });

  group('the drawings', () {
    Widget map(double width, {bool flagWave = false, int done = 3}) {
      final frame = MapFrame(width);
      final island = IslandLayout.compute(
        lessons: 6,
        current: done,
        kids: false,
        frame: frame,
      );
      final layout = MapLayout.compute(
        units: [
          UnitLessonStatus.done,
          UnitLessonStatus.done,
          UnitLessonStatus.current,
          UnitLessonStatus.locked,
        ],
        currentUnit: 2,
        ordered: true,
        current: island,
        anchor: const MapAnchor(box: BoxPlace.exit, rel: 42),
        reviewBox: true,
        frame: frame,
      );
      final scroll = ValueNotifier(0.0);
      addTearDown(scroll.dispose);
      return SingleChildScrollView(
        child: SizedBox(
          height: layout.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: SeaLayer(
                  tone: SeaTone.general,
                  cefr: HomeCefr.a2,
                  height: layout.height,
                  horizonY: layout.horizonY,
                  horizonOpen: 0,
                  nextCefr: HomeCefr.b1,
                  waves: WavesLayer(
                    height: layout.height,
                    scroll: scroll,
                    running: false,
                  ),
                ),
              ),
              Positioned.fill(
                child: BridgesLayer(layout: layout, fills: const {2: .5}),
              ),
              for (final slot in layout.islands)
                PositionedDirectional(
                  start: frame.startOf(slot.rect),
                  top: slot.rect.top,
                  child: slot.index == layout.currentIndex
                      ? IslandArt.current(
                          layout: island,
                          tone: SeaTone.general,
                          unitIndex: slot.index,
                          saturation: .5,
                          done: {for (var k = 0; k < done; k++) k},
                          segments: const {4: .5},
                          last: LastStone.lighthouse,
                          lit: done >= 5,
                          flagUp: 1,
                          complete: done >= 6,
                          frame: frame,
                          flagWave: flagWave,
                        )
                      : Stack(
                          children: [
                            IslandArt.compact(
                              status: slot.status,
                              tone: SeaTone.general,
                              unitIndex: slot.index,
                              flagWave: flagWave,
                            ),
                            if (slot.status == UnitLessonStatus.locked)
                              const FogLayer(clear: .3, running: false),
                          ],
                        ),
                ),
            ],
          ),
        ),
      );
    }

    testLayouts('the map draws in every layout', (tester, layout) async {
      await tester.pumpLocalized(
        Scaffold(body: map(layout.size.width)),
        locale: layout.locale,
        themeMode: layout.themeMode,
        size: layout.size,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(IslandArt), findsNWidgets(4));
      final current = tester.getSize(find.byType(IslandArt).at(2));
      expect(current.width, layout.size.width);
      expect(current.height, 440);
      expect(
        tester.getSize(find.byType(IslandArt).first),
        MapLayout.compactSize,
      );
      // Decorative: nothing for screen readers.
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      handle.dispose();
    });

    // Unit 0 sits on the start side: right in Arabic, left in English.
    testWidgets('islands start on the right in Arabic', (tester) async {
      await tester.pumpLocalized(
        Scaffold(body: map(360)),
        size: const Size(360, 800),
      );
      expect(tester.getTopLeft(find.byType(IslandArt).first).dx, 164);
    });

    testWidgets('islands are placed mirrored in English', (tester) async {
      await tester.pumpLocalized(
        Scaffold(body: map(360)),
        locale: const Locale('en'),
        size: const Size(360, 800),
      );
      expect(tester.getTopLeft(find.byType(IslandArt).first).dx, 20);
    });

    testWidgets('a complete unit raises its flag', (tester) async {
      Finder paintsOf(int island) => find.descendant(
        of: find.byType(IslandArt).at(island),
        matching: find.byType(CustomPaint),
      );
      await tester.pumpLocalized(Scaffold(body: map(360)));
      // The current island: its drawing only; a done one: its flag too.
      expect(paintsOf(2), findsOneWidget);
      expect(paintsOf(0), findsNWidgets(2));
      expect(paintsOf(3), findsOneWidget);

      await tester.pumpLocalized(Scaffold(body: map(360, done: 6)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(paintsOf(2), findsNWidgets(2));
    });

    testWidgets('flags wave only when asked, never under reduce motion', (
      tester,
    ) async {
      await tester.pumpLocalized(Scaffold(body: map(360)));
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpLocalized(Scaffold(body: map(360, flagWave: true)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      await tester.pumpLocalized(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(body: map(360, flagWave: true)),
          ),
        ),
      );
      await _themeSettles(tester);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('waves', () {
    Widget waves(ValueNotifier<double> scroll, {required bool running}) =>
        Scaffold(
          body: SizedBox(
            height: 600,
            child: WavesLayer(height: 600, scroll: scroll, running: running),
          ),
        );

    Offset shift(WidgetTester tester) {
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(WavesLayer),
          matching: find.byType(Transform),
        ),
      );
      final t = transform.transform.getTranslation();
      return Offset(t.x, t.y);
    }

    testWidgets('they drift while running, slower than the scroll', (
      tester,
    ) async {
      final scroll = ValueNotifier(0.0);
      addTearDown(scroll.dispose);
      await tester.pumpLocalized(waves(scroll, running: true));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(seconds: 2));
      // A quarter of the 8 s loop: a quarter of the 48 tile, to the right.
      expect(shift(tester).dx, closeTo(12, .5));

      scroll.value = 100;
      await tester.pump();
      // .35 of the scroll, within one 34-high tile.
      expect(shift(tester).dy, closeTo(35 % 34, 1e-9));
    });

    testWidgets('they move the other way in English', (tester) async {
      final scroll = ValueNotifier(0.0);
      addTearDown(scroll.dispose);
      await tester.pumpLocalized(
        waves(scroll, running: true),
        locale: const Locale('en'),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(shift(tester).dx, closeTo(-12, .5));
    });

    testWidgets('they stop when not running and under reduce motion', (
      tester,
    ) async {
      final scroll = ValueNotifier(0.0);
      addTearDown(scroll.dispose);
      await tester.pumpLocalized(waves(scroll, running: false));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpLocalized(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: waves(scroll, running: true),
          ),
        ),
      );
      await _themeSettles(tester);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('fog', () {
    testWidgets('clouds drift while running; cleared, they stop', (
      tester,
    ) async {
      await tester.pumpLocalized(
        const Scaffold(body: FogLayer(clear: 0, running: true)),
      );
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.getSize(find.byType(FogLayer)), MapLayout.compactSize);
      await tester.pumpLocalized(
        const Scaffold(body: FogLayer(clear: 1, running: true)),
      );
      await _themeSettles(tester);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
