import 'dart:math' as math;

import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/goal_ring.dart';
import 'package:englizia/core/design_system/widgets/streak_flame.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_state.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/scene/stage_metrics.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/day_header.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/goal_ring.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/kid_week.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/level_complete_card.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/notice_cards.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/say_bubble.dart';
import 'package:englizia/features/home/presentation/home/widgets/header/top_bar.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';
import '../../helpers/pump_app.dart';

final _morning = DateTime(2026, 11, 5, 10);
final _evening = DateTime(2026, 11, 5, 19, 30);

HomeState _state(
  HomeMockScenario scenario, {
  bool kids = false,
  bool emar = false,
  DateTime? now,
  bool levelJustDone = false,
}) {
  final at = now ?? _morning;
  return HomeState(
    now: at,
    load: LoadStatus.ready,
    home: mockHome(scenario: scenario, kids: kids, emar: emar, now: at),
    levelJustDone: levelJustDone,
  );
}

StageMetrics _metrics({
  double width = 375,
  double head = DayHeader.base,
  double topSlot = 0,
  double collapse = 0,
  double pull = 0,
  bool kids = false,
}) => StageMetrics(
  width: width,
  height: 700,
  head: head,
  topSlot: topSlot,
  collapse: collapse,
  scroll: collapse,
  pull: pull,
  kids: kids,
);

/// The header as the stage stacks it: the day header under the top bar, the
/// ring and the say bubble over both.
class _Stage extends StatefulWidget {
  const _Stage({required this.state, this.say});

  final HomeState state;
  final String? say;

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  double head = DayHeader.base;
  double top = 0;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final home = state.home!;
    final notices = state.notices(emailReminder: false);
    final m = _metrics(
      width: MediaQuery.sizeOf(context).width,
      head: head,
      topSlot: top,
      kids: home.kids,
    );
    final card = DayHeader.slotCard(state, notices);
    final guide = resolveGuide(
      flying: false,
      collapsed: m.collapsed,
      hasCurrentIsland: true,
      backButton: false,
      pull: 0,
      levelCardShown: false,
      card: card,
      current: 0,
    );
    final f = home.goalMinutes == 0
        ? 0.0
        : math.min(1.0, home.todayMinutes / home.goalMinutes);
    final inside = ringShowsMinutes(kids: home.kids, guide: guide, m: m);
    return Material(
      child: Stack(
        children: [
          PositionedDirectional(
            top: StageMetrics.topBar,
            start: 0,
            end: 0,
            child: DayHeader(
              state: state,
              notices: notices,
              greetingOpacity: m.greetingOpacity,
              onHeight: (h) => setState(() => head = h),
              onTopSlot: (t) => setState(() => top = t),
              topStrip: null,
              onCloseEvent: () {},
              onLevelCheck: () {},
              onPlacement: () {},
              onStartLevel: () {},
              onListen: () {},
              minutesInRing: inside,
              cardGuide: guide is GuideOnCard,
            ),
          ),
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: TopBar(
              trackTitle: home.enrollment.title,
              kids: home.kids,
              v01: home.v01,
              emar: home.enrollment.levelLabel == HomeLevelLabel.grade,
              skeleton: false,
              streak: home.streak?.current ?? 0,
              freezes: home.streak?.freezes ?? 0,
              maxFreezes: home.streak?.maxFreezes ?? 0,
              atRisk: state.atRisk,
              stars: home.learner.stars,
              dividerOn: m.dividerOn,
              overrides: HeaderOverrides.none,
              wobble: const AlwaysStoppedAnimation(0),
              onTracks: () {},
              onStreak: () {},
              onPageSearch: () {},
            ),
          ),
          Positioned.fill(
            child: GoalRingOverlay(
              metrics: m,
              fraction: f,
              success: f >= 1,
              minutes: home.todayMinutes,
              goal: home.goalMinutes,
              minutesInside: inside,
              guide: guide,
              expression: GoalRingOverlay.expressionFor(f, kids: home.kids),
              waving: false,
              overrides: HeaderOverrides.none,
              kids: home.kids,
              v01: home.v01,
              onGuideTap: () {},
            ),
          ),
          Positioned.fill(
            child: SayBubble(text: widget.say, metrics: m),
          ),
        ],
      ),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _ringPaint() => find.descendant(
  of: find.byType(GoalRingOverlay),
  matching: find.byType(GoalRing),
);

void main() {
  setUpAll(initLocalizationForTests);

  group('day header texts', () {
    testWidgets('general in the morning', (tester) async {
      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.general)),
      );
      await _settle(tester);
      expect(find.text('صباح الخير، أحمد'), findsOneWidget);
      expect(find.text('A2، الوحدة 3 من 8'), findsOneWidget);
      expect(find.text('3 دقائق وتحقق هدف اليوم'), findsOneWidget);
      expect(find.text('7/10 د'), findsOneWidget);
    });

