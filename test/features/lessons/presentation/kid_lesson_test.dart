import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/audio/app_sound.dart';
import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/domain/entities/kid_lesson.dart';
import 'package:englizia/features/lessons/presentation/kids/cubit/kid_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/kids/pages/kid_lesson_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

/// Every recorded line in these tests lasts this long.
const _clip = Duration(milliseconds: 300);

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeClipPlayer player;
  late FakeSoundPlayer sounds;
  late FakeVideoEngine video;

  setUp(() {
    final lesson = kidLesson();
    lessons = FakeLessonRepository(exercises: lesson.exercises)
      ..kids = lesson.kids;
    player = FakeClipPlayer(length: _clip);
    sounds = FakeSoundPlayer();
    video = FakeVideoEngine();
  });

  KidLessonCubit cubit() =>
      KidLessonCubit(lessons, player, sounds, video, lessonId: 'les_kid');

  /// Lets the voice say what it has to.
  Future<void> heard() => Future<void>.delayed(_clip * 3);

  group('the lesson', () {
    test('its screens, words and the guide\'s voice', () {
      final kids = kidLesson().kids!;

      expect(kids.steps.map((s) => s.runtimeType), [
        KidWordStep,
        KidLetterStep,
        KidQuestionStep,
        KidQuestionStep,
        KidQuestionStep,
      ]);
      expect(kids.words, hasLength(6));
      final letter = kids.steps[1] as KidLetterStep;
      expect(letter.letter, 'A');
      expect(letter.words.map((w) => w.word), ['apple', 'ant']);
      expect(letter.videoLength, const Duration(milliseconds: 4600));
      expect(kids.voice.praise, isNotNull);
    });

    test('a lesson with no kids\' screens can\'t be shown here', () async {
      lessons.kids = null;
      final subject = cubit();
      addTearDown(subject.close);

      await subject.start();

      expect(subject.state.stage, KidStage.failed);
    });
  });

  group('the cubit', () {
    Future<KidLessonCubit> at(int step) async {
      final subject = cubit();
      addTearDown(subject.close);
      await subject.start();
      for (var i = 0; i < step; i++) {
        if (subject.state.current is KidQuestionStep) break;
        subject.next();
        await Future<void>.delayed(KidLessonCubit.nextAfterPress * 2);
      }
      return subject;
    }

    test('each screen says its instruction, then the word', () async {
      final subject = cubit();
      addTearDown(subject.close);
      await subject.start();

      expect(subject.state.speaking, isTrue);
      expect(subject.state.mood, KidMood.talking);
      await heard();

      final word = (subject.state.current! as KidWordStep).word;
      expect(player.loaded, [
        subject.state.current!.instructionAudioUrl,
        word.audioUrl,
      ]);
      expect(subject.state.mood, KidMood.welcome);
    });

    test('«التالي» moves the star on and goes to the next screen', () async {
      final subject = await at(1);

      expect(subject.state.step, 1);
      expect(subject.state.progress, 1);
      expect(sounds.played, contains(AppSound.achievement));
    });

    test(
      'a wrong letter is tried again; after two, the right one shows',
      () async {
        final subject = await at(2);
        expect(subject.state.question, isA<ListenChooseExercise>());

        subject.pick('M');
        expect(subject.state.wrong, {'M'});
        expect(subject.state.flash, 'M');
        expect(subject.state.mood, KidMood.encourage);
        expect(subject.state.hint, isFalse);
        await Future<void>.delayed(KidLessonCubit.flashHold * 1.5);
        expect(subject.state.flash, isNull);

        subject
          ..pick('M')
          ..pick('S');
        expect(subject.state.hint, isTrue);
        expect(lessons.attempts.single.draft, const ChoiceDraft('M'));
      },
    );

    test('the right one: a star, «أحسنت!», and the next screen', () async {
      final subject = await at(2);

      subject.pick('A');
      expect(subject.state.right, 'A');
      expect(subject.state.won, 1);
      expect(subject.state.wonFrom, 'A');
      expect(subject.state.mood, KidMood.happy);
      expect(player.loaded.last, lessons.kids!.voice.praise);

      subject.landed();
      expect(subject.state.progress, 3);
      await Future<void>.delayed(KidLessonCubit.nextAfterWin * 1.2);
      expect(subject.state.step, 3);
      expect(subject.state.question, isA<ImageChoiceExercise>());
    });

    test('matching: a word alone is heard; a picture then its word', () async {
      final subject = await at(2);
      subject.pick('A');
      await Future<void>.delayed(KidLessonCubit.nextAfterWin * 1.2);
      subject.pick('cat');
      await Future<void>.delayed(KidLessonCubit.nextAfterWin * 1.2);
      expect(subject.state.question, isA<MatchingExercise>());

      subject.pickWord('cat');
      expect(subject.state.matched, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(player.loaded.last, contains('cat'));

      subject
        ..pickPicture('apple')
        ..pickWord('cat');
      expect(subject.state.wordFlash, 'cat');
      subject.pickWord('apple');
      expect(subject.state.matched, {'apple'});

      for (final pair in ['cat', 'ant']) {
        subject
          ..pickPicture(pair)
          ..pickWord(pair);
      }
      expect(subject.state.won, 3);
      final draft = lessons.attempts.last.draft as PairsDraft;
      expect(draft.mistakes, {'apple'});
    });

    test('the end: completed, and five stars fill one by one', () async {
      final subject = await at(2);
      subject.pick('A');
      await Future<void>.delayed(KidLessonCubit.nextAfterWin * 1.2);
      subject.pick('cat');
      await Future<void>.delayed(KidLessonCubit.nextAfterWin * 1.2);
      for (final pair in ['apple', 'cat', 'ant']) {
        subject
          ..pickPicture(pair)
          ..pickWord(pair);
      }
      await Future<void>.delayed(KidLessonCubit.nextAfterWin * 1.2);

      expect(subject.state.stage, KidStage.done);
      final summary = lessons.completions.single;
      expect(summary.counted, 3);
      expect(summary.rightFirstTime, 3);
      expect(subject.state.stars, 0);
      await Future<void>.delayed(
        KidLessonCubit.firstStar + KidLessonCubit.starGap * 5,
      );
      expect(subject.state.stars, KidLessonCubit.starCount);

      subject.again();
      expect(subject.state.stage, KidStage.playing);
      expect(subject.state.step, 0);
      expect(subject.state.progress, 0);
    });

    test('the letter\'s video plays to its end, by its own length', () async {
      final subject = await at(1);

      await subject.playVideo();
      expect(subject.state.video, KidVideoStatus.playing);
      expect(video.opened.single.url, contains('letter_a'));

      video.report(const VideoSnapshot(position: Duration(milliseconds: 2300)));
      await Future<void>.delayed(Duration.zero);
      expect(subject.state.videoProgress, closeTo(.5, .01));

      video.report(const VideoSnapshot(position: Duration(seconds: 5)));
      await Future<void>.delayed(Duration.zero);
      expect(subject.state.video, KidVideoStatus.done);
    });
  });

  group('the page', () {
    var exits = 0;

    Future<KidLessonCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      exits = 0;
      final subject = cubit();
      addTearDown(subject.close);
      final mic = MicCubit(FakeSpeechListener(), FakeMicPermission());
      addTearDown(mic.close);
      await tester.pumpLocalized(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: subject),
            BlocProvider.value(value: mic),
          ],
          child: KidLessonPage(onExit: () => exits++, onNext: () {}),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await settle(tester);
      return subject;
    }

    testWidgets('the word: its picture, the word and the next button', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('apple'), findsOneWidget);
      expect(find.bySemanticsLabel('kid_next'.tr()), findsOneWidget);
      expect(find.byType(KidTopBar), findsOneWidget);
    });

    testWidgets('a right letter flies a star to the bar', (tester) async {
      final subject = await pump(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.bySemanticsLabel('kid_next'.tr()));
        await settle(tester);
      }

      await tester.tap(find.bySemanticsLabel('A').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(KidStar), findsWidgets);
      await settle(tester);
      expect(subject.state.progress, 3);
    });

    testWidgets('the way out asks with two pictures; outside is staying', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.bySemanticsLabel('kid_exit'.tr()));
      await settle(tester);
      expect(find.bySemanticsLabel('kid_stay'.tr()), findsOneWidget);

      await tester.tapAt(const Offset(20, 20));
      await settle(tester);
      expect(find.bySemanticsLabel('kid_stay'.tr()), findsNothing);
      expect(exits, 0);

      await tester.tap(find.bySemanticsLabel('kid_exit'.tr()));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('kid_leave'.tr()));
      await settle(tester);
      expect(exits, 1);
    });

    testLayouts('every screen fits', (tester, layout) async {
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
      subject.next();
      await settle(tester);
      await subject.playVideo();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      subject.next();
      await settle(tester);
      subject
        ..pick('M')
        ..pick('S');
      await settle(tester);
      expect(tester.takeException(), isNull);
      subject.pick('A');
      await settle(tester);
      subject.pick('dog');
      await settle(tester);
      expect(tester.takeException(), isNull);
      subject.pick('cat');
      await settle(tester);
      subject.pickPicture('apple');
      await settle(tester);
      expect(tester.takeException(), isNull);
      for (final pair in ['apple', 'cat', 'ant']) {
        subject
          ..pickPicture(pair)
          ..pickWord(pair);
      }
      await settle(tester);
      await settle(tester);
      expect(subject.state.stage, KidStage.done);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
