import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/back_to_lesson_button.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/island_banner.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/kid_say_bubble.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/lesson_bubble.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/review_box.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/stone.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/stone_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';
import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 11, 5, 10);

HomeState _state(HomeSnapshot home, {DateTime? now}) =>
    HomeState(now: now ?? _now, home: home);

HomeLesson _current(HomeSnapshot home) {
  final unit = home.currentUnit!;
  return unit.lessons[unit.currentLesson];
}

const _frame = BubbleFrame(x0: 46, x1: 340, tailX: 25, side: TailSide.bottom);

Widget _bubble(
  HomeSnapshot home, {
  BubbleMode? mode,
  HomeLesson? lesson,
  VoidCallback? onPressed,
  double width = 294,
}) => Center(
  child: SizedBox(
    width: width,
    child: LessonBubble(
      mode: mode ?? bubbleModeOf(_state(home)),
      home: home,
      lesson: lesson ?? _current(home),
      frame: BubbleFrame(x0: 0, x1: width, tailX: 25, side: TailSide.bottom),
      centerY: 0,
      overrides: MapOverrides.none,
      onPressed: onPressed ?? () {},
    ),
  ),
);

StoneState _stateOf(HomeUnit unit, int k) => unit.lessons[k].done
    ? StoneState.done
    : k == unit.currentLesson
    ? StoneState.current
    : StoneState.locked;