    testWidgets('at risk in the evening', (tester) async {
      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.atRisk, now: _evening)),
      );
      await _settle(tester);
      expect(find.text('مساء الخير، أحمد'), findsOneWidget);
      expect(find.text('5 دقائق تحافظ على أيامك السبعة'), findsOneWidget);
      expect(find.text('3 دقائق وتحقق هدف اليوم'), findsNothing);
    });

    testWidgets('goal reached, first day, welcome back', (tester) async {
      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.goalReached)),
      );
      await _settle(tester);
      expect(find.text('حققت هدف اليوم'), findsOneWidget);

      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.firstDay)),
      );
      await _settle(tester);
      expect(find.text('أهلًا أحمد'), findsOneWidget);
      expect(find.text('درسك الأول ينتظرك'), findsOneWidget);

      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.welcomeBack)),
      );
      await _settle(tester);
      expect(find.text('أهلًا بعودتك يا أحمد'), findsOneWidget);
    });

    testWidgets('Emar names its grade', (tester) async {
      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.general, emar: true)),
      );
      await _settle(tester);
      expect(find.text('الصف 7، الوحدة 3 من 6'), findsOneWidget);
      expect(find.bySemanticsLabel('ابحث برقم الصفحة'), findsOneWidget);
    });

    testWidgets('v0.1: no ring, no flame, the guide waves', (tester) async {
      await tester.pumpLocalized(_Stage(state: _state(HomeMockScenario.v01)));
      await _settle(tester);
      expect(find.text('أكمل درسك التالي'), findsOneWidget);
      expect(_ringPaint(), findsNothing);
      expect(find.textContaining('/10'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('رصيد التجميد')), findsNothing);
      expect(find.bySemanticsLabel('صباح الخير أحمد'), findsOneWidget);
    });

    testWidgets('kids: hello, listen, streak, week, stars', (tester) async {
      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.general, kids: true)),
      );
      await _settle(tester);
      expect(find.text('أهلًا ليان!'), findsOneWidget);
      expect(find.text('4 أيام'), findsOneWidget);
      expect(find.byType(KidWeek), findsOneWidget);
      expect(
        find.bySemanticsLabel('أهلًا ليان. 4 أيام متتالية. 14 نجمة.'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('استمع')),
        matchesSemantics(
          label: 'استمع',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('14 نجمة'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('تبديل المسار')), findsNothing);
      expect(_ringPaint(), findsNothing);
    });

    testWidgets('English mirrors and reads naturally', (tester) async {
      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.general)),
        locale: AppLocales.english,
      );
      await _settle(tester);
      expect(find.text("3 minutes to reach today's goal"), findsOneWidget);
      expect(find.text('7/10 min'), findsOneWidget);
      final ring = tester.getRect(_ringPaint());
      expect(ring.right, closeTo(375 - 20, .01));
    });
  });

  group('day header semantics', () {
    testWidgets('the group, then the status as its own node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpLocalized(
        _Stage(state: _state(HomeMockScenario.atRisk, now: _evening)),
      );
      await _settle(tester);
      expect(
        find.bySemanticsLabel(
          'مساء الخير أحمد. 5 من 10 دقائق اليوم. 7 أيام متتالية.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('5 دقائق تحافظ على أيامك السبعة'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          '7 أيام متتالية، رصيد التجميد 2 من 3. افتح التفاصيل',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('تبديل المسار، الإنجليزية العامة'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('بلبل، المرشد'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tap targets and labels meet the guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      for (final state in [
        _state(HomeMockScenario.general),
        _state(HomeMockScenario.freezeUsed),
        _state(HomeMockScenario.levelCheck),
        _state(HomeMockScenario.levelComplete),
        _state(HomeMockScenario.general, kids: true),
        _state(HomeMockScenario.general, emar: true),
      ]) {
        await tester.pumpLocalized(_Stage(state: state), size: narrowViewport);
        await _settle(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
      handle.dispose();
    });
  });

  group('day header measure', () {
    testWidgets('reports the design height and the top slot', (tester) async {
      final heights = <double>[];
      final tops = <double>[];
      final state = _state(HomeMockScenario.general);
      Widget header({Widget? strip}) => Material(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: DayHeader(
            state: state,
            notices: state.notices(emailReminder: false),
            greetingOpacity: 1,
            onHeight: heights.add,
            onTopSlot: tops.add,
            topStrip: strip,
            onCloseEvent: () {},
            onLevelCheck: () {},
            onPlacement: () {},
            onStartLevel: () {},
            onListen: () {},
          ),
        ),
      );
      await tester.pumpLocalized(header());
      await _settle(tester);
      expect(heights.last, DayHeader.base);
      expect(tops.last, 0);

      await tester.pumpLocalized(header(strip: const SizedBox(height: 40)));
      await _settle(tester);
      expect(tops.last, 52);
      expect(heights.last, DayHeader.base + 52);
    });

    test('the formula is the design\'s', () {
      expect(
        DayHeader.formula(
          kids: false,
          top: HomeTopNotice.email,
          card: HomeCardNotice.freeze,
        ),
        114 + 68 + 120,
      );
      expect(
        DayHeader.formula(
          kids: true,
          top: HomeTopNotice.offline,
          card: HomeCardNotice.none,
        ),
        136 + 52,
      );
      expect(DayHeader.cardSlotOf(HomeCardNotice.broke), 104);
      expect(DayHeader.cardSlotOf(HomeCardNotice.placement), 92);
      expect(DayHeader.cardSlotOf(HomeCardNotice.levelDone), 140);
    });

    test('a level just done keeps its card at the horizon', () {
      final later = _state(HomeMockScenario.levelComplete);
      final notices = later.notices(emailReminder: false);
      expect(notices.card, HomeCardNotice.levelDone);
      expect(DayHeader.slotCard(later, notices), HomeCardNotice.levelDone);
      final now = _state(HomeMockScenario.levelComplete, levelJustDone: true);
      expect(DayHeader.slotCard(now, notices), HomeCardNotice.none);
    });

    testWidgets('the card slot grows with its card', (tester) async {
      final heights = <double>[];
      final state = _state(HomeMockScenario.freezeUsed);
      await tester.pumpLocalized(
        Material(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: DayHeader(
              state: state,
              notices: state.notices(emailReminder: false),
              greetingOpacity: 1,
              onHeight: heights.add,
              onTopSlot: (_) {},
              topStrip: null,
              onCloseEvent: () {},
              onLevelCheck: () {},
              onPlacement: () {},
              onStartLevel: () {},
              onListen: () {},
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(NoticeCard), findsOneWidget);
      expect(
        heights.last,
        greaterThanOrEqualTo(
          DayHeader.formula(
            kids: false,
            top: HomeTopNotice.none,
            card: HomeCardNotice.freeze,
          ),
        ),
      );
    });
  });

  group('notice cards', () {
    final event = HomeEvent(
      id: 'ev',
      kind: HomeEventKind.freezeUsed,
      on: DateTime(2026, 11, 4),
      streak: 7,
      freezesLeft: 1,
    );
    const streak = Streak(current: 7, longest: 12, freezes: 1, maxFreezes: 3);

    Future<void> pumpCard(WidgetTester tester, Widget card) async {
      await tester.pumpLocalized(
        Material(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(20),
            child: Align(alignment: Alignment.topCenter, child: card),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('freeze used: texts, label, close', (tester) async {
      final handle = tester.ensureSemantics();
      var closed = 0;
      await pumpCard(
        tester,
        NoticeCard.freeze(
          event: event,
          streak: streak,
          perWeek: 1,
          showGuide: true,
          onClose: () => closed++,
        ),
      );
      expect(find.text('تجميد مستخدم أمس'), findsOneWidget);
      expect(
        find.text('استخدمنا تجميدًا وحافظنا على أيامك السبعة'),
        findsOneWidget,
      );
      expect(
        find.text('بقي تجميد واحد من 3. يُضاف واحد كل أسبوع.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'استخدمنا تجميدًا أمس وحافظنا على أيامك السبعة. بقي تجميد واحد من 3.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('أغلق'));
      expect(closed, 1);
      handle.dispose();
    });

    testWidgets('no weekly freeze: the line is left out', (tester) async {
      await pumpCard(
        tester,
        NoticeCard.freeze(
          event: event,
          streak: streak,
          perWeek: 0,
          showGuide: false,
          onClose: () {},
        ),
      );
      expect(find.text('بقي تجميد واحد من 3.'), findsOneWidget);
      expect(find.textContaining('كل أسبوع'), findsNothing);
    });

    testWidgets('streak ended', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(
        tester,
        NoticeCard.broke(
          event: HomeEvent(
            id: 'ev2',
            kind: HomeEventKind.streakBroken,
            on: DateTime(2026, 11, 4),
            streak: 7,
          ),
          showGuide: true,
          onClose: () {},
        ),
      );
      expect(
        find.text('انقطعت أيامك المتتالية. ابدأ من جديد اليوم'),
        findsOneWidget,
      );
      expect(
        find.text(
          'وصلت إلى 7 أيام، ولم يبقَ تجميد. درس واحد اليوم يبدأ سلسلة جديدة.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'انقطعت أيامك المتتالية بعد 7 أيام. ابدأ من جديد اليوم.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('level check and deferred test', (tester) async {
      final handle = tester.ensureSemantics();
      var started = 0;
      await pumpCard(tester, NoticeCard.levelCheck(onStart: () => started++));
      expect(
        find.bySemanticsLabel(
          'فحص المستوى: فحص قصير يحدد إن كان مستواك مناسبًا. ابدأ الفحص',
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('ابدأ الفحص'));
      expect(started, 1);

      await pumpCard(
        tester,
        NoticeCard.placement(
          minutes: (min: 12, max: 15),
          onStart: () => started++,
        ),
      );
      expect(
        find.text('12 إلى 15 دقيقة لتبدأ من المستوى المناسب'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'اختبر مستواك: 12 إلى 15 دقيقة لتبدأ من المستوى المناسب',
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('ابدأ'));
      expect(started, 2);
      handle.dispose();
    });

    for (final locale in AppLocales.supported) {
      testWidgets('the offers keep their words whole at 320dp with the '
          'largest text (${locale.languageCode})', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final card in [
          NoticeCard.levelCheck(onStart: () {}),
          NoticeCard.placement(minutes: (min: 12, max: 15), onStart: () {}),
        ]) {
          await tester.pumpLocalized(
            Material(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(20),
                child: Align(alignment: Alignment.topCenter, child: card),
              ),
            ),
            locale: locale,
            size: narrowViewport,
          );
          await _settle(tester);
          expect(tester.takeException(), isNull);
          final texts = find.descendant(
            of: find.byWidget(card),
            matching: find.byType(RichText),
          );
          for (final text in texts.evaluate()) {
            final paragraph = text.renderObject! as RenderParagraph;
            expect(
              paragraph.size.width,
              greaterThanOrEqualTo(
                paragraph.getMinIntrinsicWidth(double.infinity) - .5,
              ),
              reason: paragraph.text.toPlainText(),
            );
          }
        }
      });
    }

    testWidgets('an offer\'s button goes under its texts where it would '
        'squeeze them', (tester) async {
      Future<(Rect, Rect)> layout(Size size, double scale) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpLocalized(
          Material(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: NoticeCard.levelCheck(onStart: () {}),
              ),
            ),
          ),
          locale: AppLocales.english,
          size: size,
        );
        await _settle(tester);
        return (
          tester.getRect(find.text('A short check to see if your level fits')),
          tester.getRect(find.text('Start the check')),
        );
      }

      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (body, button) = await layout(defaultViewport, 1);
      expect(button.top, lessThan(body.bottom), reason: 'beside');
      final (squeezed, under) = await layout(narrowViewport, 1.3);
      expect(under.top, greaterThan(squeezed.bottom), reason: 'under');
    });

    testWidgets('level complete: kicker, title, start', (tester) async {
      final handle = tester.ensureSemantics();
      var started = 0;
      final home = mockHome(scenario: HomeMockScenario.levelComplete);
      await pumpCard(
        tester,
        LevelCompleteCard(
          home: home,
          showGuide: true,
          onStart: () => started++,
        ),
      );
      expect(find.text('8 من 8 وحدات'), findsOneWidget);
      expect(find.text('أكملت مستوى A2'), findsOneWidget);
      expect(find.bySemanticsLabel('أكملت مستوى A2. ابدأ B1'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('ابدأ B1'));
      expect(started, 1);
      handle.dispose();
    });

    testWidgets('a grade is named', (tester) async {
      final emar = mockHome(
        scenario: HomeMockScenario.levelComplete,
        emar: true,
      );
      await pumpCard(
        tester,
        LevelCompleteCard(home: emar, showGuide: false, onStart: () {}),
      );
      expect(find.text(LevelCompleteCard.titleOf(emar)), findsOneWidget);
      expect(LevelCompleteCard.titleOf(emar), startsWith('أكملت الصف'));
    });
  });

  group('the one guide', () {
    GuidePlacement guide({
      bool flying = false,
      bool collapsed = false,
      bool hasCurrentIsland = true,
      bool backButton = false,
      double pull = 0,
      bool levelCardShown = false,
      HomeCardNotice card = HomeCardNotice.none,
      GuidePlacement? forced,
    }) => resolveGuide(
      flying: flying,
      collapsed: collapsed,
      hasCurrentIsland: hasCurrentIsland,
      backButton: backButton,
      pull: pull,
      levelCardShown: levelCardShown,
      card: card,
      current: 3,
      forced: forced,
    );

    test('forced, flying, then the collapsed map', () {
      expect(
        guide(forced: const GuideHop(1, 2, .5), flying: true, collapsed: true),
        const GuideHop(1, 2, .5),
      );
      expect(guide(flying: true, collapsed: true), const GuideFlying());
      expect(guide(collapsed: true), const GuideBesideStone(3));
      expect(
        guide(collapsed: true, backButton: true, pull: 40),
        const GuideInBackButton(),
      );
    });

    test('collapsed with no current island: the pull, then the card', () {
      expect(
        guide(
          collapsed: true,
          hasCurrentIsland: false,
          card: HomeCardNotice.levelDone,
        ),
        const GuideOnCard(),
      );
      expect(
        guide(collapsed: true, hasCurrentIsland: false),
        const GuideInRing(),
      );
    });

    test('hanging from the pull\'s threshold, over a card', () {
      expect(guide(pull: AppMotion.homePullGuideAt - .1), const GuideInRing());
      expect(
        guide(pull: AppMotion.homePullGuideAt, card: HomeCardNotice.freeze),
        const GuideHanging(),
      );
    });

    test('on a freeze, broke or level card; in the ring otherwise', () {
      for (final card in [
        HomeCardNotice.freeze,
        HomeCardNotice.broke,
        HomeCardNotice.levelDone,
      ]) {
        expect(guide(card: card), const GuideOnCard(), reason: '$card');
      }
      expect(guide(levelCardShown: true), const GuideOnCard());
      expect(guide(card: HomeCardNotice.levelCheck), const GuideInRing());
      expect(guide(card: HomeCardNotice.placement), const GuideInRing());
    });

    test('the ring shows the minutes once the guide left, header open', () {
      const away = GuideInBackButton();
      expect(ringShowsMinutes(kids: false, guide: away, m: _metrics()), isTrue);
      expect(
        ringShowsMinutes(
          kids: false,
          guide: away,
          m: _metrics(collapse: DayHeader.base / 2),
        ),
        isFalse,
      );
      expect(
        ringShowsMinutes(kids: true, guide: away, m: _metrics(kids: true)),
        isFalse,
      );
      expect(
        ringShowsMinutes(
          kids: false,
          guide: const GuideInRing(),
          m: _metrics(),
        ),
        isFalse,
      );
    });
  });

  group('goal ring', () {
    test('the guide\'s face follows the fraction', () {
      expect(GoalRingOverlay.expressionFor(0), MascotExpression.welcome);
      expect(GoalRingOverlay.expressionFor(.5), MascotExpression.encourage);
      expect(GoalRingOverlay.expressionFor(1), MascotExpression.happy);
      expect(
        GoalRingOverlay.expressionFor(1, kids: true),
        MascotExpression.welcome,
      );
    });

    test('sparks fly out and fade', () {
      final first = RingSparksPainter.sparkAt(0, 0);
      expect(first.opacity, 0);
      final mid = RingSparksPainter.sparkAt(0, .2);
      expect(mid.radius, inInclusiveRange(44, 66));
      expect(mid.opacity, greaterThan(0));
      final last = RingSparksPainter.sparkAt(5, 1);
      expect(last.opacity, closeTo(0, 1e-9));
      expect(last.radius, closeTo(66, 1e-9));
    });

    Widget ring(
      StageMetrics m, {
      GuidePlacement guide = const GuideInRing(),
      HeaderOverrides overrides = HeaderOverrides.none,
      VoidCallback? onTap,
      bool inside = false,
    }) => Material(
      child: GoalRingOverlay(
        metrics: m,
        fraction: .7,
        success: false,
        minutes: 7,
        goal: 10,
        minutesInside: inside,
        guide: guide,
        expression: MascotExpression.encourage,
        waving: false,
        overrides: overrides,
        kids: false,
        v01: false,
        onGuideTap: onTap ?? () {},
      ),
    );

    testWidgets('sits on its placeholder, folds to the top bar', (
      tester,
    ) async {
      await tester.pumpLocalized(ring(_metrics(topSlot: 52)));
      await _settle(tester);
      expect(
        tester.getRect(_ringPaint()),
        const Rect.fromLTWH(20, 108, 96, 96),
      );
      final drawn = tester.widget<GoalRing>(_ringPaint());
      expect(drawn.share, closeTo(.7, 1e-9));
      expect(drawn.stroke, 8);

      await tester.pumpLocalized(
        ring(
          _metrics(collapse: DayHeader.base),
          guide: const GuideBesideStone(2),
        ),
      );
      await _settle(tester);
      final folded = tester.getRect(_ringPaint());
      expect(folded.left, closeTo(20, .01));
      expect(folded.top, closeTo(14, .01));
      expect(folded.width, closeTo(28, .01));
    });

    testWidgets('M1 draws the arc in; overrides win', (tester) async {
      await tester.pumpLocalized(
        ring(_metrics(), overrides: const HeaderOverrides(ringArcIn: 0)),
      );
      await _settle(tester);
      expect(tester.widget<GoalRing>(_ringPaint()).share, 0);

      await tester.pumpLocalized(
        ring(
          _metrics(),
          overrides: const HeaderOverrides(ringFraction: 1, minutes: 12),
          inside: true,
        ),
      );
      await _settle(tester);
      expect(tester.widget<GoalRing>(_ringPaint()).share, 1);
      expect(find.text('12/10'), findsOneWidget);
    });

    testWidgets('the guide is a button only while in the ring', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpLocalized(ring(_metrics(), onTap: () => taps++));
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('بلبل، المرشد'));
      expect(taps, 1);

      await tester.pumpLocalized(
        ring(_metrics(), guide: const GuideOnCard(), onTap: () => taps++),
      );
      await _settle(tester);
      expect(find.bySemanticsLabel('بلبل، المرشد'), findsNothing);
      await tester.tapAt(tester.getCenter(_ringPaint()));
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('say bubble', () {
    testWidgets('the guide\'s line', (tester) async {
      await tester.pumpLocalized(const SizedBox());
      expect(guideSayText(today: 7, goal: 10), 'باقي 3 دقائق لهدفك');
      expect(guideSayText(today: 12, goal: 10), 'حققت هدفك اليوم!');
    });

    testWidgets('beside the ring while the header is open', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpLocalized(
        Material(
          child: SayBubble(text: 'باقي 3 دقائق لهدفك', metrics: _metrics()),
        ),
      );
      await _settle(tester);
      final bubble = find.text('باقي 3 دقائق لهدفك');
      expect(bubble, findsOneWidget);
      final rect = tester.getRect(
        find.ancestor(of: bubble, matching: find.byType(DecoratedBox)).first,
      );
      expect(rect.left, closeTo(SayBubble.end, .01));
      expect(rect.top, closeTo(SayBubble.top, .01));
      expect(rect.width, lessThanOrEqualTo(SayBubble.maxWidth));

      await tester.pumpLocalized(
        Material(
          child: SayBubble(
            text: 'باقي 3 دقائق لهدفك',
            metrics: _metrics(collapse: 20),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('باقي 3 دقائق لهدفك'), findsNothing);
      handle.dispose();
    });

    testWidgets('a tap waves for 1.4 s and speaks for 2 s', (tester) async {
      final tap = GuideTapController()..tap('line');
      addTearDown(tap.dispose);
      expect(tap.waving, isTrue);
      expect(tap.say, 'line');
      await tester.pump(AppMotion.homeWaveHold);
      expect(tap.waving, isFalse);
      expect(tap.say, 'line');
      await tester.pump(AppMotion.homeSayHold - AppMotion.homeWaveHold);
      expect(tap.say, isNull);
      tap
        ..tap('again')
        ..clear();
      expect(tap.say, isNull);
      expect(tap.waving, isFalse);
    });
  });

  group('top bar', () {
    Widget bar({
      bool kids = false,
      bool v01 = false,
      bool emar = false,
      bool skeleton = false,
      bool atRisk = false,
      HeaderOverrides overrides = HeaderOverrides.none,
      Animation<double> wobble = const AlwaysStoppedAnimation(0),
      VoidCallback? onTracks,
      VoidCallback? onStreak,
      VoidCallback? onSearch,
      VoidCallback? onLongPress,
    }) => Material(
      child: Align(
        alignment: Alignment.topCenter,
        child: TopBar(
          trackTitle: 'الإنجليزية العامة',
          kids: kids,
          v01: v01,
          emar: emar,
          skeleton: skeleton,
          streak: 7,
          freezes: 2,
          maxFreezes: 3,
          atRisk: atRisk,
          stars: 14,
          dividerOn: false,
          overrides: overrides,
          wobble: wobble,
          onTracks: onTracks ?? () {},
          onStreak: onStreak ?? () {},
          onPageSearch: onSearch ?? () {},
          onLongPress: onLongPress,
        ),
      ),
    );

    testWidgets('the capsule, the flame, the search open their sheets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final opened = <String>[];
      await tester.pumpLocalized(
        bar(
          emar: true,
          onTracks: () => opened.add('tracks'),
          onStreak: () => opened.add('streak'),
          onSearch: () => opened.add('search'),
        ),
      );
      await _settle(tester);
      await tester.tap(
        find.bySemanticsLabel('تبديل المسار، الإنجليزية العامة'),
      );
      await tester.tap(
        find.bySemanticsLabel(
          '7 أيام متتالية، رصيد التجميد 2 من 3. افتح التفاصيل',
        ),
      );
      await tester.tap(find.bySemanticsLabel('ابحث برقم الصفحة'));
      expect(opened, ['tracks', 'streak', 'search']);
      final capsule = tester.getRect(
        find.bySemanticsLabel('تبديل المسار، الإنجليزية العامة'),
      );
      expect(capsule.right, closeTo(375 - 20, .01));
      expect(capsule.height, 48);
      handle.dispose();
    });

    testWidgets('what each variant shows', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpLocalized(bar());
      await _settle(tester);
      expect(find.bySemanticsLabel('ابحث برقم الصفحة'), findsNothing);
      expect(find.text('7'), findsOneWidget);

      await tester.pumpLocalized(bar(v01: true));
      await _settle(tester);
      expect(find.text('7'), findsNothing);

      await tester.pumpLocalized(bar(skeleton: true, emar: true));
      await _settle(tester);
      expect(find.text('7'), findsNothing);
      expect(find.bySemanticsLabel('ابحث برقم الصفحة'), findsNothing);
      expect(find.text('الإنجليزية العامة'), findsOneWidget);

      await tester.pumpLocalized(bar(kids: true));
      await _settle(tester);
      expect(find.text('الإنجليزية العامة'), findsNothing);
      expect(find.bySemanticsLabel('14 نجمة'), findsOneWidget);
      expect(find.text('7'), findsNothing);
      handle.dispose();
    });

    testWidgets('the goal rolls the streak in', (tester) async {
      await tester.pumpLocalized(
        bar(overrides: const HeaderOverrides(streak: (from: 7, to: 8))),
      );
      await _settle(tester);
      expect(find.text('7'), findsOneWidget);
      await tester.pumpLocalized(
        bar(
          overrides: const HeaderOverrides(
            streak: (from: 7, to: 8),
            streakRoll: 1,
            flameFlip: .5,
            freezeGlint: .5,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('8'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('the flame tilts only while at risk', (tester) async {
      double angle() {
        final rotate = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byType(StreakFlame),
                matching: find.byType(Transform),
              )
              .first,
        );
        final m = rotate.transform;
        return math.atan2(m.entry(1, 0), m.entry(0, 0));
      }

      await tester.pumpLocalized(
        bar(atRisk: true, wobble: const AlwaysStoppedAnimation(1)),
      );
      await _settle(tester);
      expect(angle(), closeTo(4 * math.pi / 180, 1e-6));

      await tester.pumpLocalized(bar(wobble: const AlwaysStoppedAnimation(1)));
      await _settle(tester);
      expect(angle(), closeTo(0, 1e-9));
    });

    testWidgets('mock mode: a long press opens the dev page', (tester) async {
      var dev = 0;
      await tester.pumpLocalized(bar(onLongPress: () => dev++));
      await _settle(tester);
      await tester.longPress(find.byType(TopBar));
      expect(dev, 1);
    });
  });

  group('kid week', () {
    testWidgets('a letter a day, a star on the days learned', (tester) async {
      final start = DateTime(2026, 10, 31); // a Saturday
      final week = StudyWeek(
        goalMinutes: 10,
        today: 3,
        days: [
          for (var i = 0; i < 7; i++)
            StudyDay(
              date: start.add(Duration(days: i)),
              minutes: i < 3 ? 12 : (i == 3 ? 4 : null),
            ),
        ],
      );
      await tester.pumpLocalized(
        Material(
          child: Center(
            child: SizedBox(width: 200, child: KidWeek(week: week)),
          ),
        ),
      );
      await _settle(tester);
      for (final letter in ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']) {
        expect(find.text(letter), findsOneWidget);
      }
      expect(find.byType(KidStar), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });

  testLayouts('the header fits', (tester, layout) async {
    for (final state in [
      _state(HomeMockScenario.general),
      _state(HomeMockScenario.atRisk, now: _evening),
      _state(HomeMockScenario.freezeUsed),
      _state(HomeMockScenario.streakBroken),
      _state(HomeMockScenario.placementDeferred),
      _state(HomeMockScenario.levelComplete),
      _state(HomeMockScenario.v01),
      _state(HomeMockScenario.general, emar: true),
      _state(HomeMockScenario.general, kids: true),
    ]) {
      await tester.pumpLocalized(
        _Stage(state: state, say: 'باقي 3 دقائق لهدفك'),
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }
  });
}
