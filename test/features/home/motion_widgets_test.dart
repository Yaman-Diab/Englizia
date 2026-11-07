import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/features/home/presentation/home/motion/container_reveal.dart';
import 'package:englizia/features/home/presentation/home/motion/flight_layer.dart';
import 'package:englizia/features/home/presentation/home/motion/pull_guide.dart';
import 'package:englizia/features/home/presentation/home/motion/skip_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

/// [child] filling a stage, as home lays its layers.
Widget _stage(Widget child, {bool reduceMotion = false}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: Stack(children: [Positioned.fill(child: child)]),
  ),
);

void main() {
  setUpAll(initLocalizationForTests);

  group('the hanging guide (M12)', () {
    testLayouts('it hangs centred under the top bar, stretched', (
      tester,
      layout,
    ) async {
      await tester.pumpLocalized(
        _stage(const PullGuide(pull: 100, spinning: false)),
        locale: layout.locale,
        themeMode: layout.themeMode,
        size: layout.size,
      );
      expect(tester.takeException(), isNull);
      final stretch = PullGuide.stretch(100);
      final guide = tester.getRect(find.byType(Mascot));
      expect(guide.center.dx, closeTo(layout.size.width / 2, .01));
      expect(guide.top, closeTo(56 + PullGuide.thread(100) * stretch.y, .01));
      expect(guide.height, closeTo(PullGuide.size * stretch.y, .01));
      expect(guide.width, closeTo(PullGuide.size * stretch.x, .01));
      expect(
        find.ancestor(
          of: find.byType(Mascot),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });

    testWidgets('it shows from 30, where the ring lets it go (D26)', (
      tester,
    ) async {
      await tester.pumpLocalized(
        _stage(const PullGuide(pull: 29, spinning: false)),
      );
      expect(find.byType(Mascot), findsNothing);
      await tester.pumpLocalized(
        _stage(const PullGuide(pull: 30, spinning: false)),
      );
      expect(find.byType(Mascot), findsOneWidget);
      expect(PullGuide.thread(30), 0);
    });

    for (final reduce in [false, true]) {
      testWidgets('let go past the threshold it turns once'
          '${reduce ? ', not under reduce motion' : ''}', (tester) async {
        Widget at({required bool spinning}) => _stage(
          PullGuide(pull: AppMotion.homePullHoldAt, spinning: spinning),
          reduceMotion: reduce,
        );
        await tester.pumpLocalized(at(spinning: false));
        await tester.pumpLocalized(at(spinning: true));
        await tester.pump(_ms(325));
        final turns = tester
            .widget<RotationTransition>(find.byType(RotationTransition))
            .turns
            .value;
        expect(turns, reduce ? 0 : inExclusiveRange(.2, .8));
        await tester.pump(AppMotion.homePullSpin);
      });
    }
  });

  group('the skip layer (M6)', () {
    testLayouts('it is one button that skips', (tester, layout) async {
      final semantics = tester.ensureSemantics();
      var skips = 0;
      await tester.pumpLocalized(
        _stage(SkipLayer(active: true, onSkip: () => skips++)),
        locale: layout.locale,
        themeMode: layout.themeMode,
        size: layout.size,
      );
      expect(tester.takeException(), isNull);
      final skip = find.bySemanticsLabel('home_skip'.tr());
      expect(skip, findsOneWidget);
      expect(
        'home_skip'.tr(),
        layout.locale == AppLocales.arabic
            ? isNot('Skip the celebration')
            : 'Skip the celebration',
      );
      await tester.tapAt(const Offset(30, 400));
      expect(skips, 1);
      expect(tester.getSize(find.byType(SkipLayer)), layout.size);
      semantics.dispose();
    });

    testWidgets('it takes no taps while nothing plays', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpLocalized(
        _stage(SkipLayer(active: false, onSkip: () => fail('skipped'))),
      );
      await tester.tapAt(const Offset(30, 400));
      expect(find.bySemanticsLabel('home_skip'.tr()), findsNothing);
      semantics.dispose();
    });
  });

  group('the flight layer', () {
    testLayouts('the guide flies through its V, mirrored in English', (
      tester,
      layout,
    ) async {
      final flights = FlightLayerController(vsync: tester);
      addTearDown(flights.dispose);
      await tester.pumpLocalized(
        _stage(FlightLayer(controller: flights)),
        locale: layout.locale,
        themeMode: layout.themeMode,
        size: layout.size,
      );
      const from = Offset(68, 104);
      const to = Offset(250, 400);
      final landed = flights.fly(
        from,
        64,
        to,
        44,
        AppMotion.homeFlyToStone,
        MascotExpression.happy,
      );
      unawaited(flights.burst(const Offset(180, 300), 6));
      await tester.pump();
      await tester.pump(_ms(180));
      expect(tester.takeException(), isNull);
      final pose = flights.guide!;
      final shown = tester.getRect(find.byType(Mascot));
      final x = layout.locale == AppLocales.arabic
          ? pose.centre.dx
          : layout.size.width - pose.centre.dx;
      expect(shown.center.dx, closeTo(x, .01));
      expect(shown.center.dy, closeTo(pose.centre.dy, .01));
      expect(shown.width, closeTo(pose.size, .01));
      expect(find.byType(IgnorePointer), findsWidgets);
      expect(flights.sparks.where((s) => s.opacity > 0), isNotEmpty);
      await tester.pump(_ms(800));
      await landed;
      expect(flights.flying, isFalse);
      expect(find.byType(Mascot), findsNothing);
      expect(flights.overlayContext, isNotNull);
    });

    testWidgets('a new flight takes the guide from the one before', (
      tester,
    ) async {
      final flights = FlightLayerController(vsync: tester);
      addTearDown(flights.dispose);
      var first = false;
      unawaited(
        flights
            .fly(
              Offset.zero,
              44,
              const Offset(100, 100),
              44,
              AppMotion.homeModeHop,
              MascotExpression.happy,
            )
            .then((_) => first = true),
      );
      final second = flights.fly(
        const Offset(100, 100),
        44,
        Offset.zero,
        64,
        AppMotion.homeModeHop,
        MascotExpression.encourage,
      );
      await tester.pump();
      expect(first, isTrue);
      expect(flights.guide?.expression, MascotExpression.encourage);
      await tester.pump(AppMotion.homeModeHop);
      await second;
      expect(flights.flying, isFalse);
    });
  });

  group('the reveal (M4)', () {
    testLayouts('the bubble grows, the lesson opens under it, it clears', (
      tester,
      layout,
    ) async {
      var pushed = false;
      late BuildContext home;
      await tester.pumpLocalized(
        Builder(
          builder: (context) {
            home = context;
            return const ColoredBox(color: Colors.transparent);
          },
        ),
        locale: layout.locale,
        themeMode: layout.themeMode,
        size: layout.size,
      );
      final revealing = ContainerReveal.run(
        home,
        from: const Rect.fromLTWH(20, 300, 280, 180),
        push: () {
          pushed = true;
          Navigator.of(
            home,
          ).push(MaterialPageRoute<void>(builder: (_) => const Placeholder()));
        },
      );
      await tester.pump();
      await tester.pump(_ms(200));
      expect(pushed, isFalse);
      expect(_revealShown(), isTrue);
      await tester.pump(_ms(200));
      expect(pushed, isTrue);
      await tester.pump(_ms(16));
      expect(_revealShown(), isTrue, reason: 'it stays above the new page');
      await tester.pump(_ms(400));
      await revealing;
      await tester.pump(_ms(300));
      expect(_revealShown(), isFalse);
      expect(find.byType(Placeholder), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it takes the taps until the lesson is pushed', (tester) async {
      var taps = 0;
      var pushed = false;
      late BuildContext home;
      await tester.pumpLocalized(
        Builder(
          builder: (context) {
            home = context;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            );
          },
        ),
      );
      final revealing = ContainerReveal.run(
        home,
        from: _bubble,
        push: () => pushed = true,
      );
      await tester.pump();
      await tester.pump(_ms(100));
      await tester.tapAt(_bubble.center);
      expect(taps, 0, reason: 'a second «تابع» doesn\'t reach home');
      await tester.pump(_ms(300));
      expect(pushed, isTrue);
      await tester.tapAt(_bubble.center);
      expect(taps, 1);
      await tester.pump(_ms(500));
      await revealing;
    });

    testWidgets('home gone before the push: nothing opens, it clears', (
      tester,
    ) async {
      var pushed = false;
      late BuildContext home;
      final shown = ValueNotifier(true);
      addTearDown(shown.dispose);
      await tester.pumpLocalized(
        ValueListenableBuilder(
          valueListenable: shown,
          builder: (context, on, _) => on
              ? Builder(
                  builder: (context) {
                    home = context;
                    return const SizedBox.expand();
                  },
                )
              : const SizedBox.shrink(),
        ),
      );
      final revealing = ContainerReveal.run(
        home,
        from: _bubble,
        push: () => pushed = true,
      );
      await tester.pump();
      await tester.pump(_ms(100));
      shown.value = false;
      await tester.pump();
      await tester.pump(_ms(300));
      await tester.pump(_ms(500));
      await revealing;
      await tester.pump();
      expect(pushed, isFalse);
      expect(_revealShown(), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a push that fails still clears it', (tester) async {
      late BuildContext home;
      await tester.pumpLocalized(
        Builder(
          builder: (context) {
            home = context;
            return const SizedBox.expand();
          },
        ),
      );
      final revealing = ContainerReveal.run(
        home,
        from: _bubble,
        push: () => throw StateError('no route'),
      ).then<Object?>((_) => null, onError: (Object error) => error);
      await tester.pump();
      await tester.pump(_ms(400));
      expect(await revealing, isA<StateError>());
      await tester.pump();
      expect(_revealShown(), isFalse);
    });

    testWidgets('under reduce motion it only opens the lesson', (tester) async {
      var pushed = false;
      late BuildContext home;
      await tester.pumpLocalized(
        _stage(
          Builder(
            builder: (context) {
              home = context;
              return const SizedBox.expand();
            },
          ),
          reduceMotion: true,
        ),
      );
      await ContainerReveal.run(
        home,
        from: Rect.zero,
        push: () => pushed = true,
      );
      expect(pushed, isTrue);
      expect(_revealShown(), isFalse);
    });
  });
}

const _bubble = Rect.fromLTWH(20, 300, 280, 180);

bool _revealShown() => find
    .byWidgetPredicate((w) => w is CustomPaint && w.painter is RevealPainter)
    .evaluate()
    .isNotEmpty;