/// Every map object of a unit at once, for the layout matrix.
Widget _board(HomeSnapshot home, HomeSnapshot kids) {
  void none() {}
  final unit = home.currentUnit!;
  final kidUnit = kids.currentUnit!;
  final review = home.review!;
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IslandBanner(unit: unit, emar: false, onOpen: none),
          const SizedBox(height: 16),
          IslandBanner(unit: unit, emar: true, onOpen: none),
          const SizedBox(height: 16),
          IslandBanner.kid(
            unit: kidUnit,
            speaking: true,
            onListen: none,
            onOpen: none,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 40,
            children: [
              for (final (k, lesson) in unit.lessons.indexed)
                Column(
                  children: [
                    if (unit.isLast(k))
                      Stone.last(
                        lesson: lesson,
                        state: _stateOf(unit, k),
                        emar: false,
                        onPressed: none,
                      )
                    else
                      Stone.lesson(
                        lesson: lesson,
                        index: k,
                        state: _stateOf(unit, k),
                        emar: false,
                        offline: true,
                        pulse: false,
                        hit: k == 0,
                        pop: 1,
                        onPressed: none,
                      ),
                    const SizedBox(height: 6),
                    StoneLabel(
                      lesson: lesson,
                      current: _stateOf(unit, k) == StoneState.current,
                      hit: false,
                      emar: true,
                      last: unit.isLast(k),
                      locked: _stateOf(unit, k) == StoneState.locked,
                      kids: false,
                    ),
                  ],
                ),
              for (final (k, lesson) in kidUnit.lessons.indexed)
                Stone.kid(
                  lesson: lesson,
                  state: _stateOf(kidUnit, k),
                  onPressed: none,
                ),
              Stone.station(review: review, pulse: false, onPressed: none),
            ],
          ),
          const SizedBox(height: 16),
          for (final mode in BubbleMode.values) ...[
            LessonBubble(
              mode: mode,
              home: mode == BubbleMode.kids ? kids : home,
              lesson: mode == BubbleMode.kids ? _current(kids) : _current(home),
              frame: const BubbleFrame(
                x0: 0,
                x1: 254,
                tailX: 25,
                side: TailSide.top,
              ),
              centerY: 0,
              overrides: MapOverrides.none,
              onPressed: none,
            ),
            const SizedBox(height: 16),
          ],
          for (final state in StoneState.values) ...[
            StoneCard(
              lesson: unit.lessons[4],
              index: 4,
              state: state,
              lockedAfter: unit.lessons[3].title,
              reviewFirst: state == StoneState.current,
              onReplay: none,
              onStart: none,
            ),
            const SizedBox(height: 16),
          ],
          ReviewBox(review: review, onPressed: none),
          const SizedBox(height: 16),
          KidSayBubble(unit: kidUnit),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final direction in BackDirection.values)
                BackToLessonButton(
                  direction: direction,
                  kids: false,
                  lessonTitle: _current(home).title,
                  reviewFirst: false,
                  arrivedByFlight: true,
                  onPressed: none,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(initLocalizationForTests);

  group('bubbleModeOf', () {
    test('follows the design frames, first match wins', () {
      BubbleMode of(HomeMockScenario scenario, {DateTime? now}) =>
          bubbleModeOf(_state(mockHome(scenario: scenario), now: now));

      expect(of(HomeMockScenario.general), BubbleMode.next);
      expect(of(HomeMockScenario.firstDay), BubbleMode.first);
      expect(of(HomeMockScenario.partial), BubbleMode.resume);
      expect(of(HomeMockScenario.goalReached), BubbleMode.extra);
      expect(of(HomeMockScenario.welcomeBack), BubbleMode.reviewFirst);
      expect(of(HomeMockScenario.v01), BubbleMode.next);
      expect(bubbleModeOf(_state(mockHome(emar: true))), BubbleMode.suggested);
      expect(bubbleModeOf(_state(mockHome(kids: true))), BubbleMode.kids);
      expect(bubbleModeOf(HomeState(now: _now)), BubbleMode.next);
    });
  });

  group('LessonBubble', () {
    testWidgets('says the next lesson as the design prints it', (tester) async {
      var opened = 0;
      await tester.pumpLocalized(
        _bubble(mockHome(), onPressed: () => opened++),
      );

      expect(find.text('درسك التالي'), findsOneWidget);
      expect(find.text('يوم في حياة سارة'), findsOneWidget);
      expect(find.text('نص تفاعلي، 7 دقائق'), findsOneWidget);
      expect(find.text('الوحدة 3، يوم في المزرعة'), findsOneWidget);
      expect(find.text('تابع'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'درسك التالي: يوم في حياة سارة، نص تفاعلي، 7 دقائق. تابع',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(LessonBubble));
      expect(opened, 1);
    });

    testWidgets('the first day starts, a half-done lesson goes on', (
      tester,
    ) async {
      await tester.pumpLocalized(
        _bubble(mockHome(scenario: HomeMockScenario.firstDay)),
      );
      expect(find.text('درسك الأول'), findsOneWidget);
      expect(find.text('ابدأ'), findsOneWidget);

      await tester.pumpLocalized(
        _bubble(mockHome(scenario: HomeMockScenario.partial)),
      );
      expect(find.text('تابع من حيث توقفت'), findsOneWidget);
      expect(find.text('السؤال 3 من 6'), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsOneWidget);
      expect(
        tester
            .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
            .widthFactor,
        .5,
      );
    });

    testWidgets('one lesson more once the goal is reached', (tester) async {
      await tester.pumpLocalized(
        _bubble(mockHome(scenario: HomeMockScenario.goalReached)),
      );
      expect(find.text('درس إضافي؟'), findsOneWidget);
      expect(find.text('تابع'), findsOneWidget);
    });

    testWidgets('the review first, back after a while', (tester) async {
      final home = mockHome(scenario: HomeMockScenario.welcomeBack);
      await tester.pumpLocalized(_bubble(home, mode: BubbleMode.reviewFirst));
      expect(find.text('ابدأ بمراجعة قصيرة تنعش ذاكرتك'), findsOneWidget);
      expect(find.text('راجع اليوم'), findsOneWidget);
      expect(find.text('12 كلمة و3 مفاهيم، نحو 5 دقائق'), findsOneWidget);
      expect(find.text('راجع'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'ابدأ بمراجعة قصيرة تنعش ذاكرتك: راجع اليوم، '
          '12 كلمة و3 مفاهيم، نحو 5 دقائق. راجع',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Emar suggests a lesson and gives its page', (tester) async {
      await tester.pumpLocalized(_bubble(mockHome(emar: true)));
      expect(find.text('الدرس المقترح'), findsOneWidget);
      expect(find.text('الوحدة 3، يوم في المزرعة · ص 36'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^الدرس المقترح: .*، صفحة 36\. تابع$')),
        findsOneWidget,
      );
    });

    testWidgets('kids: the picture, the English name and ▶', (tester) async {
      final kids = mockHome(kids: true);
      final lesson = _current(kids);
      await tester.pumpLocalized(_bubble(kids, mode: BubbleMode.kids));
      expect(find.text('درسك التالي'), findsOneWidget);
      expect(find.text(lesson.title), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(
        find.bySemanticsLabel('درسك التالي: ${lesson.title}. ابدأ'),
        findsOneWidget,
      );
    });

    testWidgets('hidden while a motion hides it', (tester) async {
      final home = mockHome();
      await tester.pumpLocalized(
        LessonBubble(
          mode: BubbleMode.next,
          home: home,
          lesson: _current(home),
          frame: _frame,
          centerY: 300,
          overrides: const MapOverrides(bubbleVisible: false),
          onPressed: () {},
        ),
      );
      expect(find.text('تابع'), findsNothing);
    });

    testWidgets('in a stack it lays itself out at its frame, mirrored in '
        'English', (tester) async {
      final home = mockHome();
      Widget stack() => Stack(
        children: [
          Positioned.fill(
            child: LessonBubble(
              mode: BubbleMode.next,
              home: home,
              lesson: _current(home),
              frame: _frame,
              centerY: 300,
              overrides: MapOverrides.none,
              onPressed: () {},
            ),
          ),
        ],
      );
      Rect card() => tester.getRect(
        find.descendant(
          of: find.byType(LessonBubble),
          matching: find.byType(PressScale),
        ),
      );
      await tester.pumpLocalized(stack(), size: const Size(360, 800));
      final rect = card();
      expect(rect.left, 46);
      expect(rect.right, 340);
      expect(rect.center.dy, 300);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpLocalized(
        stack(),
        size: const Size(360, 800),
        locale: AppLocales.english,
      );
      final mirrored = card();
      expect(mirrored.left, 20);
      expect(mirrored.right, 314);
    });

    testWidgets('measures what it lays out to', (tester) async {
      final general = mockHome();
      final partial = mockHome(scenario: HomeMockScenario.partial);
      final back = mockHome(scenario: HomeMockScenario.welcomeBack);
      final kids = mockHome(kids: true);
      final cases = [
        (general, BubbleMode.next, 170.0),
        (partial, BubbleMode.resume, 176.0),
        (back, BubbleMode.reviewFirst, null),
        (kids, BubbleMode.kids, 146.0),
      ];
      for (final locale in AppLocales.supported) {
        // A new tree: the localization keeps its first locale.
        await tester.pumpWidget(const SizedBox());
        for (final scale in [1.0, 1.6]) {
          for (final (home, mode, height) in cases) {
            for (final width in [294.0, 254.0]) {
              late double measured;
              await tester.pumpLocalized(
                MediaQuery.withClampedTextScaling(
                  minScaleFactor: scale,
                  maxScaleFactor: scale,
                  child: Builder(
                    builder: (context) {
                      measured = LessonBubble.measure(
                        context,
                        mode: mode,
                        lesson: _current(home),
                        home: home,
                        width: width,
                      );
                      return _bubble(home, mode: mode, width: width);
                    },
                  ),
                ),
                locale: locale,
              );
              expect(
                Directionality.of(tester.element(find.byType(LessonBubble))),
                locale == AppLocales.arabic
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              );
              final drawn = tester.getSize(find.byType(LessonBubble)).height;
              expect(
                measured,
                moreOrLessEquals(drawn, epsilon: .01),
                reason: '$mode ${locale.languageCode} ×$scale at $width',
              );
              if (height != null && scale == 1 && locale == AppLocales.arabic) {
                expect(drawn, height, reason: '$mode');
              }
            }
          }
        }
      }
    });
  });

  group('Stone', () {
    testWidgets('says its lesson, kind, minutes and state', (tester) async {
      final unit = mockHome().currentUnit!;
      final taps = <int>[];
      await tester.pumpLocalized(
        Center(
          child: Wrap(
            spacing: 16,
            children: [
              for (final (k, lesson) in unit.lessons.indexed)
                if (unit.isLast(k))
                  Stone.last(
                    lesson: lesson,
                    state: _stateOf(unit, k),
                    emar: false,
                    onPressed: () => taps.add(k),
                  )
                else
                  Stone.lesson(
                    lesson: lesson,
                    index: k,
                    state: _stateOf(unit, k),
                    emar: false,
                    offline: false,
                    pulse: false,
                    hit: false,
                    pop: 1,
                    onPressed: () => taps.add(k),
                  ),
            ],
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('الدرس 1، كلمات المزرعة، مفردات، 5 دقائق، مكتمل'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'الدرس 4، يوم في حياة سارة، نص تفاعلي، 7 دقائق، الدرس الحالي',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'الدرس 5، الصندوق القابل للكسر، محادثة ذكية، 5 دقائق، مقفل',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'مراجعة الوحدة، اختبار، 10 دقائق، مقفلة، تُفتح بعد إكمال الدروس',
        ),
        findsOneWidget,
      );

      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.bySemanticsLabel(RegExp('^الدرس 4،')));
      expect(haptics, isEmpty, reason: 'the current stone opens, no tick');
      await tester.tap(find.bySemanticsLabel(RegExp('^الدرس 1،')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      expect(taps, [3, 0]);
      await _settle(tester);
    });

    testWidgets('Emar: its page, suggested, open', (tester) async {
      final unit = mockHome(emar: true).currentUnit!;
      final current = unit.currentLesson;
      final open = unit.lessons[current + 1];
      await tester.pumpLocalized(
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stone.lesson(
                lesson: unit.lessons[current],
                index: current,
                state: StoneState.current,
                emar: true,
                offline: false,
                pulse: true,
                hit: false,
                pop: 1,
                onPressed: () {},
              ),
              Stone.lesson(
                lesson: open,
                index: current + 1,
                state: StoneState.open,
                emar: true,
                offline: false,
                pulse: false,
                hit: true,
                pop: 1,
                onPressed: () {},
              ),
              Stone.last(
                lesson: unit.lessons.last,
                state: StoneState.open,
                emar: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^الدرس 4، .*، صفحة 36، الدرس المقترح$')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^الدرس 5، .*، صفحة 39، متاح$')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'، متاحة، صفحة 41$')),
        findsOneWidget,
      );
      await _settle(tester);
    });

    testWidgets('kids and the review station', (tester) async {
      final unit = mockHome(kids: true).currentUnit!;
      final review = mockHome().review!;
      await tester.pumpLocalized(
        Center(
          child: Wrap(
            children: [
              for (final (k, lesson) in unit.lessons.indexed)
                Stone.kid(
                  lesson: lesson,
                  state: _stateOf(unit, k),
                  onPressed: () {},
                ),
              Stone.station(review: review, pulse: true, onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Red، مكتمل'), findsOneWidget);
      expect(find.bySemanticsLabel('Green، الدرس الحالي'), findsOneWidget);
      expect(find.bySemanticsLabel('Colors song، مقفل'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'المحطة الأولى: راجع اليوم، 12 كلمة و3 مفاهيم، نحو 5 دقائق، الحالية',
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(Stone).first), const Size(64, 64));
      expect(
        tester.getSize(find.byType(Stone).at(unit.currentLesson)),
        const Size(80, 80),
      );
      await _settle(tester);
    });

    testWidgets('the new current stone grows about its centre', (tester) async {
      final lesson = _current(mockHome());
      final state = ValueNotifier(StoneState.locked);
      addTearDown(state.dispose);
      await tester.pumpLocalized(
        Center(
          child: ValueListenableBuilder(
            valueListenable: state,
            builder: (context, value, _) => Stone.lesson(
              lesson: lesson,
              index: 3,
              state: value,
              emar: false,
              offline: false,
              pulse: false,
              hit: false,
              pop: 1,
              onPressed: () {},
            ),
          ),
        ),
      );
      final centre = tester.getCenter(find.byType(AnimatedContainer));
      expect(
        tester.getSize(find.byType(AnimatedContainer)),
        const Size(48, 48),
      );
      state.value = StoneState.current;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final halfway = tester.getSize(find.byType(AnimatedContainer)).width;
      expect(halfway, greaterThan(48));
      expect(halfway, lessThan(64));
      expect(tester.getCenter(find.byType(AnimatedContainer)), centre);
      await _settle(tester);
      expect(
        tester.getSize(find.byType(AnimatedContainer)),
        const Size(64, 64),
      );
    });

    testWidgets('labels: the kind, Emar\'s page, the lighthouse waiting', (
      tester,
    ) async {
      final emar = mockHome(emar: true).currentUnit!;
      final general = mockHome().currentUnit!;
      await tester.pumpLocalized(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoneLabel(
                lesson: emar.lessons[3],
                current: true,
                hit: false,
                emar: true,
                last: false,
                locked: false,
                kids: false,
              ),
              StoneLabel(
                lesson: general.lessons.last,
                current: false,
                hit: false,
                emar: false,
                last: true,
                locked: true,
                kids: false,
              ),
              const StoneLabel.station(),
            ],
          ),
        ),
      );
      expect(find.text('نص · ص 36'), findsOneWidget);
      expect(find.text('مراجعة الوحدة'), findsOneWidget);
      expect(find.text('تُفتح بعد إكمال الدروس'), findsOneWidget);
      expect(find.text('راجع'), findsOneWidget);
    });
  });

  testWidgets('Arabic lines that wrap keep the running floor; one line its '
      'design height', (tester) async {
    double heightOf(String text) =>
        tester.widget<Text>(find.text(text)).style!.height!;
    final home = mockHome();
    const meta = 'نص تفاعلي، 7 دقائق';
    for (final (scale, height) in [(1.0, 20 / 13), (1.6, 1.7)]) {
      await tester.pumpLocalized(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: _bubble(home, width: 254),
        ),
      );
      expect(heightOf(meta), closeTo(height, 1e-9), reason: '×$scale');
    }

    final unit = home.currentUnit!;
    await tester.pumpLocalized(
      Center(
        child: StoneCard(
          lesson: unit.lessons[4],
          index: 4,
          state: StoneState.locked,
          lockedAfter: unit.lessons[3].title,
          reviewFirst: false,
          onReplay: () {},
          onStart: () {},
        ),
      ),
    );
    await _settle(tester, 4);
    expect(heightOf(unit.lessons[4].title), 1.7);
    expect(heightOf('يُفتح بعد «${unit.lessons[3].title}»'), 1.7);
  });

  group('StoneCard', () {
    testWidgets('done replays, locked says what comes first, Emar starts', (
      tester,
    ) async {
      final unit = mockHome().currentUnit!;
      final replays = <int>[];
      final starts = <int>[];
      Widget card(int k, StoneState state, {bool reviewFirst = false}) =>
          StoneCard(
            lesson: unit.lessons[k],
            index: k,
            state: state,
            lockedAfter: k == 0 || unit.isLast(k)
                ? null
                : unit.lessons[k - 1].title,
            reviewFirst: reviewFirst,
            onReplay: () => replays.add(k),
            onStart: () => starts.add(k),
          );
      await tester.pumpLocalized(
        SingleChildScrollView(
          child: Column(
            children: [
              card(0, StoneState.done),
              card(4, StoneState.locked),
              card(5, StoneState.locked),
              card(4, StoneState.open),
              card(3, StoneState.current, reviewFirst: true),
            ],
          ),
        ),
      );
      await _settle(tester, 4);

      expect(find.text('مكتمل'), findsOneWidget);
      expect(find.text('كلمات المزرعة'), findsOneWidget);
      expect(find.text('مفردات، 5 دقائق'), findsOneWidget);
      expect(find.text('الدرس 5'), findsNWidgets(2));
      expect(find.text('يُفتح بعد «يوم في حياة سارة»'), findsOneWidget);
      expect(find.text('تُفتح بعد إكمال الدروس'), findsOneWidget);
      expect(find.text('يُفتح بعد «راجع اليوم»'), findsOneWidget);

      await tester.tap(find.text('أعد'));
      await tester.tap(find.text('ابدأ'));
      expect(replays, [0]);
      expect(starts, [4]);
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('أعد'),
                    matching: find.byType(GestureDetector),
                  )
                  .first,
            )
            .height,
        48,
      );
    });

    test('place: centred on its stone, 12 inside the frame, by the gap', () {
      final frame = MapFrame(360);
      final below = StoneCard.place(
        stone: const Offset(312, 78),
        last: false,
        above: false,
        frame: frame,
      );
      expect(below.left, 124);
      expect(below.width, StoneCard.width);
      expect(below.top, 78 + 30 + 10);

      final above = StoneCard.place(
        stone: const Offset(80, 354),
        last: false,
        above: true,
        frame: frame,
      );
      expect(above.left, 12);
      expect(above.bottom, 354 - 30 - 10);

      final lighthouse = StoneCard.place(
        stone: const Offset(196, 354),
        last: true,
        above: true,
        frame: frame,
      );
      expect(lighthouse.left, 84);
      expect(lighthouse.bottom, 354 - 56 - 10);

      final narrow = StoneCard.place(
        stone: const Offset(30, 78),
        last: false,
        above: false,
        frame: MapFrame(320),
      );
      expect(narrow.left, 12);
      final wide = StoneCard.place(
        stone: Offset(MapFrame(600).scaled(312), 78),
        last: false,
        above: false,
        frame: MapFrame(600),
      );
      expect(wide.right, MapFrame(600).fromStart(12));
    });

    testWidgets('above its stone it keeps to the rect\'s bottom', (
      tester,
    ) async {
      final unit = mockHome().currentUnit!;
      final rect = StoneCard.place(
        stone: const Offset(196, 700),
        last: false,
        above: true,
        frame: MapFrame(360),
      );
      await tester.pumpLocalized(
        Stack(
          children: [
            PositionedDirectional(
              start: 360 - rect.right,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: StoneCard(
                lesson: unit.lessons[4],
                index: 4,
                state: StoneState.locked,
                lockedAfter: unit.lessons[3].title,
                reviewFirst: false,
                onReplay: () {},
                onStart: () {},
                above: true,
              ),
            ),
          ],
        ),
        size: const Size(360, 800),
      );
      await _settle(tester, 4);
      final card = tester.getRect(find.byType(Container).first);
      expect(card.bottom, rect.bottom);
      expect(card.left, rect.left);
    });
  });

  group('ReviewBox', () {
    testWidgets('one button with what is due', (tester) async {
      var opened = 0;
      await tester.pumpLocalized(
        Center(
          child: ReviewBox(
            review: mockHome().review!,
            onPressed: () => opened++,
          ),
        ),
      );
      expect(find.text('راجع اليوم'), findsOneWidget);
      expect(find.text('راجع'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'راجع اليوم: 12 كلمة و3 مفاهيم، نحو 5 دقائق. راجع',
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(ReviewBox)), const Size(198, 68));
      await tester.tap(find.byType(ReviewBox));
      expect(opened, 1);
    });

    testWidgets('words only', (tester) async {
      await tester.pumpLocalized(
        const Center(
          child: ReviewBox(
            review: HomeReview(wordsDue: 12, minutes: 5),
            onPressed: _noop,
          ),
        ),
      );
      expect(find.text('12 كلمة، نحو 5 دقائق'), findsOneWidget);
    });
  });

  group('IslandBanner', () {
    for (final size in [const Size(360, 800), narrowViewport]) {
      testWidgets('Emar\'s book line grows it past 236 at ${size.width}', (
        tester,
      ) async {
        final emar = mockHome(emar: true).currentUnit!;
        await tester.pumpLocalized(
          Center(
            child: IslandBanner(unit: emar, emar: true, onOpen: () {}),
          ),
          size: size,
        );
        expect(find.text('كتاب الطالب، الصفحات 30 إلى 41'), findsOneWidget);
        final sub = tester.renderObject<RenderParagraph>(
          find.text('كتاب الطالب، الصفحات 30 إلى 41'),
        );
        expect(sub.didExceedMaxLines, isFalse, reason: 'not cut');
        final width = tester.getSize(find.byType(IslandBanner)).width;
        expect(width, greaterThan(236));
        expect(width, lessThanOrEqualTo(size.width - 40));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Emar keeps only its pages where even that would cut the '
        'book line', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final emar = mockHome(emar: true).currentUnit!;
      await tester.pumpLocalized(
        Center(
          child: IslandBanner(unit: emar, emar: true, onOpen: () {}),
        ),
        size: narrowViewport,
      );
      expect(find.text('كتاب الطالب، الصفحات 30 إلى 41'), findsNothing);
      expect(find.text('الصفحات 30 إلى 41'), findsOneWidget);
      // The screen reader still hears the whole line.
      expect(
        find.bySemanticsLabel(
          RegExp(r'، كتاب الطالب، الصفحات 30 إلى 41\. افتح الوحدة$'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('its unit and progress; Emar its pages', (tester) async {
      final unit = mockHome().currentUnit!;
      final emar = mockHome(emar: true).currentUnit!;
      var opened = 0;
      await tester.pumpLocalized(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IslandBanner(unit: unit, emar: false, onOpen: () => opened++),
              IslandBanner(
                unit: emar,
                emar: true,
                onOpen: () {},
                maxWidth: 320,
              ),
            ],
          ),
        ),
      );
      expect(find.text('الوحدة 3 · يوم في المزرعة'), findsNWidgets(2));
      expect(find.text('3 من 6 دروس'), findsOneWidget);
      expect(find.text('كتاب الطالب، الصفحات 30 إلى 41'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'الوحدة 3، يوم في المزرعة، 3 من 6 دروس. افتح الوحدة',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'، كتاب الطالب، الصفحات 30 إلى 41\. افتح الوحدة$'),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(IslandBanner).first).height, 48);
      expect(
        tester.getSize(find.byType(IslandBanner).first).width,
        lessThanOrEqualTo(236),
      );
      await tester.tap(find.byType(IslandBanner).first);
      expect(opened, 1);
    });

    testWidgets('kids: both names, the stars and the speaker', (tester) async {
      final unit = mockHome(kids: true).currentUnit!;
      var listened = 0;
      var opened = 0;
      await tester.pumpLocalized(
        Center(
          child: IslandBanner.kid(
            unit: unit,
            speaking: false,
            onListen: () => listened++,
            onOpen: () => opened++,
          ),
        ),
      );
      expect(find.text('الألوان'), findsOneWidget);
      expect(find.text('Colors'), findsOneWidget);
      expect(
        find.bySemanticsLabel('الألوان، Colors. نجمتان من 5. افتح الوحدة'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('استمع: الألوان، Colors'));
      await tester.tap(find.text('الألوان'));
      expect((listened, opened), (1, 1));
      expect(tester.getSize(find.byType(IslandBanner)).height, 64);
    });
  });

  testWidgets('KidSayBubble says the unit in both languages', (tester) async {
    final unit = mockHome(kids: true).currentUnit!;
    await tester.pumpLocalized(Center(child: KidSayBubble(unit: unit)));
    await _settle(tester, 3);
    expect(find.text('الألوان'), findsOneWidget);
    expect(find.text('Colors'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('استمع: الألوان، Colors')),
      isSemantics(isLiveRegion: true),
    );
  });

  group('BackToLessonButton', () {
    test('the eyes say which way', () {
      final up = BackFacePose.at(0, up: true);
      final down = BackFacePose.at(1, up: false);
      expect((up.faceDy, up.pupilDy, up.lid), (-2.5, -2.5, 0.0));
      expect((down.faceDy, down.pupilDy, down.lid), (2.5, 2.5, 1.0));
      expect(up.tilt, lessThan(0));
      expect(down.tilt, greaterThan(0));
      final glancing = BackFacePose.at(0, glance: 1, up: true);
      expect(glancing.glanceDy, -1.6);
      expect(glancing.pupilDy, -2.5 - .9);
      expect(BackFacePose.at(1, glance: 1, up: false).glanceDy, 1.6);
    });

    testWidgets('pops in, says the lesson, turns, ticks and hides', (
      tester,
    ) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add('${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var pressed = 0;
      Widget button(BackDirection? direction, {bool review = false}) => Center(
        child: BackToLessonButton(
          direction: direction,
          kids: false,
          lessonTitle: 'يوم في حياة سارة',
          reviewFirst: review,
          arrivedByFlight: true,
          onPressed: () => pressed++,
        ),
      );
      await tester.pumpLocalized(button(BackDirection.up));
      await _settle(tester, 4);
      expect(
        find.bySemanticsLabel('ارجع إلى درسك الحالي، يوم في حياة سارة'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(BackToLessonButton)),
        const Size(56, 56),
      );
      BackFacePainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(BackToLessonButton),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as BackFacePainter;
      expect(painter().pose.lid, 0);

      await tester.pumpLocalized(button(BackDirection.down));
      await _settle(tester, 3);
      expect(painter().pose.lid, 1);

      await tester.tap(find.byType(BackToLessonButton));
      expect(pressed, 1);
      expect(haptics, ['HapticFeedbackType.lightImpact']);

      await tester.pumpLocalized(button(null));
      await _settle(tester, 3);
      expect(
        find.descendant(
          of: find.byType(BackToLessonButton),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(find.bySemanticsLabel(RegExp('^ارجع إلى')), findsNothing);

      await tester.pumpLocalized(button(BackDirection.up, review: true));
      await _settle(tester, 3);
      expect(
        find.bySemanticsLabel('ارجع إلى درسك الحالي، راجع اليوم'),
        findsOneWidget,
      );
    });

    testWidgets('kids: 64', (tester) async {
      await tester.pumpLocalized(
        const Center(
          child: BackToLessonButton(
            direction: BackDirection.down,
            kids: true,
            lessonTitle: 'Green',
            reviewFirst: false,
            arrivedByFlight: false,
            onPressed: _noop,
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(BackToLessonButton)),
        const Size(64, 64),
      );
    });
  });

  testLayouts('every map object fits', (tester, layout) async {
    await tester.pumpLocalized(
      Scaffold(body: _board(mockHome(), mockHome(kids: true))),
      locale: layout.locale,
      themeMode: layout.themeMode,
      size: layout.size,
    );
    await _settle(tester, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every target is big enough and labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(
      Scaffold(body: _board(mockHome(), mockHome(kids: true))),
      size: narrowViewport,
    );
    await _settle(tester, 4);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}

void _noop() {}
