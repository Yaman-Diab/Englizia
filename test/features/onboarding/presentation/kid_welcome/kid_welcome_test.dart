import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/session/app_session_controller.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/onboarding/presentation/kid_welcome/cubit/kid_welcome_cubit.dart';
import 'package:englizia/features/onboarding/presentation/kid_welcome/pages/kid_welcome_page.dart';
import 'package:englizia/features/onboarding/presentation/kid_welcome/widgets/hello_word.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_accounts.dart';
import '../../../../helpers/fakes.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  late AppSessionController session;
  late FakeSoundPlayer sound;
  late FakeDeviceVolume volume;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app.has_launched': true});
    session = AppSessionController(
      tokens: FakeTokenStorage(),
      settings: SettingsStorageService(await SharedPreferences.getInstance()),
    );
    await session.bootstrap();
    sound = FakeSoundPlayer();
    volume = FakeDeviceVolume();
  });
  tearDown(() => volume.dispose());

  const helloCue = Duration(milliseconds: 20);
  const endCue = Duration(milliseconds: 40);

  KidWelcomeCubit cubit() {
    final cubit = KidWelcomeCubit(
      session,
      sound,
      volume,
      helloCue: helloCue,
      endCue: endCue,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('KidWelcomeCubit', () {
    test('starts the session, then waits for the parent', () async {
      final welcome = cubit();
      await welcome.start(memberTokens);
      expect(session.status, SessionStatus.member);
      expect(welcome.state.phase, KidWelcomePhase.handOver);
      expect(sound.played, isEmpty);
    });

    test('speaks the welcome, says hello, then ends', () async {
      final welcome = cubit();
      await welcome.start(memberTokens);
      final playing = welcome.play();
      await pumpEventQueue();
      expect(welcome.state.phase, KidWelcomePhase.speaking);
      expect(sound.played, [AppSound.guideWelcome]);

      await Future<void>.delayed(helloCue);
      expect(welcome.state.phase, KidWelcomePhase.hello);
      await playing;
      expect(welcome.state.phase, KidWelcomePhase.done);
    });

    test('a silent phone waits, and turning it up starts over', () async {
      volume.muted = true;
      final welcome = cubit();
      await welcome.start(memberTokens);
      await welcome.play();
      expect(welcome.state.phase, KidWelcomePhase.muted);
      expect(sound.played, isEmpty);

      volume.muted = false;
      await pumpEventQueue();
      expect(welcome.state.phase, KidWelcomePhase.speaking);
      expect(sound.played, [AppSound.guideWelcome]);
    });

    test('turning it down while speaking asks to turn it up', () async {
      final welcome = cubit();
      await welcome.start(memberTokens);
      final playing = welcome.play();
      await pumpEventQueue();
      volume.muted = true;
      await pumpEventQueue();
      expect(welcome.state.phase, KidWelcomePhase.muted);
      await playing;
      // The interrupted welcome does not carry on.
      expect(welcome.state.phase, KidWelcomePhase.muted);
    });

    test('back returns to the parent and stops the welcome', () async {
      final welcome = cubit();
      await welcome.start(memberTokens);
      final playing = welcome.play();
      await pumpEventQueue();
      welcome.handOver();
      await playing;
      expect(welcome.state.phase, KidWelcomePhase.handOver);
    });

    test(
      'replay starts over; a silent phone or the parent part does not',
      () async {
        final welcome = cubit();
        await welcome.replay();
        expect(sound.played, isEmpty);

        await welcome.play();
        await welcome.replay();
        expect(sound.played, [AppSound.guideWelcome, AppSound.guideWelcome]);

        welcome.sayHello();
        expect(sound.played.last, AppSound.hello);
      },
    );
  });

  group('KidWelcomePage', () {
    Future<KidWelcomeCubit> pumpPage(
      WidgetTester tester, {
      String childName = 'ليان',
      VoidCallback? onPlay,
      LayoutCase? layout,
    }) async {
      final welcome = cubit();
      await welcome.start(memberTokens);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: welcome,
          child: KidWelcomePage(childName: childName, onPlay: onPlay ?? () {}),
        ),
        locale: layout?.locale ?? const Locale('ar'),
        size: layout?.size ?? defaultViewport,
        themeMode: layout?.themeMode ?? ThemeMode.light,
      );
      return welcome;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(AppMotion.slow * 2);
    }

    Future<void> listenThrough(WidgetTester tester) async {
      await tester.tap(find.text('kid_welcome_start'.tr()));
      await tester.pump();
      await tester.pump(endCue);
      await settle(tester);
      await tester.pump(AppMotion.slow * 3);
    }

    Mascot guide(WidgetTester tester) =>
        tester.widget<Mascot>(find.byType(Mascot));

    testLayouts('lays out without overflow', (tester, layout) async {
      final welcome = await pumpPage(tester, layout: layout);
      expect(tester.takeException(), isNull);
      await listenThrough(tester);
      expect(tester.takeException(), isNull);
      volume.muted = true;
      await welcome.play();
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the parent hands the phone over and turns the sound up', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('كل شيء جاهز لـليان'), findsOneWidget);
      expect(find.text('kid_welcome_sound_up'.tr()), findsOneWidget);
      expect(guide(tester).expression, MascotExpression.handoff);
    });

    testWidgets('the guide greets the child, then "let\'s play" appears', (
      tester,
    ) async {
      var played = false;
      await pumpPage(tester, onPlay: () => played = true);
      await tester.tap(find.text('kid_welcome_start'.tr()));
      await tester.pump();

      expect(find.text('مرحبًا ليان!'), findsOneWidget);
      expect(guide(tester).waving, isTrue);
      final play = tester.widget<AppButton>(find.byType(AppButton));
      expect(play.onPressed, isNull);

      await tester.pump(endCue);
      await settle(tester);
      await tester.pump(AppMotion.slow * 3);
      expect(guide(tester).expression, MascotExpression.happy);
      await tester.tap(find.text('kid_welcome_play'.tr()));
      expect(played, isTrue);
    });

    testWidgets('tapping the word says it and lights it up', (tester) async {
      await pumpPage(tester);
      await listenThrough(tester);
      await tester.tap(find.byType(HelloWord));
      await tester.pump();
      expect(sound.played.last, AppSound.hello);
      expect(
        tester.widget<HelloWord>(find.byType(HelloWord)).highlighted,
        isTrue,
      );

      await tester.pump(AppMotion.highlightHold);
      expect(
        tester.widget<HelloWord>(find.byType(HelloWord)).highlighted,
        isFalse,
      );
    });

    testWidgets('a silent phone asks to turn it up, with no arrow', (
      tester,
    ) async {
      volume.muted = true;
      await pumpPage(tester);
      await tester.tap(find.text('kid_welcome_start'.tr()));
      await settle(tester);

      expect(find.text('kid_welcome_turn_up'.tr()), findsOneWidget);
      expect(find.text('kid_welcome_side_button'.tr()), findsOneWidget);
      expect(find.byType(HelloWord), findsNothing);
      expect(guide(tester).expression, MascotExpression.listen);

      volume.muted = false;
      await settle(tester);
      expect(find.text('مرحبًا ليان!'), findsOneWidget);
      await tester.pump(endCue);
      await settle(tester);
    });

    testWidgets('back from the child part returns to the parent part', (
      tester,
    ) async {
      final welcome = await pumpPage(tester);
      await listenThrough(tester);
      expect(welcome.state.phase, KidWelcomePhase.done);

      final popped = await tester.binding.handlePopRoute();
      await settle(tester);
      expect(popped, isTrue);
      expect(welcome.state.phase, KidWelcomePhase.handOver);
      expect(find.text('kid_welcome_start'.tr()), findsOneWidget);
    });

    testWidgets('without a name the texts still read well', (tester) async {
      await pumpPage(tester, childName: '');
      expect(find.text('kid_welcome_ready'.tr()), findsOneWidget);
      await tester.tap(find.text('kid_welcome_start'.tr()));
      await tester.pump();
      expect(find.text('kid_welcome_hello'.tr()), findsOneWidget);
      await tester.pump(endCue);
      await settle(tester);
    });

    testWidgets('buttons meet the tap target guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      await listenThrough(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
