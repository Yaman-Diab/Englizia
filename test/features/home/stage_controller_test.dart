import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/features/home/presentation/home/widgets/stage/stage_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The design's header (general, no notice) and its stage at 360 × 800.
StageController _stage({TickerProvider? vsync, bool reduce = false}) {
  final stage = StageController(vsync: vsync, reduceMotion: () => reduce)
    ..width = 360
    ..height = 680
    ..head = 114;
  addTearDown(stage.dispose);
  return stage;
}

/// A scrollable map [extent] tall under [stage], as the page puts it.
Future<ScrollController> _attach(
  WidgetTester tester,
  StageController stage, {
  double extent = 3000,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  stage.attach(controller);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.rtl,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          stage.onScroll(n.metrics.pixels);
          return false;
        },
        child: SingleChildScrollView(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(height: extent),
        ),
      ),
    ),
  );
  return controller;
}

/// Lets the header's pause after the last scroll pass.
Future<void> _idle(WidgetTester tester) async {
  await tester.pump(AppMotion.homeSnapDelay);
  await tester.pump(AppMotion.homeSnap);
  await tester.pump(AppMotion.homeSnap);
}

void main() {
  group('the floating header (header §5.1)', () {
    test('folds one to one, never past the scroll', () {
      final stage = _stage();
      stage.onScroll(40);
      expect(stage.collapse, 40);
      stage.onScroll(100);
      expect(stage.collapse, 100);
      stage.onScroll(300);
      expect(stage.collapse, 114, reason: 'no more than the header');
      expect(stage.metrics.dividerOn, isTrue);
      expect(stage.metrics.progress, 1);
    });

    test('the first scroll up brings it back over the map', () {
      final stage = _stage()..onScroll(600);
      expect(stage.collapse, 114);
      stage.onScroll(560);
      expect(stage.collapse, 74);
      expect(stage.scroll, 560);
      stage.onScroll(700);
      expect(stage.collapse, 114);
    });

    test('at the top it is open', () {
      final stage = _stage()..onScroll(80);
      stage.onScroll(0);
      expect(stage.collapse, 0);
      expect(stage.metrics.greetingOpacity, 1);
    });

    test('tells when it passes half folded, once each way', () {
      final flips = <bool>[];
      final stage = _stage()..collapsedChanged = flips.add;
      for (final st in [20.0, 50.0, 56.0, 58.0, 80.0, 200.0, 150.0]) {
        stage.onScroll(st);
      }
      expect(flips, [true], reason: '64 of 114 is still past half');
      stage.onScroll(140);
      expect(flips, [true, false]);
    });

    test('the ring follows: 96 open, 28 in the top bar once folded', () {
      final stage = _stage();
      expect(stage.metrics.ringScale, 1);
      expect(stage.metrics.ringTop, 56);
      stage.onScroll(200);
      expect(stage.metrics.ringScale, closeTo(28 / 96, 1e-9));
      expect(stage.metrics.ringTop, 14);
    });

    test('a pull is held as given', () {
      final stage = _stage()..setPull(40);
      expect(stage.pulling, isTrue);
      expect(stage.metrics.pull, 40);
      stage.setPull(0);
      expect(stage.pulling, isFalse);
    });
  });

  group('the snap (M8)', () {
    test('past half it shuts as far as the map scrolled; else it opens', () {
      final stage = _stage()..onScroll(70);
      stage.settle();
      expect(stage.collapse, 70, reason: 'no more than scrolled');

      final open = _stage()
        ..onScroll(300)
        ..onScroll(260);
      expect(open.collapse, 74);
      open.settle();
      expect(open.collapse, 114);

      final back = _stage()
        ..onScroll(300)
        ..onScroll(220);
      expect(back.collapse, 34);
      back.settle();
      expect(back.collapse, 0);
    });

    test('never while pulled or while a celebration holds it', () {
      final stage = _stage()
        ..onScroll(300)
        ..onScroll(220)
        ..setPull(10)
        ..settle();
      expect(stage.collapse, 34);

      var busy = true;
      final held = _stage()
        ..holdSnap = (() => busy)
        ..onScroll(300)
        ..onScroll(220)
        ..settle();
      expect(held.collapse, 34);
      busy = false;
      held.settle();
      expect(held.collapse, 0);
    });

    testWidgets('eases over the snap\'s time, a pause after the scroll', (
      tester,
    ) async {
      var idle = 0;
      final stage = _stage(vsync: const TestVSync())..onIdle = () => idle++;
      stage
        ..onScroll(300)
        ..onScroll(220);
      await tester.pump(AppMotion.homeSnapDelay ~/ 2);
      expect(idle, 0);
      expect(stage.collapse, 34);
      await tester.pump(AppMotion.homeSnapDelay);
      expect(idle, 1);
      await tester.pump(AppMotion.homeSnap ~/ 2);
      expect(stage.collapse, inExclusiveRange(0, 34));
      await tester.pump(AppMotion.homeSnap);
      expect(stage.collapse, 0);
      await _idle(tester);
    });

    testWidgets('jumps under reduce motion', (tester) async {
      final stage = _stage(vsync: const TestVSync(), reduce: true)
        ..onScroll(300)
        ..onScroll(220)
        ..settle();
      expect(stage.collapse, 0);
      await _idle(tester);
    });
  });

  group('home\'s own scrolls (header §5.6)', () {
    testWidgets('fold the header with the scroll, folded at the end', (
      tester,
    ) async {
      final stage = _stage(vsync: const TestVSync());
      final controller = await _attach(tester, stage);
      final done = stage.scrollTo(500, AppMotion.homeGoScroll);
      expect(stage.programmatic, isTrue);
      await tester.pump();
      await tester.pump(AppMotion.homeGoScroll ~/ 2);
      expect(controller.offset, inExclusiveRange(0, 500));
      final e = controller.offset / 500;
      expect(stage.collapse, closeTo(114 * e, .5));
      await tester.pump(AppMotion.homeGoScroll);
      await tester.pump(const Duration(milliseconds: 50));
      await done;
      expect(controller.offset, 500);
      expect(stage.collapse, 114);
      expect(stage.programmatic, isFalse);
      expect(stage.moved, isTrue);
      await _idle(tester);
    });

    testWidgets('a short scroll folds only as far as it goes', (tester) async {
      final stage = _stage(vsync: const TestVSync());
      final controller = await _attach(tester, stage);
      final done = stage.scrollTo(60, AppMotion.homeBackScroll);
      await tester.pump();
      await tester.pump(AppMotion.homeBackScroll);
      await tester.pump(const Duration(milliseconds: 50));
      await done;
      expect(controller.offset, 60);
      expect(stage.collapse, 60);
      await _idle(tester);
    });

    testWidgets('jump under reduce motion, kept within the map', (
      tester,
    ) async {
      final stage = _stage(vsync: const TestVSync(), reduce: true);
      final controller = await _attach(tester, stage, extent: 1000);
      await stage.scrollTo(5000, AppMotion.homeGoScroll);
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(stage.collapse, 114);
      await _idle(tester);
    });

    testWidgets('the camera lets the header follow the scroll', (tester) async {
      final stage = _stage(vsync: const TestVSync());
      final controller = await _attach(tester, stage);
      stage.jumpTo(400);
      expect(stage.collapse, 0);
      final done = stage.scrollTo(450, AppMotion.homeCamera, foldHeader: false);
      await tester.pump();
      await tester.pump(AppMotion.homeCamera);
      await tester.pump(const Duration(milliseconds: 50));
      await done;
      expect(controller.offset, 450);
      expect(stage.collapse, 50, reason: 'folded by what was scrolled');
      await _idle(tester);
    });

    testWidgets('the anchor: the map placed, the header open', (tester) async {
      final stage = _stage(vsync: const TestVSync());
      final controller = await _attach(tester, stage);
      stage.onScroll(0);
      stage.jumpTo(352);
      expect(controller.offset, 352);
      expect(stage.scroll, 352);
      expect(stage.collapse, 0);
      expect(stage.moved, isFalse);

      // A taller header than measured moves the map with it, no fold.
      stage.shiftScroll(20);
      expect(controller.offset, 372);
      expect(stage.collapse, 0);
      expect(stage.moved, isFalse);
      await _idle(tester);
    });
  });
}
