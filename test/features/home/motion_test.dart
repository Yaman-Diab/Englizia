import 'dart:async';

import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/design_system/mascot/mascot_expression.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/home/presentation/home/cubit/home_cubit.dart';
import 'package:englizia/features/home/presentation/home/geometry/island_layout.dart';
import 'package:englizia/features/home/presentation/home/geometry/map_layout.dart';
import 'package:englizia/features/home/presentation/home/motion/choreographer.dart';
import 'package:englizia/features/home/presentation/home/motion/container_reveal.dart';
import 'package:englizia/features/home/presentation/home/motion/flight_layer.dart';
import 'package:englizia/features/home/presentation/home/motion/lesson_done_motion.dart';
import 'package:englizia/features/home/presentation/home/motion/loop_budget.dart';
import 'package:englizia/features/home/presentation/home/motion/motion_timeline.dart';
import 'package:englizia/features/home/presentation/home/motion/opening_motion.dart';
import 'package:englizia/features/home/presentation/home/motion/unit_done_motion.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';
import 'package:englizia/features/home/presentation/home/scene/map_frame.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/stage_controller.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';
import '../../helpers/fake_lesson_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final _morning = DateTime(2026, 11, 5, 10);

Duration _ms(int ms) => Duration(milliseconds: ms);

HomeSnapshot _home([HomeMockScenario scenario = HomeMockScenario.general]) =>
    mockHome(scenario: scenario, now: _morning);

/// Frame 09: les_it (stone 3) done, 7 + 7 = 14 of 10 minutes, streak 7 → 8.
LessonDoneMoment _lessonDone({
  HomeSnapshot? home,
  int lesson = 3,
  int next = 4,
  int from = 7,
  int to = 14,
  int streakFrom = 7,
  int streakTo = 8,
}) {
  final day = home ?? _home();
  return LessonDoneMoment(
    before: day,
    after: day,
    lesson: lesson,
    next: next,
    minutesFrom: from,
    minutesTo: to,
    goal: 10,
    streakFrom: streakFrom,
    streakTo: streakTo,
  );
}

/// Frame 10: unit 3's last lesson done, unit 4 next.
UnitDoneMoment _unitDone({
  HomeSnapshot? before,
  int unit = 2,
  int? nextUnit = 3,
  bool levelDone = false,
  int from = 7,
  int to = 12,
}) {
  final day = before ?? _home(HomeMockScenario.lastLesson);
  return UnitDoneMoment(
    before: day,
    after: day,
    unit: unit,
    nextUnit: nextUnit,
    levelDone: levelDone,
    minutesFrom: from,
    minutesTo: to,
    goal: 10,
    streakFrom: 7,
    streakTo: 8,
  );
}

