import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/core/video/silent_audio_engine.dart';
import 'package:englizia/core/video/video_engine.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/reader_model.dart';
import 'package:englizia/features/lessons/domain/entities/reader_content.dart';
import 'package:englizia/features/lessons/presentation/reader/cubit/interactive_text_cubit.dart';
import 'package:englizia/features/lessons/presentation/reader/pages/interactive_text_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);

final _content = readerFromJson(
  asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(LessonFakeDataSource.textAsset).readAsStringSync()),
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

  InteractiveTextCubit cubit() {
    final subject = InteractiveTextCubit(lessons, engine, lessonId: 'les');
    addTearDown(subject.close);
    return subject;
  }

  VideoSnapshot at(Duration position, {bool playing = true}) =>
      VideoSnapshot(position: position, playing: playing, ready: true);

  Future<void> report(VideoSnapshot snapshot) async {
    engine.report(snapshot);
    await Future<void>.delayed(Duration.zero);
  }

  group('following the sound', () {
    test('nothing plays by itself, and opening asks for the sound', () async {
      final subject = cubit();
      await subject.start();
      expect(engine.opened, isEmpty);
      expect(subject.state.current, 0);

      await subject.play();

      expect(engine.opened.single.url, _content.audioUrl);
    });

    test('the sentence and word follow the time, frame by frame', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      final target = _content.sentences[1].words[2];

      await report(at(target.start));
      subject.tick(const Duration(milliseconds: 16));

      expect(subject.state.current, 1);
      expect(subject.state.word, 2);
    });

    test('a report close to the running time leaves it alone', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      subject.tick(const Duration(seconds: 2));
      final running = subject.state.position;

      await report(at(running - const Duration(milliseconds: 100)));

      expect(subject.state.position, running);
    });

    test('the running time goes at its speed', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await subject.cycleSpeed();
      expect(subject.state.speed, 1.25);
      expect(engine.speeds, [1.25]);

      subject.tick(const Duration(seconds: 2));

      expect(subject.state.position, const Duration(milliseconds: 2500));
    });

    test('while paused the time stands still', () async {
      final subject = cubit();
      await subject.start();

      subject.tick(const Duration(seconds: 2));

      expect(subject.state.position, Duration.zero);
    });

    test('«استمع» plays that sentence alone', () async {
      final subject = cubit();
      await subject.start();
      final sentence = _content.sentences[2];

      await subject.listenTo(2);
      expect(engine.opened.single.from, sentence.start);

      subject.tick(sentence.end - sentence.start);

      expect(subject.state.playing, isFalse);
      expect(subject.state.position, sentence.end);
      expect(engine.pauses, 1);
    });

    test('stopping after each sentence stops as it ends', () async {
      lessons.prefs = const ReaderPrefs(stopEachSentence: true);
      final subject = cubit();
      await subject.start();
      await subject.play();

      subject.tick(_content.sentences[0].end + const Duration(seconds: 1));

      expect(subject.state.playing, isFalse);
      expect(subject.state.current, 0);
      expect(subject.state.position, _content.sentences[0].end);
    });

    test(
      'a sentence pressed becomes the current one, and the sound goes',
      () async {
        final subject = cubit();
        await subject.start();
        await subject.play();

        await subject.goTo(3);

        expect(subject.state.current, 3);
        expect(engine.seeks.single, _content.sentences[3].start);
      },
    );

    test('the end says so once, and tells the server', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      subject.tick(_content.duration);
      subject.reachedEnd();

      expect(subject.state.finished, isTrue);
      expect(subject.state.playing, isFalse);
      expect(lessons.contentDone, 1);
    });

    test('scrolling by hand stops the following, until asked', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      subject.stopFollowing();
      expect(subject.state.following, isFalse);

      subject.followAgain();
      expect(subject.state.following, isTrue);
    });

    test('a sound that fails leaves the text, and tries again', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      await report(const VideoSnapshot(failed: true));
      expect(subject.state.audioFailed, isTrue);
      expect(subject.state.playing, isFalse);

      await subject.retryAudio();
      expect(subject.state.audioFailed, isFalse);
      expect(engine.opened, hasLength(2));
    });

    test('a lesson with no such content is a failure with a retry', () async {
      lessons.reader = null;
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.failure);
    });

    test('a lesson that fails to load says why', () async {
      lessons.failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();

      expect(subject.state.failure, const NetworkFailure());
    });
  });

  group('a word pressed', () {
    test('any word of a span opens it, and the sound waits', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();

      expect(subject.selectWord(4, 3), isTrue);

      expect(subject.state.selection?.span?.id, 'turnoff');
      expect(engine.pauses, 1);
    });

    test('a word with a meaning opens its small card', () async {
      final subject = cubit();
      await subject.start();

      expect(subject.selectWord(0, 3), isTrue);

      expect(subject.state.selection?.span, isNull);
      expect(subject.state.selection?.word, 3);
    });

    test('a word with nothing opens nothing: no AI is asked', () async {
      final subject = cubit();
      await subject.start();

      expect(subject.selectWord(0, 0), isFalse);
      expect(subject.state.selection, isNull);
    });

    test('closing carries on from where it stopped', () async {
      final subject = cubit();
      await subject.start();
      await subject.play();
      await report(at(const Duration(seconds: 20)));
      subject.selectWord(4, 1);
      await report(at(const Duration(seconds: 20), playing: false));

      await subject.closeCard();

      expect(subject.state.selection, isNull);
      expect(subject.state.playing, isTrue);
      expect(engine.seeks.last, const Duration(seconds: 20));
    });

    test('closing when it was paused stays paused', () async {
      final subject = cubit();
      await subject.start();
      subject.selectWord(4, 1);

      await subject.closeCard();

      expect(subject.state.playing, isFalse);
      expect(engine.opened, isEmpty);
    });

    test('its sound is cut by the words, across a word between', () async {
      final subject = cubit();
      await subject.start();
      subject.selectWord(4, 1);
      final words = _content.sentences[4].words;

      await subject.sayCard();
      expect(engine.opened.single.from, words[1].start);

      subject.tick(words[3].end - words[1].start);

      expect(subject.state.playing, isFalse);
      expect(subject.state.position, words[3].end);
    });

    test('the star saves the span whole, and takes it back', () async {
      final subject = cubit();
      await subject.start();
      subject.selectWord(4, 1);

      await subject.toggleSaved();
      expect(subject.state.saved, {'turnoff'});
      expect(subject.state.savedNotice, isTrue);
      final (word, saved) = lessons.wordsSent.single;
      expect(saved, isTrue);
      expect(word.span.base, 'turn off');
      expect(word.sentence.english, contains('turn it off'));

      await subject.toggleSaved();
      expect(subject.state.saved, isEmpty);
      expect(lessons.wordsSent.last.$2, isFalse);
    });
  });

  group('the settings', () {
    test('come from the phone, and go back to it', () async {
      lessons.prefs = const ReaderPrefs(size: ReaderTextSize.large);
      final subject = cubit();
      await subject.start();
      expect(subject.state.prefs.size, ReaderTextSize.large);

      await subject.setPrefs(
        subject.state.prefs.copyWith(mode: ReaderMode.below),
      );

      expect(lessons.prefs.mode, ReaderMode.below);
    });

    test('a new way of showing hides what was revealed again', () async {
      final subject = cubit();
      await subject.start();
      subject.reveal(1);

      await subject.setPrefs(
        subject.state.prefs.copyWith(mode: ReaderMode.listening),
      );

      expect(subject.state.revealed, isEmpty);
    });

    test('the tip shows until it has been seen, and only then', () async {
      lessons.tipSeen = false;
      final subject = cubit();
      await subject.start();
      expect(subject.state.showTip, isTrue);

      subject.closeTip();

      expect(subject.state.showTip, isFalse);
      expect(lessons.tipSeen, isTrue);
    });
  });

  test('the silent sound passes its time, and a broken one fails', () async {
    final silent = SilentAudioEngine();
    addTearDown(silent.dispose);
    final seen = <VideoSnapshot>[];
    final subscription = silent.changes.listen(seen.add);
    addTearDown(subscription.cancel);

    await silent.open('https://example.com/broken.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.failed, isTrue);

    await silent.open('https://example.com/ok.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.playing, isTrue);
    await silent.pause();
  });

  group('the page', () {
    var exits = 0;
    bool? continued;
    var words = 0;

    setUp(() {
      exits = 0;
      continued = null;
      words = 0;
    });

    Future<InteractiveTextCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: InteractiveTextPage(
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

    Future<void> leave(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }

    Finder word(String text) => find.text(text);

    testWidgets('the words, the current sentence\'s tools and the player', (
      tester,
    ) async {
      await pump(tester);

      expect(word('Sara'), findsWidgets);
      expect(find.text('lesson_kind_interactive_text'.tr()), findsOneWidget);
      expect(find.text('reader_listen'.tr()), findsOneWidget);
      expect(find.text('reader_translation'.tr()), findsOneWidget);
      expect(
        find.text('reader_sentence_of'.tr(namedArgs: {'at': '1', 'of': '6'})),
        findsOneWidget,
      );
      await leave(tester);
    });

    testWidgets('the translation opens, and stays when the sound moves', (
      tester,
    ) async {
      final subject = await pump(tester);
      final arabic = _content.sentences[0].arabic;
      expect(find.text(arabic), findsNothing);

      await tester.tap(find.text('reader_translation'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text(arabic), findsOneWidget);

      await subject.goTo(1);
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text(arabic), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a span\'s card: form, kind, meaning, note and star', (
      tester,
    ) async {
      final subject = await pump(tester);

      subject.selectWord(4, 1);
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(find.text('turn off'), findsOneWidget);
      expect(find.text('reader_kind_phrasal'.tr()), findsOneWidget);
      expect(find.text('يُطفئ'), findsOneWidget);
      expect(find.bySemanticsLabel('reader_save'.tr()), findsOneWidget);
      await leave(tester);
    }, semanticsEnabled: true);

    testWidgets('pressing a dotted word opens it, outside closes it', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.tap(word('wakes'));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(subject.state.selection?.span?.id, 'wakeup');

      await tester.tapAt(const Offset(10, 300));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(subject.state.selection, isNull);
      await leave(tester);
    });

    testWidgets('a small card has its word and meaning', (tester) async {
      final subject = await pump(tester);

      subject.selectWord(0, 3);
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(find.text('باكرًا'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('saving shows its notice, with the way to the words', (
      tester,
    ) async {
      final subject = await pump(tester);
      subject.selectWord(4, 1);
      await tester.pump();
      await subject.toggleSaved();
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(find.text('reader_saved_notice'.tr()), findsOneWidget);
      await subject.closeCard();
      await tester.pump();
      await tester.settleEntrance(_settled);

      await tester.tap(find.text('reader_saved_show'.tr()));
      await tester.pump();
      expect(words, 1);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('reader_saved_notice'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('the first time, the tip; pressing anywhere closes it', (
      tester,
    ) async {
      lessons.tipSeen = false;
      await pump(tester);
      await tester.pump();
      expect(find.text('reader_tip'.tr()), findsOneWidget);

      await tester.tap(find.text('reader_tip_ok'.tr()));
      await tester.pump();

      expect(find.text('reader_tip'.tr()), findsNothing);
      expect(lessons.tipSeen, isTrue);
      await leave(tester);
    });

    testWidgets('a sound that fails says so, and the card still works', (
      tester,
    ) async {
      final subject = await pump(tester);
      await subject.play();
      engine.report(const VideoSnapshot(failed: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('reader_audio_failed'.tr()), findsOneWidget);

      subject.selectWord(4, 1);
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text('turn off'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('the settings sheet changes how the text shows', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.tap(find.text('reader_size_sample'.tr()).first);
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(find.text('reader_mode_title'.tr()), findsOneWidget);

      await tester.tap(find.text('reader_mode_below'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(subject.state.prefs.mode, ReaderMode.below);

      await tester.tap(find.text('reader_settings_done'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(find.text(_content.sentences[0].arabic), findsOneWidget);
      expect(find.text(_content.sentences[5].arabic), findsOneWidget);
      expect(find.text('reader_translation'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('listening hides the words until «أظهر»', (tester) async {
      lessons.prefs = const ReaderPrefs(mode: ReaderMode.listening);
      await pump(tester);
      expect(word('Sara'), findsNothing);
      expect(find.text('reader_reveal'.tr()), findsNWidgets(6));

      await tester.tap(find.text('reader_reveal'.tr()).first);
      await tester.pump();
      await tester.settleEntrance(_settled);

      expect(find.text('reader_reveal'.tr()), findsNWidgets(5));
      expect(word('wakes'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('translation only has no English', (tester) async {
      lessons.prefs = const ReaderPrefs(mode: ReaderMode.arabicOnly);
      await pump(tester);

      expect(word('wakes'), findsNothing);
      expect(find.text(_content.sentences[0].arabic), findsOneWidget);
      await leave(tester);
    });

    testWidgets('dragging while it plays offers the way back', (tester) async {
      final subject = await pump(tester);
      await subject.play();
      await tester.pump();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();

      expect(subject.state.following, isFalse);
      expect(find.text('reader_back_to_current'.tr()), findsOneWidget);

      await tester.tap(find.text('reader_back_to_current'.tr()));
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(subject.state.following, isTrue);
      await subject.pause();
      await leave(tester);
    });

    testWidgets('the end: its counts, and the way on', (tester) async {
      await pump(tester);

      await tester.ensureVisible(find.text('reader_end_title'.tr()));
      await tester.pump();
      await tester.tap(find.text('reader_continue_shadowing'.tr()));
      await tester.pump();

      expect(continued, isTrue);
      await leave(tester);
    });

    testWidgets('with no sentences to practise, on to the exercises', (
      tester,
    ) async {
      lessons.reader = ReaderContent(
        audioUrl: 'a',
        duration: _content.duration,
        sentences: [
          for (final s in _content.sentences)
            ReaderSentence(id: s.id, words: s.words, arabic: s.arabic),
        ],
      );
      await pump(tester);

      await tester.ensureVisible(find.text('reader_continue_exercises'.tr()));
      await tester.pump();
      await tester.tap(find.text('reader_continue_exercises'.tr()));
      await tester.pump();

      expect(continued, isFalse);
      await leave(tester);
    });

    testWidgets('leaving is one press', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('lesson_gv_exit'.tr()));
      await tester.pump();

      expect(exits, 1);
      await leave(tester);
    });

    testLayouts('every way of showing fits', (tester, layout) async {
      for (final mode in ReaderMode.values) {
        for (final size in ReaderTextSize.values) {
          lessons.prefs = ReaderPrefs(mode: mode, size: size);
          await pump(
            tester,
            locale: layout.locale,
            size: layout.size,
            themeMode: layout.themeMode,
          );
          expect(tester.takeException(), isNull);
          await leave(tester);
        }
      }
    });

    testLayouts('cards, the tip and the sheet fit', (tester, layout) async {
      lessons.tipSeen = false;
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      subject.closeTip();
      await tester.pump();

      for (final (sentence, word) in const [(4, 1), (5, 4), (0, 3), (2, 6)]) {
        subject.selectWord(sentence, word);
        await tester.pump();
        await tester.settleEntrance(_settled);
        expect(tester.takeException(), isNull);
        await subject.closeCard();
        await tester.pump();
      }

      await tester.tap(find.text('reader_size_sample'.tr()).first);
      await tester.pump();
      await tester.settleEntrance(_settled);
      expect(tester.takeException(), isNull);
      await leave(tester);
    });
  });
}
