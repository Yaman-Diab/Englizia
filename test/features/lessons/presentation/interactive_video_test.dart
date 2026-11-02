import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/reader_model.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_video_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/pages/interactive_video_page.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_card.dart';
import 'package:englizia/features/lessons/presentation/reader/widgets/reader_sentence.dart';
import 'package:englizia/features/lessons/presentation/video/lesson_player.dart';
import 'package:englizia/features/lessons/presentation/video/player_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);
const _sideways = Size(800, 360);

final _content = readerFromJson(
  asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(LessonFakeDataSource.videoAsset).readAsStringSync()),
    ),
  ),
)!;

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeVideoEngine engine;

  setUp(() {
    lessons = FakeLessonRepository(exercises: const [])..reader = _content;
    engine = FakeVideoEngine();
  });

  InteractiveVideoCubit cubit() {
    final subject = InteractiveVideoCubit(lessons, engine, lessonId: 'les');
    addTearDown(subject.close);
    return subject;
  }

  VideoSnapshot at(
    Duration position, {
    bool playing = true,
    bool buffering = false,
    bool ended = false,
  }) => VideoSnapshot(
    position: position,
    duration: _content.duration,
    playing: playing,
    buffering: buffering,
    ended: ended,
    ready: true,
  );

  Future<void> report(VideoSnapshot snapshot) async {
    engine.report(snapshot);
    await Future<void>.delayed(Duration.zero);
  }

  group('the video', () {
    test('nothing plays by itself, and the cover has no current one', () async {
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.ready);
      expect(subject.state.stage, VideoStage.cover);
      expect(engine.opened, isEmpty);
    });

    test('a lesson with no reader says so', () async {
      lessons.reader = null;
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.failure);
    });

    test(
      'playing opens the quality chosen, at the speed from the panel',
      () async {
        lessons
          ..quality = VideoQuality.low
          ..reader = ReaderContent(
            duration: _content.duration,
            sentences: _content.sentences,
            video: ReaderVideo(
              video: _content.video!.video,
              requiredPercent: 80,
              defaultSpeed: .75,
            ),
          );
        final subject = cubit();
        await subject.start();

        await subject.play();

        expect(subject.state.stage, VideoStage.playing);
        expect(
          engine.opened.single.url,
          _content.video!.video.urlFor(VideoQuality.low),
        );
        expect(engine.opened.single.speed, .75);
      },
    );

    test('a sentence pressed plays from just before it', () async {
      final subject = cubit();
      await subject.start();

      await subject.goTo(2);

      final start = _content.sentences[2].start;
      expect(subject.state.current, 2);
      expect(subject.state.playing, isTrue);
      expect(
        engine.opened.single.from,
        start - const Duration(milliseconds: 200),
      );
    });

    test('once open, a sentence pressed only seeks there', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      await subject.goTo(1);

      expect(engine.opened, hasLength(1));
      expect(engine.seeks.single, lessThan(_content.sentences[1].start));
      expect(engine.plays, 1);
    });

    test('the word follows the time, frame by frame', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      await report(at(_content.sentences[1].words[2].start));
      subject.tick(const Duration(milliseconds: 16));

      expect(subject.state.current, 1);
      expect(subject.state.word, 2);
    });

    test('a sentence stays through the silence after it', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      final first = _content.sentences[0];
      final second = _content.sentences[1];
      await report(at(first.words.last.start));

      await report(at(first.end + const Duration(milliseconds: 300)));
      expect(subject.state.current, 0);
      expect(subject.state.word, isNull);

      await report(at(second.start - const Duration(milliseconds: 100)));
      expect(subject.state.current, 1);
    });

    test('time stands still while it loads', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(at(const Duration(seconds: 2), buffering: true));
      final position = subject.state.position;

      subject.tick(const Duration(seconds: 1));

      expect(subject.state.position, position);
    });

    test(
      'a text\'s stopping at each sentence doesn\'t reach a video',
      () async {
        lessons.prefs = const ReaderPrefs(stopEachSentence: true);
        final subject = cubit();
        await subject.start();
        await subject.play();

        await report(at(_content.sentences[0].words.last.start));
        await report(at(_content.sentences[1].words.first.start));

        expect(subject.state.playing, isTrue);
        expect(subject.state.current, 1);
      },
    );

    test(
      'the bar never reaches the very end, and stops short of nothing',
      () async {
        final subject = cubit();
        await subject.start();
        await subject.play();

        await subject.skipBack();
        expect(engine.seeks.last, Duration.zero);

        await subject.seekTo(_content.duration + const Duration(seconds: 5));
        expect(subject.state.finished, isFalse);
        expect(engine.seeks.last, lessThan(_content.duration));
      },
    );

    test('the end says so and tells the server how much was watched', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      await report(at(_content.duration, ended: true));
      await Future<void>.delayed(Duration.zero);

      expect(subject.state.finished, isTrue);
      expect(subject.state.playing, isFalse);
      expect(lessons.watchesSent, isNotEmpty);
    });

    test('playing again from the end starts over', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(at(_content.duration, ended: true));

      await subject.play();

      expect(subject.state.position, Duration.zero);
      expect(subject.state.current, 0);
      expect(engine.seeks.last, Duration.zero);
    });
  });

  group('watching', () {
    /// Plays the seconds from [from] to [to], one report at a time.
    Future<void> watch(int from, int to) async {
      for (var second = from; second <= to; second++) {
        await report(at(Duration(seconds: second)));
      }
    }

    test('dragging ahead counts for nothing', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      await report(at(const Duration(seconds: 70)));
      await Future<void>.delayed(Duration.zero);

      expect(lessons.watchesSent, isEmpty);
    });

    test('reaching the panel\'s share is told to the server, once', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      final needed = _content.duration.inSeconds * 80 ~/ 100;

      await watch(0, needed - 2);
      expect(lessons.watchesSent, isEmpty);

      await watch(needed - 1, needed + 3);
      await Future<void>.delayed(Duration.zero);

      expect(lessons.watchesSent, hasLength(1));
    });

    test('it is kept on the phone along the way', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      await watch(0, 7);
      await Future<void>.delayed(Duration.zero);

      expect(lessons.watches['les'], isNotNull);
    });

    test('it carries on from where it stopped', () async {
      lessons.watches['les'] = WatchState(
        videoId: _content.video!.video.id,
        positionSeconds: 30,
        ranges: const [(0, 30)],
      );
      final subject = cubit();
      await subject.start();

      const from = Duration(seconds: 30);
      expect(subject.state.resumeFrom, from);
      expect(subject.state.current, _content.placeAt(from).sentence);

      await subject.play();
      expect(engine.opened.single.from, from);
      expect(subject.state.resumeFrom, isNull);
    });

    test('a replaced video starts over', () async {
      lessons.watches['les'] = const WatchState(
        videoId: 'old',
        positionSeconds: 30,
        ranges: [(0, 30)],
      );
      final subject = cubit();
      await subject.start();

      expect(subject.state.resumeFrom, isNull);
      expect(subject.state.position, Duration.zero);
    });
  });

  group('words', () {
    test('a card stops it, and closing it carries on from there', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(at(_content.sentences[4].words[3].start));
      final position = subject.state.position;

      expect(subject.selectWord(4, 3), isTrue);
      expect(subject.state.playing, isFalse);
      expect(engine.pauses, 1);

      await subject.closeCard();

      expect(subject.state.selection, isNull);
      expect(subject.state.playing, isTrue);
      expect(engine.seeks.last, position);
    });

    test(
      'a word with nothing to say leaves the press to its sentence',
      () async {
        final subject = cubit();
        await subject.start();

        expect(subject.selectWord(0, 0), isFalse);
      },
    );

    test('a saved word carries the video, for its moment', () async {
      final subject = cubit();
      await subject.start();
      subject.selectWord(4, 3);

      await subject.toggleSaved();

      expect(subject.state.saved, contains('wrapup'));
      expect(subject.state.savedNotice, isTrue);
      final (word, saved) = lessons.wordsSent.single;
      expect(saved, isTrue);
      expect(word.videoId, _content.video!.video.id);
    });

    test('its translation closes for that sentence alone', () async {
      final subject = cubit();
      await subject.start();

      subject.toggleTranslation(1);

      expect(subject.state.open, {1});
    });
  });

  group('how it shows', () {
    test('the choice is kept apart from a text\'s', () async {
      final subject = cubit();
      await subject.start();

      await subject.setMode(ReaderMode.englishOnly);

      expect(lessons.prefs.videoMode, ReaderMode.englishOnly);
      expect(lessons.prefs.mode, ReaderMode.onTap);
    });

    test('speed and quality reach the player', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(at(const Duration(seconds: 3)));

      await subject.setSpeed(1.5);
      expect(engine.speeds, [1.5]);

      await subject.setQuality(VideoQuality.high);
      expect(lessons.quality, VideoQuality.high);
      expect(engine.opened, hasLength(2));
      expect(engine.opened.last.from, const Duration(seconds: 3));
    });

    test('a failure offers another try', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      await report(const VideoSnapshot(failed: true));
      expect(subject.state.stage, VideoStage.failed);
      expect(subject.state.playing, isFalse);

      await subject.retry();
      expect(subject.state.stage, VideoStage.playing);
      expect(engine.opened, hasLength(2));
    });
  });

  group('page', () {
    var exits = 0;
    bool? continued;
    var words = 0;

    setUp(() {
      exits = 0;
      continued = null;
      words = 0;
    });

    Future<InteractiveVideoCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: InteractiveVideoPage(
            onExit: () => exits++,
            onContinue: (shadowing) => continued = shadowing,
            onShowWords: () => words++,
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await tester.pump();
      await tester.settleEntrance(_settled);
      return subject;
    }

    /// Plays at a word of a sentence, with what floats over it settled.
    Future<void> playAt(
      WidgetTester tester,
      InteractiveVideoCubit subject,
      int sentence,
      int word,
    ) async {
      await subject.goTo(sentence);
      engine.report(at(_content.sentences[sentence].words[word].start));
      await tester.pump();
      await tester.pump(_settled);
      await tester.pump(_settled);
    }

    Future<void> leave(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    }

    Finder said(String text) => find.text(text);

    testWidgets('the cover shows it all and marks nothing', (tester) async {
      await pump(tester);

      expect(said('Good'), findsOneWidget);
      expect(said('Omar'), findsWidgets);
      expect(said('reader_again'.tr()), findsNothing);
      expect(said(_content.sentences.first.arabic), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await leave(tester);
    });

    testWidgets('under the picture, the current sentence and its tools', (
      tester,
    ) async {
      final subject = await pump(tester);

      await playAt(tester, subject, 1, 2);

      expect(said(_content.sentences[1].arabic), findsOneWidget);
      expect(said('reader_again'.tr()), findsOneWidget);
      expect(said('reader_translation'.tr()), findsOneWidget);
      expect(said('reader_listen'.tr()), findsNothing);
      expect(said(_content.sentences[2].arabic), findsNothing);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('«الترجمة» closes the current one, and «أعد الجملة» says it', (
      tester,
    ) async {
      final subject = await pump(tester);
      await playAt(tester, subject, 1, 2);

      await tester.tap(said('reader_translation'.tr()));
      await tester.pump();
      await tester.pump(_settled);
      expect(said(_content.sentences[1].arabic), findsNothing);

      await tester.tap(said('reader_again'.tr()));
      await tester.pump();
      expect(
        engine.seeks.last,
        _content.sentences[1].start - const Duration(milliseconds: 200),
      );
      await subject.pause();
      await leave(tester);
    });

    testWidgets('there is no text over the picture, in any way of showing', (
      tester,
    ) async {
      final subject = await pump(tester);
      await playAt(tester, subject, 1, 2);

      expect(
        find.bySemanticsLabel('lesson_gv_captions_off'.tr()),
        findsNothing,
      );
      expect(said('lesson_gv_captions_badge'.tr()), findsNothing);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('practising listening shows bars and who speaks, and no way '
        'to reveal them', (tester) async {
      lessons.prefs = const ReaderPrefs(videoMode: ReaderMode.listening);
      final subject = await pump(tester);

      await playAt(tester, subject, 2, 1);

      expect(said('Omar'), findsWidgets);
      expect(said('Good'), findsNothing);
      expect(said('reader_reveal'.tr()), findsNothing);
      expect(said('reader_again'.tr()), findsNothing);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('translation only has no English', (tester) async {
      lessons.prefs = const ReaderPrefs(videoMode: ReaderMode.arabicOnly);
      final subject = await pump(tester);

      await playAt(tester, subject, 1, 1);

      expect(said('kilo.'), findsNothing);
      expect(said(_content.sentences[1].arabic), findsOneWidget);
      expect(said(_content.sentences[0].arabic), findsOneWidget);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('English only has no translation, nor its tool', (
      tester,
    ) async {
      lessons.prefs = const ReaderPrefs(videoMode: ReaderMode.englishOnly);
      final subject = await pump(tester);

      await playAt(tester, subject, 1, 1);

      expect(said(_content.sentences[1].arabic), findsNothing);
      expect(said('reader_translation'.tr()), findsNothing);
      expect(said('reader_again'.tr()), findsOneWidget);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('a pressed word opens its card and stops the picture', (
      tester,
    ) async {
      final subject = await pump(tester);
      await playAt(tester, subject, 0, 1);

      await tester.tap(said('much'));
      await tester.pump();
      await tester.pump(_settled);

      expect(find.byType(ReaderCard), findsOneWidget);
      expect(subject.state.playing, isFalse);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tapAt(const Offset(10, 700));
      await tester.pump();
      await tester.pump(_settled);

      expect(find.byType(ReaderCard), findsNothing);
      expect(subject.state.playing, isTrue);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('`Aa` offers the video\'s five ways, and keeps the choice', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.tap(find.bySemanticsLabel('reader_mode_title'.tr()).first);
      await tester.pump();
      await tester.pump(_settled);

      expect(said('reader_mode_current'.tr()), findsOneWidget);
      expect(said('reader_mode_current_detail'.tr()), findsOneWidget);
      expect(said('reader_mode_english_only'.tr()), findsOneWidget);
      expect(said('reader_mode_arabic_first'.tr()), findsOneWidget);
      expect(said('reader_mode_arabic_only'.tr()), findsOneWidget);
      expect(said('reader_mode_bars_detail'.tr()), findsOneWidget);
      expect(said('reader_mode_tap'.tr()), findsNothing);

      await tester.tap(said('reader_mode_english_only'.tr()));
      await tester.pump();
      await tester.pump(_settled);

      expect(subject.state.prefs.videoMode, ReaderMode.englishOnly);
      await leave(tester);
    });

    testWidgets('the speed\'s sheet goes from half to one and a half', (
      tester,
    ) async {
      final subject = await pump(tester);
      await playAt(tester, subject, 1, 1);
      await subject.pause();
      await tester.pump();
      await tester.pump(_settled);

      await tester.tap(
        find.bySemanticsLabel(
          'lesson_gv_speed_now'.tr(namedArgs: {'speed': '1'}),
        ),
      );
      await tester.pump();
      await tester.pump(_settled);

      await tester.tap(said('lesson_gv_speed'.tr(namedArgs: {'speed': '0.5'})));
      await tester.pump();
      await tester.pump(_settled);

      expect(subject.state.speed, .5);
      await leave(tester);
    });

    testWidgets('slow to load, it offers a lower quality', (tester) async {
      final subject = await pump(tester);
      await subject.play();
      await tester.pump();

      await tester.pump(const Duration(seconds: 6));
      expect(subject.state.slowConnection, isTrue);
      expect(said('lesson_gv_lower_quality'.tr()), findsOneWidget);

      await tester.tap(said('lesson_gv_lower_quality'.tr()));
      await tester.pump();
      expect(subject.state.quality, VideoQuality.low);
      expect(engine.opened, hasLength(2));
      await subject.pause();
      await leave(tester);
    });

    testWidgets('scrolling by hand stops the following until the pill', (
      tester,
    ) async {
      final subject = await pump(tester);
      await playAt(tester, subject, 1, 1);

      await tester.drag(said('price?'), const Offset(0, -120));
      await tester.pump();
      await tester.pump(_settled);

      expect(subject.state.following, isFalse);
      expect(said('reader_back_to_clip'.tr()), findsOneWidget);

      await tester.tap(said('reader_back_to_clip'.tr()));
      await tester.pump();
      await tester.pump(_settled);

      expect(subject.state.following, isTrue);
      expect(said('reader_back_to_clip'.tr()), findsNothing);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('the star says it kept the moment, and «اعرض» shows them', (
      tester,
    ) async {
      final subject = await pump(tester);
      subject.selectWord(4, 3);
      await tester.pump();
      await tester.pump(_settled);

      await subject.toggleSaved();
      await tester.pump();

      expect(said('reader_saved_with_time'.tr()), findsOneWidget);
      await subject.closeCard();
      await tester.pump();
      await tester.tap(said('reader_saved_show'.tr()));
      expect(words, 1);
      await leave(tester);
    });

    testWidgets('the end counts the phrases and goes on', (tester) async {
      final subject = await pump(tester);
      await subject.play();
      engine.report(at(_content.duration, ended: true));
      await tester.pump();
      await tester.pump(_settled);

      expect(said('reader_end_clip'.tr()), findsOneWidget);
      expect(
        find.textContaining(
          'reader_end_marked_phrases'.plural(_content.spans.length),
        ),
        findsOneWidget,
      );

      final button = said('reader_continue_shadowing'.tr());
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      expect(continued, isTrue);
      await leave(tester);
    });

    testWidgets('the way out', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));

      expect(exits, 1);
      await leave(tester);
    });

    group('sideways', () {
      Future<void> turn(WidgetTester tester) async {
        await tester.tap(find.bySemanticsLabel('lesson_gv_fullscreen'.tr()));
        await tester.pump();
        tester.setViewport(_sideways);
        await tester.pump();
        await tester.pump(_settled);
      }

      testWidgets('the panel has the current sentence and the next', (
        tester,
      ) async {
        final subject = await pump(tester);
        await playAt(tester, subject, 3, 3);
        await subject.pause();
        await tester.pump();
        await tester.pump(_settled);

        await turn(tester);

        expect(said('Fine.'), findsOneWidget);
        expect(said(_content.sentences[3].arabic), findsOneWidget);
        expect(said(_content.sentences[4].english), findsOneWidget);
        expect(said('reader_again'.tr()), findsNothing);
        expect(tester.takeException(), isNull);
        await leave(tester);
      });

      testWidgets('the mark sits on the word said, once it has turned', (
        tester,
      ) async {
        final subject = await pump(tester);
        await playAt(tester, subject, 3, 3);
        await subject.pause();
        engine.report(at(_content.sentences[3].words[3].start, playing: false));
        await tester.pump();
        await tester.pump(_settled);

        await turn(tester);
        await tester.pump(_settled);
        await tester.pump(_settled);

        final mark = find.descendant(
          of: find.byType(ReaderSentenceBlock),
          matching: find.byType(AnimatedPositionedDirectional),
        );
        final word = tester.getRect(find.text('out'));
        final box = tester.getRect(mark);
        expect(box.center.dx, moreOrLessEquals(word.center.dx, epsilon: 1));
        expect(box.center.dy, moreOrLessEquals(word.center.dy, epsilon: 1));
        expect(box.height, moreOrLessEquals(word.height, epsilon: 1));
        await leave(tester);
      });

      testWidgets('its tab hides it and the picture fills the screen', (
        tester,
      ) async {
        final subject = await pump(tester);
        await playAt(tester, subject, 1, 1);
        await subject.pause();
        await tester.pump();
        await tester.pump(_settled);
        await turn(tester);

        final picture = find.byType(LessonPlayer);
        final before = tester.getSize(picture).width;

        await tester.tap(find.bySemanticsLabel('reader_panel_hide'.tr()));
        await tester.pump();
        await tester.pump(_settled);

        expect(tester.getSize(picture).width, greaterThan(before));
        expect(find.bySemanticsLabel('reader_panel_show'.tr()), findsOneWidget);
        await leave(tester);
      });

      testWidgets('`Aa` is among the controls, and words are only to read', (
        tester,
      ) async {
        final subject = await pump(tester);
        await playAt(tester, subject, 0, 1);
        await subject.pause();
        await tester.pump();
        await tester.pump(_settled);
        await turn(tester);

        expect(find.bySemanticsLabel('reader_mode_title'.tr()), findsOneWidget);

        await tester.tap(said('much'));
        await tester.pump();

        expect(subject.state.selection, isNull);
        await leave(tester);
      });

      testWidgets('turning the phone takes the card away', (tester) async {
        final subject = await pump(tester);
        await playAt(tester, subject, 0, 1);
        await subject.pause();
        await tester.pump();
        await tester.pump(_settled);
        subject.selectWord(0, 3);
        await tester.pump();
        await tester.pump(_settled);

        expect(subject.state.selection, isNotNull);

        // The card covers nothing of the picture, so its controls can be called.
        await tester.tapAt(tester.getCenter(find.byType(LessonPlayer)));
        await tester.pump();
        await tester.pump(_settled);
        await tester.tap(find.bySemanticsLabel('lesson_gv_fullscreen'.tr()));
        await tester.pump();

        expect(subject.state.selection, isNull);
        await leave(tester);
      });

      testWidgets('back comes back upright first', (tester) async {
        final subject = await pump(tester);
        await playAt(tester, subject, 3, 1);
        await subject.pause();
        await tester.pump();
        await tester.pump(_settled);
        await turn(tester);

        await tester.tap(
          find.bySemanticsLabel('lesson_gv_fullscreen_exit'.tr()),
        );
        await tester.pump();
        tester.setViewport(defaultViewport);
        await tester.pump();
        await tester.pump(_settled);

        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(exits, 0);

        // The list came back from its top, and finds the sentence again.
        await tester.pump(_settled);
        final list = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(list.position.pixels, greaterThan(0));
        await leave(tester);
      });
    });

    testWidgets('only the current sentence redraws as the words change', (
      tester,
    ) async {
      final subject = await pump(tester);
      await playAt(tester, subject, 1, 1);
      final views = tester
          .widgetList<ReaderSentenceBlock>(find.byType(ReaderSentenceBlock))
          .toList();

      engine.report(at(_content.sentences[1].words[4].start));
      await tester.pump();

      final after = tester
          .widgetList<ReaderSentenceBlock>(find.byType(ReaderSentenceBlock))
          .toList();
      expect(identical(after[0], views[0]), isTrue);
      expect(identical(after[2], views[2]), isTrue);
      expect(identical(after[1], views[1]), isFalse);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('it can be read aloud', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(
        find.bySemanticsLabel('lesson_gv_play_video'.tr()),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Omar: Good')), findsOneWidget);
      handle.dispose();
      await leave(tester);
    });

    testLayouts('every way of showing fits', (tester, layout) async {
      for (final mode in ReaderMode.forVideo) {
        for (final size in ReaderTextSize.values) {
          lessons.prefs = ReaderPrefs(videoMode: mode, size: size);
          engine = FakeVideoEngine();
          final subject = await pump(
            tester,
            locale: layout.locale,
            size: layout.size,
            themeMode: layout.themeMode,
          );
          await playAt(tester, subject, 1, 1);
          expect(tester.takeException(), isNull);
          await subject.pause();
          await leave(tester);
        }
      }
    });

    testLayouts('the card, the end and sideways fit', (tester, layout) async {
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      subject.selectWord(0, 3);
      await tester.pump();
      await tester.pump(_settled);
      expect(tester.takeException(), isNull);
      await subject.closeCard();
      await tester.pump();

      await subject.play();
      await tester.pump();
      engine.report(at(_content.duration, ended: true));
      await tester.pump();
      await tester.pump(_settled);
      expect(tester.takeException(), isNull);

      await tester.tap(find.bySemanticsLabel('lesson_gv_fullscreen'.tr()));
      await tester.pump();
      tester.setViewport(Size(layout.size.height, layout.size.width));
      await tester.pump();
      await tester.pump(_settled);
      expect(tester.takeException(), isNull);
      await leave(tester);
    });
  });
}
