import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/widgets/letter_panel.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/data/datasources/lesson_remote_data_source.dart';
import 'package:englizia/features/lessons/data/models/vocabulary_model.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/cubit/vocab_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/pages/vocab_lesson_page.dart';
import 'package:englizia/features/lessons/presentation/vocabulary/widgets/vocab_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

const _settled = Duration(seconds: 1);

final _content = vocabularyFromJson(
  asJsonMap(
    ApiClient.unwrap(
      jsonDecode(File(LessonFakeDataSource.vocabularyAsset).readAsStringSync()),
    ),
  ),
)!;

void main() {
  setUpAll(initLocalizationForTests);

  late FakeLessonRepository lessons;
  late FakeClipPlayer player;
  late FakeDeviceVolume volume;

  setUp(() {
    lessons = FakeLessonRepository(exercises: const [])..vocabulary = _content;
    player = FakeClipPlayer(length: const Duration(milliseconds: 900));
    volume = FakeDeviceVolume();
  });

  VocabLessonCubit cubit() {
    final subject = VocabLessonCubit(lessons, player, volume, lessonId: 'les');
    addTearDown(subject.close);
    return subject;
  }

  group('the cards', () {
    test('the first word is said as it shows, with its ring', () async {
      final subject = cubit();
      await subject.start();
      await Future<void>.delayed(Duration.zero);

      expect(subject.state.load, LoadStatus.ready);
      expect(player.loaded.single, _content.words.first.audioUrl);
      expect(subject.state.wordRun?.length, const Duration(milliseconds: 900));
    });

    test('a lesson with no cards says so', () async {
      lessons.vocabulary = null;
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.failure);
    });

    test('with the volume down nothing is said, and it says so', () async {
      volume = FakeDeviceVolume(muted: true);
      final subject = cubit();
      await subject.start();

      expect(subject.state.muted, isTrue);
      expect(player.loaded, isEmpty);

      volume.muted = false;
      await Future<void>.delayed(Duration.zero);
      expect(subject.state.muted, isFalse);
    });

    test('a sound that fails says so, and «إعادة» tries again', () async {
      player.fails = 1;
      final subject = cubit();
      await subject.start();
      await Future<void>.delayed(Duration.zero);

      expect(subject.state.audioFailed, isTrue);
      subject.next();
      expect(player.loaded, hasLength(1));

      await subject.retryAudio();
      expect(subject.state.audioFailed, isFalse);
      expect(player.loaded, hasLength(2));
    });

    test('«التالي» and the previous one say their word', () async {
      final subject = cubit();
      await subject.start();

      subject.next();
      await Future<void>.delayed(Duration.zero);
      expect(subject.state.index, 1);
      expect(player.loaded.last, _content.words[1].audioUrl);

      subject.previous();
      await Future<void>.delayed(Duration.zero);
      expect(subject.state.index, 0);
      expect(player.loaded.last, _content.words[0].audioUrl);

      subject.previous();
      expect(subject.state.index, 0);
    });

    test(
      'after the last card, the review, and the content is done once',
      () async {
        final subject = cubit();
        await subject.start();

        for (var i = 0; i < _content.words.length; i++) {
          subject.next();
        }
        expect(subject.state.review, isTrue);
        expect(lessons.contentDone, 1);

        subject
          ..again()
          ..next();
        for (var i = 1; i < _content.words.length; i++) {
          subject.next();
        }
        expect(lessons.contentDone, 1);
      },
    );

    test('«راجع البطاقات مرة أخرى» starts over', () async {
      final subject = cubit();
      await subject.start();
      for (var i = 0; i < _content.words.length; i++) {
        subject.next();
      }

      subject.again();

      expect(subject.state.review, isFalse);
      expect(subject.state.index, 0);
    });

    test('the example is said and its translation stays shown', () async {
      final subject = cubit();
      await subject.start();

      await subject.sayExample();
      expect(player.loaded.last, _content.words.first.example.audioUrl);
      expect(subject.state.exampleRun, isNotNull);
      expect(subject.state.wordRun, isNull);

      subject.reveal();
      expect(subject.state.revealed, {0});
    });

    test('the star keeps the card in the word bank', () async {
      final subject = cubit();
      await subject.start();

      await subject.toggleSaved();
      expect(subject.state.saved, {_content.words.first.id});
      expect(subject.state.savedNotice, isTrue);
      expect(lessons.vocabSent.single.$2, isTrue);

      await subject.toggleSaved();
      expect(subject.state.saved, isEmpty);
      expect(lessons.vocabSent.last.$2, isFalse);
    });

    test('the review says a word without a ring', () async {
      final subject = cubit();
      await subject.start();

      await subject.sayWordAt(3);

      expect(player.loaded.last, _content.words[3].audioUrl);
      expect(subject.state.wordRun, isNull);
    });
  });

  group('page', () {
    var exits = 0;
    var started = 0;
    var words = 0;

    setUp(() {
      exits = 0;
      started = 0;
      words = 0;
    });

    Future<VocabLessonCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: VocabLessonPage(
            onExit: () => exits++,
            onStartExercises: () => started++,
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

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(_settled);
    }

    Future<void> leave(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }

    Finder said(String text) => find.text(text);

    Finder top() => find.byWidgetPredicate(
      (widget) => widget is VocabCard && widget.onSave != null,
    );

    testWidgets('a card has its word, kind, meaning and example', (
      tester,
    ) async {
      await pump(tester);

      final first = _content.words.first;
      expect(find.descendant(of: top(), matching: said(first.word)), findsOne);
      expect(said('vocab_kind_noun'.tr()), findsWidgets);
      expect(said(first.arabic), findsWidgets);
      expect(said('vocab_reveal'.tr()), findsOneWidget);
      expect(said(first.example.arabic), findsNothing);
      expect(
        said('vocab_counter'.tr(namedArgs: {'at': '1', 'of': '6'})),
        findsOneWidget,
      );
      await leave(tester);
    });

    testWidgets('the translation shows when asked for', (tester) async {
      await pump(tester);

      await tester.tap(said('vocab_reveal'.tr()));
      await settle(tester);

      expect(said(_content.words.first.example.arabic), findsOneWidget);
      expect(said('vocab_reveal'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('«التالي» moves on, and the previous one comes back', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.tap(said('vocab_next'.tr()));
      await settle(tester);

      expect(subject.state.index, 1);
      expect(
        find.descendant(of: top(), matching: said(_content.words[1].word)),
        findsOne,
      );
      expect(
        said('vocab_counter'.tr(namedArgs: {'at': '2', 'of': '6'})),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('vocab_previous'.tr()));
      await settle(tester);
      expect(subject.state.index, 0);
      await leave(tester);
    });

    testWidgets('there is no previous card to the first', (tester) async {
      final subject = await pump(tester);

      await tester.tap(find.bySemanticsLabel('vocab_previous'.tr()));
      await settle(tester);

      expect(subject.state.index, 0);
      await leave(tester);
    });

    testWidgets('in Arabic, dragging right moves on and left comes back', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.drag(top(), const Offset(220, 0));
      await settle(tester);
      expect(subject.state.index, 1);

      await tester.drag(top(), const Offset(-220, 0));
      await settle(tester);
      expect(subject.state.index, 0);
      await leave(tester);
    });

    testWidgets('in English, dragging left moves on', (tester) async {
      final subject = await pump(tester, locale: const Locale('en'));

      await tester.drag(top(), const Offset(-220, 0));
      await settle(tester);

      expect(subject.state.index, 1);
      await leave(tester);
    });

    testWidgets('a short drag springs back', (tester) async {
      final subject = await pump(tester);

      await tester.drag(top(), const Offset(60, 0));
      await settle(tester);

      expect(subject.state.index, 0);
      expect(tester.getTopLeft(top()).dx, moreOrLessEquals(20, epsilon: 1));
      await leave(tester);
    });

    testWidgets('the star says it went to the word bank, with «اعرض»', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.bySemanticsLabel('reader_save'.tr()));
      await settle(tester);

      expect(said('reader_saved_notice'.tr()), findsOneWidget);
      await tester.tap(said('reader_saved_show'.tr()));
      expect(words, 1);
      await leave(tester);
    });

    testWidgets('a failed sound shows its strip, and «إعادة» clears it', (
      tester,
    ) async {
      player.fails = 1;
      await pump(tester);

      expect(said('vocab_audio_failed'.tr()), findsOneWidget);

      await tester.tap(said('vocab_retry'.tr()));
      await settle(tester);

      expect(said('vocab_audio_failed'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('the volume note shows on the first card only', (tester) async {
      volume = FakeDeviceVolume(muted: true);
      final subject = await pump(tester);

      expect(said('vocab_muted'.tr()), findsOneWidget);

      subject.next();
      await settle(tester);
      expect(said('vocab_muted'.tr()), findsNothing);
      await leave(tester);
    });

    testWidgets('a word without a picture shows its first letter', (
      tester,
    ) async {
      final subject = await pump(tester);

      for (var i = 0; i < 5; i++) {
        subject.next();
      }
      await settle(tester);

      expect(
        find.descendant(of: top(), matching: find.byType(LetterPanel)),
        findsOneWidget,
      );
      await leave(tester);
    });

    testWidgets('the review lists the words and leads to the exercises', (
      tester,
    ) async {
      final subject = await pump(tester);
      await subject.toggleSaved();
      for (var i = 0; i < _content.words.length; i++) {
        subject.next();
      }
      await settle(tester);

      expect(said('vocab_review_title'.tr()), findsOneWidget);
      expect(said('vocab_review_counter'.tr()), findsOneWidget);

      await tester.tap(said(_content.words.first.word));
      await tester.pump();
      expect(player.loaded.last, _content.words.first.audioUrl);

      await tester.tap(said('vocab_start_exercises'.tr()));
      expect(started, 1);

      await tester.tap(said('vocab_again'.tr()));
      await settle(tester);
      expect(subject.state.review, isFalse);
      await leave(tester);
    });

    testWidgets('the way out', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));

      expect(exits, 1);
      await leave(tester);
    });

    testWidgets('a reader hears the card whole', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(
        find.bySemanticsLabel(RegExp('^barn، ${'vocab_kind_noun'.tr()}، ')),
        findsWidgets,
      );
      expect(find.bySemanticsLabel('vocab_reveal_said'.tr()), findsOneWidget);
      handle.dispose();
      await leave(tester);
    });

    testLayouts('every card and the review fit', (tester, layout) async {
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      for (var i = 0; i < _content.words.length; i++) {
        subject.reveal();
        await subject.toggleSaved();
        await settle(tester);
        expect(tester.takeException(), isNull);
        subject.next();
      }
      await settle(tester);
      expect(tester.takeException(), isNull);
      await leave(tester);
    });
  });
}
