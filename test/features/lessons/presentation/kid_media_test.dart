import 'package:englizia/core/audio/mic_cubit.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/domain/entities/kid_lesson.dart';
import 'package:englizia/features/lessons/presentation/kids/cubit/kid_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/kids/pages/kid_lesson_page.dart';
import 'package:englizia/features/lessons/presentation/kids/widgets/kid_media_screens.dart';
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
  late FakeVideoEngine video;

  setUp(() {
    final lesson = kidMediaLesson();
    lessons = FakeLessonRepository(exercises: lesson.exercises)
      ..kids = lesson.kids;
    player = FakeClipPlayer(length: _clip);
    video = FakeVideoEngine();
  });

  KidLessonCubit cubit() => KidLessonCubit(
    lessons,
    player,
    FakeSoundPlayer(),
    video,
    lessonId: 'les_kid_media',
  );

  Future<void> wait(Duration time) => Future<void>.delayed(time);

  /// Past the instruction and what follows it.
  Future<void> heard() => wait(_clip * 3);

  group('the lesson', () {
    test('a story, a song, a dialogue and a word to say', () {
      final kids = kidMediaLesson().kids!;

      expect(kids.steps.map((s) => s.runtimeType), [
        KidStoryStep,
        KidSongStep,
        KidDialogueStep,
        KidSpeakStep,
      ]);
      final story = kids.steps.first as KidStoryStep;
      expect(story.pages, hasLength(3));
      expect(story.pages.first.sentence, 'The cat is on the bed.');
      expect(story.pages.first.markedFor('bed.')!.word, 'bed');
      expect(story.pages.first.markedFor('The'), isNull);
      final song = kids.steps[1] as KidSongStep;
      expect(song.lines, hasLength(4));
      expect(song.lines.first.first.text, 'Red');
      final dialogue = kids.steps[2] as KidDialogueStep;
      expect(dialogue.replies.map((r) => r.word.word), ['red', 'blue']);
      expect(dialogue.replies.first.echo.text, 'I like red.');
    });
  });

  group('the cubit', () {
    Future<KidLessonCubit> started() async {
      final subject = cubit();
      addTearDown(subject.close);
      await subject.start();
      return subject;
    }

    Future<void> skipTo(KidLessonCubit subject, Type step) async {
      while (subject.state.current.runtimeType != step) {
        subject.landed();
        // Moves on as a star does.
        subject.next();
        await wait(KidLessonCubit.nextAfterPress * 2);
        if (subject.state.current is KidStoryStep) {
          subject.turnPage(9);
          await wait(KidLessonCubit.nextAfterWin * 1.2);
        }
        if (subject.state.current is KidSongStep && step != KidSongStep) {
          subject.songDone();
          await wait(KidLessonCubit.nextAfterWin * 1.2);
        }
      }
    }

    test('the story is told, each word marked in its turn', () async {
      final subject = await started();
      await wait(_clip * 1.2);
      expect(subject.state.story.word, -1);

      await wait(const Duration(milliseconds: 250));
      expect(subject.state.story.word, 0);
      await wait(const Duration(milliseconds: 440));
      expect(subject.state.story.word, 1);
      await heard();
      await wait(const Duration(seconds: 3));
      expect(subject.state.story.word, -1);
    });

    test('a page turns; past the last, a star', () async {
      final subject = await started();

      subject.turnPage(1);
      expect(subject.state.story.page, 1);
      expect(subject.state.story.turnedFrom, 0);
      subject.turnPage(1);
      expect(subject.state.story.page, 1, reason: 'one turn at a time');
      await wait(KidMediaSteps.pageTurn * 1.5);
      expect(subject.state.story.turnedFrom, isNull);

      subject.turnPage(-1);
      await wait(KidMediaSteps.pageTurn * 1.5);
      expect(subject.state.story.page, 0);

      subject.turnPage(1);
      await wait(KidMediaSteps.pageTurn * 1.5);
      subject.turnPage(1);
      await wait(KidMediaSteps.pageTurn * 1.5);
      subject.turnPage(1);
      expect(subject.state.won, 1);
      expect(subject.state.wonFrom, KidLessonCubit.storyCard);
    });

    test('pages turn by themselves when asked', () async {
      final subject = await started();
      subject.toggleAutoTurn();
      expect(subject.state.story.auto, isTrue);

      await wait(const Duration(seconds: 4));

      expect(subject.state.story.page, greaterThan(0));
    });

    test('a marked word opens its card and says itself', () async {
      final subject = await started();
      final bed = (subject.state.current! as KidStoryStep).pages.first.marked
          .firstWhere((w) => w.word == 'bed');

      subject.openMarked(bed);
      expect(subject.state.story.opened, bed);
      await wait(Duration.zero);
      expect(player.loaded.last, bed.audioUrl);
      subject.closeMarked();
      expect(subject.state.story.opened, isNull);
    });

    test('the song follows its video, line and word, at 0.75', () async {
      final subject = await started();
      await skipTo(subject, KidSongStep);

      await subject.playSong();
      expect(video.opened.single.speed, KidSongStep.slow);
      video.report(const VideoSnapshot(position: Duration(milliseconds: 1800)));
      await wait(Duration.zero);
      expect(subject.state.song.line, 1);
      expect(subject.state.song.word, 0);

      await subject.toggleSongSpeed();
      expect(subject.state.song.speed, KidSongStep.normal);
      expect(video.speeds.last, KidSongStep.normal);

      video.report(const VideoSnapshot(position: Duration(seconds: 7)));
      await wait(Duration.zero);
      expect(subject.state.song.status, KidVideoStatus.done);

      subject.songDone();
      expect(subject.state.wonFrom, KidLessonCubit.songNext);
    });

    test(
      'the dialogue: a pick, its answer, then the sentence for a star',
      () async {
        final subject = await started();
        await skipTo(subject, KidDialogueStep);
        await heard();
        expect(subject.state.dialogue.phase, KidTalkPhase.choose);
        expect(subject.state.dialogue.line, "What's your favorite color?");

        subject.pickReply(0);
        expect(subject.state.dialogue.phase, KidTalkPhase.reply);
        await wait(KidMediaSteps.replyWait + _clip * 2);
        expect(subject.state.dialogue.line, 'Red! I like red too!');
        await heard();
        expect(subject.state.dialogue.phase, KidTalkPhase.echo);

        subject.listening();
        expect(subject.state.dialogue.phase, KidTalkPhase.recording);
        expect(subject.state.mood, KidMood.listening);
        subject.tried();
        expect(subject.state.dialogue.phase, KidTalkPhase.echoed);

        await wait(KidMediaSteps.replyWait + _clip * 2);
        expect(subject.state.dialogue.line, 'Yay! Bye bye!');
        expect(subject.state.wonFrom, KidLessonCubit.echoCard);
      },
    );

    test('«كرّر بعدي»: the model, then any try earns the star', () async {
      final subject = await started();
      await skipTo(subject, KidSpeakStep);
      await heard();
      expect(player.loaded.last, contains('banana'));

      subject.listening();
      expect(subject.state.speak, KidSpeakPhase.recording);
      subject.tried();

      expect(subject.state.speak, KidSpeakPhase.done);
      expect(subject.state.wonFrom, KidLessonCubit.micButton);
    });
  });

  group('the page', () {
    late FakeSpeechListener listener;

    Future<KidLessonCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      listener = FakeSpeechListener()..says = 'I like red';
      final subject = cubit();
      addTearDown(subject.close);
      final mic = MicCubit(listener, FakeMicPermission());
      addTearDown(mic.close);
      await tester.pumpLocalized(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: subject),
            BlocProvider.value(value: mic),
          ],
          child: KidLessonPage(onExit: () {}, onNext: () {}),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await settle(tester);
      return subject;
    }

    testWidgets('the story: its sentence, and a marked word\'s card', (
      tester,
    ) async {
      final subject = await pump(tester);

      expect(find.byType(KidStoryScreen), findsOneWidget);
      expect(find.text('cat'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('bed.'));
      await settle(tester);
      expect(subject.state.story.opened?.word, 'bed');
    });

    testWidgets('the dialogue: speaking ends with a star', (tester) async {
      final subject = await pump(tester);
      for (var step = 0; step < 2; step++) {
        subject
          ..landed()
          ..next();
        await settle(tester);
      }
      expect(find.byType(KidDialogueScreen), findsOneWidget);
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('red').first);
      await settle(tester);
      await settle(tester);
      expect(subject.state.dialogue.phase, KidTalkPhase.echo);

      await tester.tap(find.byType(KidMicButton));
      await tester.pump();
      listener.finish();
      await tester.pump();
      expect(subject.state.dialogue.phase, KidTalkPhase.echoed);
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      expect(find.byType(KidSpeakScreen), findsOneWidget);
    });

    testLayouts('every media screen fits', (tester, layout) async {
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      subject.openMarked(
        (subject.state.current! as KidStoryStep).pages.first.marked.first,
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      subject
        ..closeMarked()
        ..turnPage(1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await settle(tester);
      for (final screen in [KidSongScreen, KidDialogueScreen, KidSpeakScreen]) {
        subject
          ..landed()
          ..next();
        await settle(tester);
        expect(find.byType(screen), findsOneWidget);
        if (screen == KidSongScreen) {
          await subject.playSong();
          video.report(
            const VideoSnapshot(position: Duration(milliseconds: 1500)),
          );
          await settle(tester);
        }
        if (screen == KidDialogueScreen) {
          await settle(tester);
          subject.pickReply(1);
          await settle(tester);
          await settle(tester);
        }
        expect(tester.takeException(), isNull);
      }
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