void main() {
  setUpAll(initLocalizationForTests);

  group('the helpers', () {
    test('keyframes run straight between their offsets and past the end', () {
      const frames = [(0.0, 1.0), (.5, 3.0), (1.0, 2.0)];
      expect(keyframes(0, frames), 1);
      expect(keyframes(.25, frames), 2);
      expect(keyframes(.75, frames), 2.5);
      expect(keyframes(1, frames), 2);
      // An overshooting curve goes past the last pair, as the web does.
      expect(keyframes(1.1, frames), closeTo(1.8, 1e-9));
    });

    test('a phase holds 0 before it and 1 after it', () {
      expect(phase(99, _ms(100), _ms(200)), 0);
      expect(phase(200, _ms(100), _ms(200)), .5);
      expect(phase(400, _ms(100), _ms(200)), 1);
    });

    test('the beats add up as the design times them', () {
      expect(
        LessonDoneBeats.fill,
        LessonDoneBeats.flyToStone + AppMotion.homeFlyToStone,
      );
      expect(
        LessonDoneBeats.goal,
        LessonDoneBeats.flyHome + AppMotion.homeFlyHome,
      );
      expect(LessonDoneBeats.goalLength, FlightPath.burstLength(6));
      expect(UnitDoneBeats.finishAt, _ms(2630));
    });
  });

  group('M1, the opening', () {
    const opening = OpeningMotion(islands: 8, segment: 3);
    MotionFrame at(int ms) => opening.frameAt(_ms(ms));

    test('it starts from nothing', () {
      final f = at(0);
      expect(f.map.mapOpacity, 0);
      expect(f.map.isleRise, everyElement(0.0));
      expect(f.map.segments, {3: 0.0});
      expect(f.header.ringArcIn, 0);
      expect(f.header.ringGuideIn, 0);
      expect(f.map.bubbleScale, 1);
      expect(f.map.bubbleIn, 0);
      expect(f.map.boxIn, 0);
    });

    test('the map fades in over 200', () {
      expect(
        at(100).map.mapOpacity,
        closeTo(AppMotion.out.transform(.5), 1e-9),
      );
      expect(at(200).map.mapOpacity, 1);
    });

    test('each island rises 80 + 60·j in, over 320', () {
      for (var j = 0; j < 8; j++) {
        final start = 80 + 60 * j;
        expect(at(start).map.isleRise[j], 0, reason: 'island $j at $start');
        expect(at(start + 160).map.isleRise[j], inExclusiveRange(0, 1));
        expect(at(start + 320).map.isleRise[j], 1);
      }
      expect(HomeEntrance.isle(7), _ms(500));
    });

    test('the trail, the ring, the guide, the bubble and the box follow', () {
      expect(at(300).map.segments[3], 0);
      expect(at(700).map.segments[3], 1);
      expect(at(300).header.ringArcIn, 0);
      expect(at(900).header.ringArcIn, 1);
      expect(at(560).header.ringGuideIn, 0);
      expect(at(940).header.ringGuideIn, 1);
      expect(at(880).map.bubbleIn, 0);
      expect(at(1030).map.bubbleIn, .5, reason: 'linear: the bubble pops');
      expect(at(1180).map.bubbleIn, 1);
      expect(at(980).map.boxIn, 0);
      expect(at(1240).map.boxIn, 1);
    });

    test('it lasts until the box is in', () {
      expect(opening.length, _ms(1240));
      expect(opening.busyUntil, Duration.zero);
      expect(const OpeningMotion(islands: 16, segment: 0).length, _ms(1300));
    });
  });

  group('M5, a lesson done (frame 09)', () {
    final motion = LessonDoneMotion(moment: _lessonDone(), collapsed: false);
    MotionFrame at(int ms) => motion.frameAt(_ms(ms));

    test('it starts on the day before', () {
      final f = at(0);
      expect(f.map.doneN, 3);
      expect(f.map.cur, 3);
      expect(f.map.segments, {4: 0.0});
      expect(f.map.bubbleContent, 1);
      expect(f.guide, isNull);
      expect(f.header.ringFraction, closeTo(.7, 1e-9));
      expect(f.header.minutes, 14);
      expect(f.header.ringSuccess, isFalse);
      expect(f.header.streak, (from: 7, to: 7));
    });

    test('beat 1: the ring fills toward the goal', () {
      expect(at(300).header.ringFraction, inExclusiveRange(.9, 1));
      expect(at(600).header.ringFraction, 1);
      expect(at(600).header.ringSuccess, isFalse);
    });

    test('beat 2: the guide lands, the stone fills and sparks', () {
      expect(at(500).guide, const GuideFlying());
      final f = at(700);
      expect(f.map.doneN, 4);
      expect(f.map.cur, 3);
      expect(f.guide, const GuideBesideStone(3));
      expect(f.map.stonePop?.index, 3);
      expect(f.map.bubbleContent, inExclusiveRange(0, 1));
      expect(f.map.segments[4], 0, reason: 'D24: no flash before 820');
      expect(f.map.saturation, inExclusiveRange(.5, 2 / 3));
      expect(f.expression, MascotExpression.happy);
    });

    test('beat 3: the guide hops while the trail draws on', () {
      final f = at(1030);
      expect(f.map.bubbleContent, 0);
      expect(f.map.segments[4], inExclusiveRange(.4, .7));
      final hop = f.guide! as GuideHop;
      expect((hop.from, hop.to), (3, 4));
      expect(hop.t, inExclusiveRange(.5, 1));
      expect(f.map.saturation, inExclusiveRange(.55, 2 / 3));
    });

    test('beat 4: the next stone is the current one, the tail follows', () {
      final f = at(1400);
      expect(f.map.cur, isNull);
      expect(f.map.doneN, isNull);
      expect(f.map.tail?.a, 3);
      expect(f.map.tail?.b, 4);
      expect(f.map.tail!.t, inExclusiveRange(0, 1));
      expect(f.map.bubbleContent, inExclusiveRange(0, 1));
      expect(f.map.rowFrom, isNull);
      expect(f.guide, const GuideBesideStone(4));
      expect(at(1700).map.tail, isNull);
    });

    test('beat 5: the guide is home and the goal plays', () {
      expect(at(1800).guide, const GuideFlying());
      final f = at(2230);
      expect(f.guide, isNull);
      expect(f.header.ringSuccess, isTrue);
      expect(f.header.streak, (from: 7, to: 8));
      expect(f.header.streakRoll, greaterThan(0));
      expect(f.header.flameFlip, inExclusiveRange(0, 1.2));
      expect(f.header.guideJump, inExclusiveRange(0, 1));
      expect(f.header.ringSparks, closeTo(200 / 720, 1e-9));
      expect(at(2000).header.ringSparks, isNull);
    });

    test('its cues and length', () {
      expect(motion.cues.map((c) => (c.at, c.cue)), [
        (_ms(320), MotionCue.flyToStone),
        (_ms(680), MotionCue.fillStone),
        (_ms(1650), MotionCue.flyHome),
        (_ms(2030), MotionCue.goal),
      ]);
      expect(motion.length, _ms(2750));
      expect(motion.busyUntil, _ms(2030));
      final last = motion.frameAt(motion.length);
      expect(last.header.streakRoll, 1);
      expect(last.header.guideJump, 1);
      expect(last.header.ringSparks, 1);
    });

    test('short of the goal it ends at 2030 with no goal step', () {
      final short = LessonDoneMotion(
        moment: _lessonDone(from: 2, to: 6, streakTo: 7),
        collapsed: false,
      );
      expect(short.length, _ms(2030));
      expect(short.cues.map((c) => c.cue), isNot(contains(MotionCue.goal)));
      expect(short.frameAt(_ms(2030)).header.ringSuccess, isNull);
      expect(short.frameAt(_ms(2030)).header.streak, isNull);
    });

    test('collapsed, the guide stays on the map (D23)', () {
      final folded = LessonDoneMotion(moment: _lessonDone(), collapsed: true);
      expect(folded.frameAt(Duration.zero).guide, const GuideBesideStone(3));
      expect(folded.frameAt(_ms(1000)).guide, isA<GuideHop>());
      expect(folded.frameAt(_ms(1500)).guide, const GuideBesideStone(4));
      expect(folded.frameAt(_ms(2100)).guide, const GuideBesideStone(4));
      expect(folded.cues.map((c) => c.cue), [
        MotionCue.fillStone,
        MotionCue.goal,
      ]);
    });
  });

  group('09ب, the next stone on a new row', () {
    final motion = LessonDoneMotion(
      moment: _lessonDone(
        home: _home(HomeMockScenario.newRow),
        lesson: 5,
        next: 6,
        from: 2,
        to: 6,
        streakTo: 7,
      ),
      collapsed: false,
      rows: (from: 0, to: 1),
    );
    MotionFrame at(int ms) => motion.frameAt(_ms(ms));

    test('beat 1: stone 6 fills, the bubble still over its row', () {
      final f = at(700);
      expect(f.map.doneN, 6);
      expect(f.map.stonePop?.index, 5);
      expect(f.guide, const GuideBesideStone(5));
      expect(f.map.rowFrom, isNull);
    });

    test('beat 2: the rows move, the content waits', () {
      // rt .4 of easeInOutQuad is k ≈ .447 of the 300.
      final f = at(1434);
      expect(f.map.rowFrom, 0);
      expect(f.map.rowT, closeTo(.4, .01));
      expect(f.map.bubbleContent, 0);
    });

    test('beat 3: stone 7 current, the content fades in after the rows', () {
      expect(at(1460).map.bubbleContent, 0);
      final f = at(1600);
      expect(f.map.rowFrom, isNull);
      expect(f.map.rowT, 1);
      expect(f.map.bubbleContent, inExclusiveRange(0, 1));
      expect(at(1680).map.bubbleContent, 1);
    });
  });

  group('M6, a unit done (frame 10)', () {
    final moment = _unitDone();
    final motion = UnitDoneMotion(moment: moment, collapsed: false);
    // M6's own time starts after M5's lead-in (D25).
    MotionFrame at(int ms) => motion.frameAt(_ms(680 + ms));

    test('the lead-in is M5\'s: the ring, the flight, the last stone', () {
      final f = motion.frameAt(_ms(300));
      expect(f.map.snapshot, moment.before);
      expect(f.map.doneN, 5);
      expect(f.map.bubbleVisible, isTrue);
      expect(f.header.ringFraction, inExclusiveRange(.7, 1));
      expect(motion.frameAt(_ms(400)).guide, const GuideFlying());
    });

    test(
      'beat 1: full colour, the flag rising, the guide by the lighthouse',
      () {
        final f = at(300);
        final shown = f.map.snapshot!;
        expect(shown.currentUnit!.lessons.every((l) => l.done), isTrue);
        expect(shown.unitsDone, moment.before.unitsDone + 1);
        expect(f.map.doneN, 6);
        expect(f.map.bubbleVisible, isFalse);
        expect(f.map.flagUp, inExclusiveRange(.4, 1.3));
        expect(f.map.saturation, inExclusiveRange(5 / 6, 1));
        expect(f.guide, const GuideBesideStone(5));
        expect(at(600).map.saturation, 1);
      },
    );

    test('beat 2: the flag up, the bridge half drawn', () {
      final f = at(900);
      expect(f.map.flagUp, 1);
      expect(f.map.bridges[2], closeTo(.5, 1e-9));
      expect(f.map.clouds, 0);
      expect(f.map.cloudsIsland, 3);
    });

    test('beat 3: the bridge done, the fog clearing, the guide crossing', () {
      final f = at(1500);
      expect(f.map.bridges[2], 1);
      expect(f.map.clouds, inExclusiveRange(.6, 1));
      final crossing = f.guide! as GuideOnBridge;
      expect(crossing.bridge, 2);
      expect(crossing.t, inExclusiveRange(.5, 1));
    });

    test('beat 4: unit 4 current, its island grows, the bubble pops', () {
      final f = at(2100);
      expect(f.map.snapshot, isNull);
      expect(f.map.doneN, isNull);
      expect(f.map.islandGrow!.scale, inExclusiveRange(.82, 1));
      expect(f.map.bubbleIn, 0);
      expect(f.guide, isNull);
      expect(at(2300).map.bubbleIn, closeTo(.5, 1e-9));
      expect(at(2500).map.bubbleIn, 1);
      expect(at(2500).map.bubbleScale, 1);
    });

    test('its cues, length and skip point', () {
      expect(motion.cues.map((c) => (c.at, c.cue)), [
        (_ms(320), MotionCue.flyToStone),
        (_ms(680), MotionCue.unitDone),
        (_ms(1280), MotionCue.camera),
        (_ms(2630), MotionCue.finish),
        (_ms(2630), MotionCue.goal),
      ]);
      expect(motion.busyUntil, _ms(2630));
      expect(motion.length, _ms(2630 + 720));
    });

    test('M7 follows the level\'s last unit', () {
      final level = UnitDoneMotion(
        moment: _unitDone(
          before: _home(HomeMockScenario.lastUnit),
          unit: 7,
          nextUnit: null,
          levelDone: true,
        ),
        collapsed: true,
      );
      final finish = 2630;
      final f = level.frameAt(_ms(finish + 300));
      expect(f.map.horizonOpen, inExclusiveRange(0, 1));
      expect(f.map.levelCardIn, 0);
      final g = level.frameAt(_ms(finish + 750));
      expect(g.map.horizonOpen, 1);
      expect(g.map.levelCardIn, inExclusiveRange(0, 1));
      expect(level.frameAt(_ms(2000)).map.bridges, isEmpty);
      expect(level.frameAt(_ms(2000)).guide, const GuideBesideStone(5));
      expect(
        level.cues.map((c) => c.cue),
        containsAll([MotionCue.camera, MotionCue.levelDone]),
      );
      expect(level.length, _ms(finish + 900));
    });

    test('M14: a kid\'s guide stands by the banner saying the name', () {
      final kids = UnitDoneMotion(
        moment: _unitDone(before: mockHome(kids: true, now: _morning)),
        collapsed: true,
      );
      expect(kids.frameAt(_ms(2730)).guide, const GuideOnBanner());
      expect(kids.frameAt(_ms(2630 + 2600)).guide, isNull);
      expect(kids.cues.map((c) => c.cue), contains(MotionCue.kidSay));
      expect(kids.length, _ms(2630 + 2600));
    });

    test('allDone keeps every other unit and the lessons\' kept flags', () {
      final before = moment.before;
      final done = UnitDoneMotion.allDone(before);
      expect(done.units.length, before.units.length);
      final unit = done.currentUnit!;
      expect(unit.status, UnitLessonStatus.current);
      expect(
        unit.lessons.map((l) => l.kept),
        before.currentUnit!.lessons.map((l) => l.kept),
      );
      expect(done.units[0], before.units[0]);
    });
  });

  group('the flights and the sparks', () {
    test('a flight goes through a V 36 above its higher end', () {
      const a = Offset(68, 104);
      const b = Offset(250, 300);
      final mid = FlightPath.at(
        from: a,
        fromSize: 64,
        to: b,
        toSize: 44,
        t: .5,
      );
      expect(mid.centre, const Offset(159, 68));
      expect(mid.size, 54);
      expect(
        FlightPath.at(from: a, fromSize: 64, to: b, toSize: 44, t: 0).centre,
        a,
      );
      expect(
        FlightPath.at(from: a, fromSize: 64, to: b, toSize: 44, t: 1).size,
        44,
      );
    });

    test('sparks start up, go out 22 → 36 → 52 and fade', () {
      const c = Offset(100, 100);
      final first = FlightPath.spark(centre: c, j: 0, count: 6, ms: 0);
      expect(first.opacity, 0);
      expect(first.centre.dx, closeTo(100, 1e-9));
      expect(first.centre.dy, closeTo(78, 1e-9));
      final late = FlightPath.spark(centre: c, j: 5, count: 6, ms: 50);
      expect(late.opacity, 0, reason: 'the sixth waits 100');
      final out = FlightPath.spark(centre: c, j: 0, count: 6, ms: 619);
      expect(out.opacity, lessThan(.05));
      expect(FlightPath.burstLength(8), _ms(760));
    });

    test('the ring\'s sparks scale with the ring', () {
      const c = Offset(68, 104);
      final small = FlightPath.spark(
        centre: c,
        j: 0,
        count: 6,
        ms: 0,
        r0: 44 * .5,
        r1: 55 * .5,
        r2: 66 * .5,
      );
      expect(small.centre.dy, closeTo(104 - 22, 1e-9));
    });
  });

  group('the reveal (M4)', () {
    const bubble = Rect.fromLTWH(20, 300, 320, 180);
    const screen = Size(360, 800);

    test('the bubble grows to the screen under a blue cover', () {
      final start = ContainerReveal.frame(
        Duration.zero,
        from: bubble,
        full: screen,
      );
      expect(start.rect, bubble);
      expect(start.radius, ContainerReveal.radius);
      expect(start.cover, 1);
      expect(start.opacity, 1);
      final grown = ContainerReveal.frame(_ms(350), from: bubble, full: screen);
      expect(grown.rect, Offset.zero & screen);
      expect(grown.radius, 0);
      expect(
        ContainerReveal.frame(_ms(189), from: bubble, full: screen).cover,
        1,
      );
      expect(
        ContainerReveal.frame(_ms(350), from: bubble, full: screen).cover,
        inExclusiveRange(0, 1),
      );
      expect(
        ContainerReveal.frame(_ms(420), from: bubble, full: screen).cover,
        0,
      );
      expect(ContainerReveal.length, _ms(750));
      expect(
        ContainerReveal.frame(_ms(750), from: bubble, full: screen).opacity,
        0,
      );
    });
  });

  group('the budget (M2)', () {
    test('the main state: the pulse, the guide, the box; the waves wait', () {
      expect(
        LoopBudget.pick(
          visible: {
            HomeLoop.stonePulse: true,
            HomeLoop.guideBreath: true,
            HomeLoop.reviewBox: true,
            HomeLoop.waves: true,
            HomeLoop.flags: true,
          },
        ),
        {HomeLoop.stonePulse, HomeLoop.guideBreath, HomeLoop.reviewBox},
      );
    });

    test('at risk, the flame goes first and the box waits', () {
      expect(
        LoopBudget.pick(
          visible: {
            HomeLoop.flame: true,
            HomeLoop.stonePulse: true,
            HomeLoop.guideBreath: true,
            HomeLoop.reviewBox: true,
          },
        ),
        {HomeLoop.flame, HomeLoop.stonePulse, HomeLoop.guideBreath},
      );
    });

    test('off screen loops cost nothing; clouds and flags a third each', () {
      expect(
        LoopBudget.pick(
          visible: {
            HomeLoop.stonePulse: false,
            HomeLoop.guideBreath: true,
            HomeLoop.waves: true,
            HomeLoop.clouds: true,
            HomeLoop.flags: true,
          },
          counts: {HomeLoop.clouds: 3},
        ),
        {HomeLoop.guideBreath, HomeLoop.waves, HomeLoop.clouds},
      );
      expect(
        LoopBudget.pick(
          visible: {
            HomeLoop.waves: true,
            HomeLoop.clouds: true,
            HomeLoop.flags: true,
          },
          counts: {HomeLoop.clouds: 3, HomeLoop.flags: 2},
        ),
        {HomeLoop.waves, HomeLoop.clouds, HomeLoop.flags},
      );
    });
  });

  group('the choreographer', () {
    late FakeHomeRepository homes;
    late FakeSoundPlayer sounds;
    late List<String> taps;

    setUp(() {
      homes = FakeHomeRepository(_home());
      sounds = FakeSoundPlayer();
      taps = [];
    });

    void listenToHaptics(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            taps.add(call.arguments as String);
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
    }

    Future<(HomeChoreographer, HomeCubit)> make({bool reduce = false}) async {
      final cubit = HomeCubit(
        homes,
        FakeProfileRepository(mockProfile()),
        FakeLessonRepository(),
        FakeConnectivityService(),
        sounds,
        now: () => _morning,
      );
      addTearDown(cubit.close);
      await cubit.refresh();
      final stage = StageController()
        ..width = 360
        ..height = 748
        ..head = 114;
      final flights = FlightLayerController(vsync: const TestVSync());
      final subject = HomeChoreographer(
        vsync: const TestVSync(),
        reduceMotion: () => reduce,
        stage: stage,
        cubit: cubit,
        flights: flights,
      );
      addTearDown(() {
        subject.dispose();
        flights.dispose();
        stage.dispose();
      });
      return (subject, cubit);
    }

    final frame = MapFrame(360);
    IslandLayout layout() =>
        IslandLayout.compute(lessons: 6, current: 3, kids: false, frame: frame);
    MapLayout mapOf(IslandLayout island) => MapLayout.compute(
      units: [for (final u in _home().units) u.status],
      currentUnit: 2,
      ordered: true,
      current: island,
      anchor: const MapAnchor(box: null, rel: 0),
      reviewBox: false,
      frame: frame,
    );

    testWidgets('M5 holds its first frame, plays, then hands back', (
      tester,
    ) async {
      listenToHaptics(tester);
      final (subject, cubit) = await make();
      final island = layout();
      var done = false;
      final playing = subject
          .playMoment(_lessonDone(), layout: island, map: mapOf(island))
          .then((_) => done = true);

      expect(subject.busy, isTrue);
      expect(subject.map.doneN, 3);
      expect(subject.header.minutes, 14);
      await tester.pump();
      await tester.pump(_ms(140 + 700));
      expect(subject.map.doneN, 4);
      expect(taps, ['HapticFeedbackType.lightImpact']);
      await tester.pump(_ms(1400));
      expect(subject.header.ringSuccess, isTrue);
      expect(taps.last, 'HapticFeedbackType.mediumImpact');
      expect(sounds.played, [AppSound.goalReached]);
      expect(subject.busy, isFalse);
      await tester.pump(_ms(1000));
      await playing;
      expect(done, isTrue);
      expect(subject.map, MapOverrides.none);
      expect(subject.header, HeaderOverrides.none);
      expect(subject.forcedGuide, isNull);
      expect(cubit.state.moment, isNull);
    });

    testWidgets('reduce motion: the last frame at once, the haptics stay', (
      tester,
    ) async {
      listenToHaptics(tester);
      final (subject, _) = await make(reduce: true);
      final island = layout();
      final playing = subject.playMoment(
        _lessonDone(),
        layout: island,
        map: mapOf(island),
      );
      expect(subject.busy, isFalse);
      expect(subject.map.doneN, isNull);
      expect(subject.map.bubbleContent, 0);
      expect(subject.forcedGuide, isNull);
      expect(taps, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
      await tester.pump();
      await tester.pump(AppMotion.quick);
      await playing;
      expect(subject.map, MapOverrides.none);
    });

    testWidgets('reduce motion: the opening is only marked as played', (
      tester,
    ) async {
      final (subject, cubit) = await make(reduce: true);
      await subject.playOpening(_home());
      expect(cubit.state.openingDue, isFalse);
      expect(homes.openingDay, isNotNull);
      expect(subject.map, MapOverrides.none);
    });

    testWidgets('a tap skips M6 to the next unit, with its pattern', (
      tester,
    ) async {
      listenToHaptics(tester);
      final (subject, _) = await make();
      final island = layout();
      final playing = subject.playMoment(
        _unitDone(),
        layout: island,
        map: mapOf(island),
      );
      await tester.pump();
      await tester.pump(_ms(400));
      expect(subject.skippable, isTrue);
      expect(subject.map.snapshot, isNotNull);
      subject.skip();
      expect(subject.skippable, isFalse);
      expect(subject.busy, isFalse);
      expect(subject.map.snapshot, isNull);
      expect(sounds.played, [AppSound.achievement, AppSound.goalReached]);
      await tester.pump(_ms(50));
      expect(
        taps.where((t) => t == 'HapticFeedbackType.mediumImpact').length,
        greaterThanOrEqualTo(2),
      );
      await tester.pump(_ms(1000));
      await playing;
    });

    testWidgets('the small motions write their own overrides', (tester) async {
      listenToHaptics(tester);
      final (subject, _) = await make();
      final shaking = subject.lockedTap(4);
      expect(taps, ['HapticFeedbackType.lightImpact']);
      await tester.pump();
      await tester.pump(_ms(180));
      expect(subject.map.shakeIsland, 4);
      expect(subject.map.shakeT, inExclusiveRange(0, 1));
      await tester.pump(_ms(200));
      await shaking;
      expect(subject.map.shakeIsland, isNull);

      final pulsing = subject.pulseStone(2, hit: true);
      await tester.pump();
      await tester.pump(_ms(300));
      expect(subject.map.pulse?.index, 2);
      expect(subject.map.hit, 2);
      await tester.pump(_ms(500));
      await pulsing;
      expect(subject.map.pulse, isNull);
      expect(subject.map.hit, 2);
      await tester.pump(_ms(2400));
      expect(subject.map.hit, isNull);

      final closing = subject.cardClosed(
        cardGuide: const Rect.fromLTWH(270, 150, 56, 56),
        dh: 120,
      );
      expect(subject.header.contentShift, 120);
      expect(subject.forcedGuide, const GuideFlying());
      await tester.pump();
      await tester.pump(_ms(130));
      expect(subject.header.contentShift, inExclusiveRange(0, 120));
      var hopped = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(_ms(50));
        if (subject.header.guideHop > hopped) hopped = subject.header.guideHop;
      }
      expect(hopped, inExclusiveRange(0, 1));
      await closing;
      expect(subject.header.contentShift, 0);
      expect(subject.header.guideHop, 0);
    });

    testWidgets('a track switch fades the stage out and back in', (
      tester,
    ) async {
      final (subject, _) = await make();
      var loaded = false;
      final switching = subject.switchTrack(() async => loaded = true);
      await tester.pump();
      await tester.pump(_ms(150));
      expect(subject.map.mapOpacity, 0);
      expect(loaded, isTrue);
      await tester.pump(_ms(10));
      expect(subject.map.mapOpacity, 0, reason: 'at least 160 out');
      await tester.pump(_ms(16));
      await tester.pump(_ms(16));
      await tester.pump(_ms(150));
      expect(subject.map.mapOpacity, inExclusiveRange(0, 1));
      await tester.pump(_ms(200));
      await switching;
      expect(subject.map.mapOpacity, 1);
    });

    testWidgets('the pull ticks past 70, holds, spins and goes back', (
      tester,
    ) async {
      listenToHaptics(tester);
      final (subject, _) = await make();
      subject
        ..pullMoved(40)
        ..pullMoved(80);
      expect(taps, ['HapticFeedbackType.selectionClick']);
      final pulls = <double>[];
      final releasing = subject.pullReleased(90, onPull: pulls.add);
      expect(pulls, [AppMotion.homePullHoldAt]);
      expect(subject.pullSpinning, isTrue);
      await tester.pump();
      await tester.pump(_ms(700));
      expect(subject.pullSpinning, isFalse);
      await tester.pump(_ms(300));
      await tester.pump(_ms(16));
      await tester.pump(_ms(200));
      expect(pulls.last, inExclusiveRange(0, AppMotion.homePullHoldAt));
      await tester.pump(_ms(200));
      await releasing;
      expect(pulls.last, 0);
    });

    testWidgets('the budget runs the loops it picks, none under reduce '
        'motion', (tester) async {
      final (subject, _) = await make();
      subject.budget({HomeLoop.flame: true, HomeLoop.waves: true});
      expect(subject.loops.on, {HomeLoop.flame, HomeLoop.waves});
      await tester.pump();
      await tester.pump(_ms(350));
      expect(subject.flameWobble.value, isNot(0));
      subject.budget(const {});
      expect(subject.loops.on, isEmpty);
    });

    testWidgets('kids: the speaker says the name again, a tap starts over', (
      tester,
    ) async {
      final (subject, _) = await make();
      subject.sayUnit();
      expect(subject.kidSaying, isTrue);
      await tester.pump();
      await tester.pump(_ms(2000));
      subject.sayUnit();
      await tester.pump();
      await tester.pump(_ms(2100));
      expect(subject.kidSaying, isTrue);
      await tester.pump(_ms(200));
      expect(subject.kidSaying, isFalse);
    });

    testWidgets('M8: the guide hops ring to stone, not while M5 plays', (
      tester,
    ) async {
      final (subject, _) = await make();
      final island = layout();
      subject
        ..island = island
        ..mapLayout = mapOf(island);
      final hopping = subject.modeFlip(collapsed: true);
      expect(subject.forcedGuide, const GuideFlying());
      expect(
        subject.flights.guide?.expression,
        MascotExpression.encourage,
        reason: '7 of 10 minutes',
      );
      await tester.pump();
      await tester.pump(AppMotion.homeModeHop);
      await hopping;
      expect(subject.forcedGuide, isNull);

      final playing = subject.playMoment(
        _lessonDone(),
        layout: island,
        map: mapOf(island),
      );
      await subject.modeFlip(collapsed: false);
      expect(subject.flights.flying, isFalse);
      for (var i = 0; i < 32; i++) {
        await tester.pump(_ms(100));
      }
      await playing;
    });

    testWidgets('the back button takes the guide and gives it back', (
      tester,
    ) async {
      final (subject, _) = await make();
      final island = layout();
      subject
        ..island = island
        ..mapLayout = mapOf(island);
      final showing = subject.backButtonShown();
      expect(subject.forcedGuide, const GuideFlying());
      expect(
        subject.flights.guide?.centre,
        subject.stage.metrics.ringCenter,
        reason: 'D27: with the header open it leaves the ring',
      );
      await tester.pump();
      await tester.pump(AppMotion.homeBackFly);
      await showing;
      expect(subject.forcedGuide, const GuideInBackButton());

      final landing = subject.backButtonLanded();
      await tester.pump();
      await tester.pump(AppMotion.homeBackLandDelay);
      await tester.pump(_ms(16));
      expect(subject.forcedGuide, const GuideFlying());
      await tester.pump(AppMotion.homeBackLand);
      await landing;
      expect(subject.forcedGuide, isNull);

      unawaited(subject.backButtonShown());
      subject.backButtonHidden();
      await tester.pump();
      await tester.pump(AppMotion.homeBackFly);
      expect(subject.forcedGuide, isNull);
    });

    testWidgets('a freeze used: one glint, after a beat', (tester) async {
      final (subject, _) = await make();
      final glinting = subject.freezeGlint();
      await tester.pump();
      await tester.pump(_ms(700));
      expect(subject.header.freezeGlint, isNull);
      await tester.pump(_ms(400));
      expect(subject.header.freezeGlint, inExclusiveRange(0, 1));
      await tester.pump(_ms(400));
      await glinting;
      expect(subject.header.freezeGlint, isNull);
    });

    testWidgets('M4 grows the bubble over home, then opens the lesson', (
      tester,
    ) async {
      final (subject, _) = await make();
      await tester.pumpLocalized(
        Stack(
          children: [
            Positioned.fill(child: FlightLayer(controller: subject.flights)),
          ],
        ),
      );
      var pushed = 0;
      final opening = subject.openLesson(
        const Rect.fromLTWH(40, 300, 280, 180),
        () => pushed++,
      );
      await tester.pump();
      await tester.pump(_ms(300));
      expect(pushed, 0);
      await tester.pump(_ms(100));
      expect(pushed, 1);
      await tester.pump(_ms(500));
      await opening;
      expect(pushed, 1);
    });
  });
}
