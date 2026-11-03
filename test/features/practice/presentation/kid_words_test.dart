import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/practice/data/models/word_bank_model.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/presentation/kids/cubit/kid_words_cubit.dart';
import 'package:englizia/features/practice/presentation/kids/pages/kid_review_page.dart';
import 'package:englizia/features/practice/presentation/kids/pages/kid_words_page.dart';
import 'package:englizia/features/practice/presentation/review/cubit/review_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_practice_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  final today = DateTime(2026, 11, 3, 10);
  late FakePracticeRepository practice;
  late FakeClipPlayer player;

  setUp(() {
    practice = FakePracticeRepository(bank: mockKidBank(today), now: today);
    player = FakeClipPlayer(length: const Duration(milliseconds: 300));
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  group('the bank', () {
    test('a child\'s words: pictures by unit, with no sentence', () {
      final bank = mockKidBank(today);

      expect(bank.words, hasLength(24));
      expect(bank.units.map((u) => u.id), ['colors', 'animals', 'food']);
      final cat = bank.words.firstWhere((w) => w.word == 'cat');
      expect(cat.unitId, 'animals');
      expect(cat.sentence, isEmpty);
      expect(cat.imageUrl, isNotNull);
      expect(bank.kidsVoice.empty, isNotNull);
    });

    test('kept on the phone with its units and voice', () {
      final bank = mockKidBank(today);

      final again = WordBankModel(WordBankModel.fromEntity(bank)).toEntity();

      expect(again.units, bank.units);
      expect(again.kidsVoice, bank.kidsVoice);
      expect(again.words.first.unitId, bank.words.first.unitId);
    });
  });

  group('the cubit', () {
    KidWordsCubit cubit() {
      final subject = KidWordsCubit(practice, player);
      addTearDown(subject.close);
      return subject;
    }

    test('says what the screen is, and filters by unit', () async {
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.ready);
      expect(player.loaded.first, practice.bank!.kidsVoice.words);
      subject.filter('food');
      expect(subject.state.shown, hasLength(8));
      expect(subject.state.shown.every((w) => w.unitId == 'food'), isTrue);
      subject.filter(null);
      expect(subject.state.shown, hasLength(24));
    });

    test('a word pressed says itself', () async {
      final subject = cubit();
      await subject.start();
      final cat = subject.state.shown.firstWhere((w) => w.word == 'cat');

      await subject.say(cat);

      expect(player.loaded.last, cat.audioUrl);
      expect(subject.state.said, cat.id);
    });

    test('none yet: the guide says how to collect them', () async {
      practice.bank = const WordBank(
        words: [],
        kidsVoice: KidWordsVoice(empty: 'https://example.com/empty.mp3'),
      );
      final subject = cubit();
      await subject.start();

      expect(player.loaded.single, 'https://example.com/empty.mp3');
    });
  });

  group('the pages', () {
    var played = 0;

    Future<KidWordsCubit> words(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      played = 0;
      final subject = KidWordsCubit(practice, player);
      addTearDown(subject.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: Scaffold(body: KidWordsPage(onPlay: () async => played++)),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await settle(tester);
      return subject;
    }

    testWidgets('the count, the game, the units and the grid', (tester) async {
      final subject = await words(tester);

      expect(find.text('kid_words_count'.plural(24)), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('الحيوانات'));
      await tester.pump();
      expect(subject.state.unit, 'animals');
      expect(find.text('red'), findsNothing);
      expect(find.text('cat'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('kid_play_words'.tr()));
      await settle(tester);
      expect(played, 1);
    });

    testWidgets('none yet: the guide and an empty box', (tester) async {
      practice.bank = const WordBank(words: []);
      await words(tester);

      expect(find.text('kid_play_words'.tr()), findsNothing);
      expect(find.bySemanticsLabel('kid_listen'.tr()), findsOneWidget);
    });

    Future<ReviewCubit> review(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final subject = ReviewCubit(practice, player, now: () => today)..start();
      addTearDown(subject.close);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: KidReviewPage(voice: practice.bank!.kidsVoice, onExit: () {}),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await settle(tester);
      return subject;
    }

    testWidgets('«العب بكلماتي»: each card says itself, then a star each', (
      tester,
    ) async {
      final subject = await review(tester);
      final count = subject.state.words.length;
      expect(count, 4);
      expect(player.loaded, contains(subject.state.word!.audioUrl));

      for (var card = 0; card < count; card++) {
        await tester.tap(
          find.bySemanticsLabel(
            card.isEven ? 'kid_know'.tr() : 'kid_dont_know'.tr(),
          ),
        );
        await settle(tester);
      }

      expect(practice.answers.map((a) => a.$2), [true, false, true, false]);
      expect(subject.state.word, isNull);
      expect(
        find.bySemanticsLabel('kid_review_stars'.plural(4)),
        findsOneWidget,
      );
      expect(find.byType(KidStar), findsWidgets);
    });

    testLayouts('they fit', (tester, layout) async {
      await words(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
      final subject = await review(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
      for (var card = 0; card < subject.state.words.length; card++) {
        await tester.tap(find.bySemanticsLabel('kid_know'.tr()));
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
