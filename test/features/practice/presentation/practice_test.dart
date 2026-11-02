import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/app/shell/tab_shell.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/presentation/practice/cubit/practice_cubit.dart';
import 'package:englizia/features/practice/presentation/practice/pages/practice_page.dart';
import 'package:englizia/features/practice/presentation/review/cubit/review_cubit.dart';
import 'package:englizia/features/practice/presentation/review/pages/review_page.dart';
import 'package:englizia/features/practice/presentation/widgets/word_parts.dart';
import 'package:englizia/features/practice/presentation/words/cubit/my_words_cubit.dart';
import 'package:englizia/features/practice/presentation/words/pages/my_words_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_practice_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

final _today = DateTime(2026, 11, 2, 10);
const _settled = Duration(seconds: 1);

void main() {
  setUpAll(initLocalizationForTests);

  late FakePracticeRepository practice;
  late FakeClipPlayer player;

  setUp(() {
    practice = FakePracticeRepository(bank: mockBank(_today), now: _today);
    player = FakeClipPlayer();
  });

  WordBank laterBank() => practice.bank!.copyWith(
    words: [
      for (final word in practice.bank!.words)
        word.copyWith(dueAt: DateTime(2026, 11, 3)),
    ],
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(_settled);
  }

  Finder said(String text) => find.text(text);

  group('the tab', () {
    PracticeCubit cubit() {
      final subject = PracticeCubit(practice, now: () => _today);
      addTearDown(subject.close);
      return subject;
    }

    test('the bank, what is due, and the badge with the concepts', () async {
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.ready);
      expect(subject.state.due, 9);
      expect(subject.state.badge, 12);
    });

    test('the kept bank shows at once; offline it stays', () async {
      practice.failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.ready);
    });

    test('nothing kept and no connection says so', () async {
      practice
        ..bank = null
        ..failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();

      expect(subject.state.load, LoadStatus.failure);
    });

    Future<PracticeCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      void Function()? onReview,
      void Function()? onWords,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: BlocSelector<PracticeCubit, PracticeState, int>(
            selector: (state) => state.badge,
            builder: (context, badge) => TabShell(
              current: AppTab.practice,
              badges: {AppTab.practice: badge},
              onSelect: (_) {},
              child: PracticePage(
                onReview: () async => onReview?.call(),
                onWords: () async => onWords?.call(),
                onConcepts: () async {},
                onSentences: () {},
              ),
            ),
          ),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await subject.start();
      await settle(tester);
      return subject;
    }

    testWidgets('the bank, its boxes, and the way to review', (tester) async {
      var reviews = 0;
      var lists = 0;
      await pump(tester, onReview: () => reviews++, onWords: () => lists++);

      expect(said('practice_words_count'.plural(12)), findsOneWidget);
      expect(said('practice_due'.plural(9)), findsOneWidget);
      expect(find.byType(StrengthChart), findsOneWidget);
      expect(said('practice_concepts'.plural(3)), findsOneWidget);
      expect(said('practice_sentences'.plural(9)), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'tab_with_badge'.tr(
            namedArgs: {'tab': 'tab_practice'.tr(), 'count': '12'},
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(said('practice_review'.tr()));
      await tester.tap(said('practice_all_words'.tr()));
      await settle(tester);
      expect(reviews, 1);
      expect(lists, 1);
    });

    testWidgets('nothing due: the guide asleep, and reviewing anyway', (
      tester,
    ) async {
      practice.bank = laterBank();
      await pump(tester);

      expect(said('practice_none_due'.tr()), findsOneWidget);
      expect(said('practice_review_anyway'.tr()), findsOneWidget);
      expect(said('practice_review'.tr()), findsNothing);
    });

    testWidgets('a new learner learns where words come from', (tester) async {
      practice.bank = const WordBank(words: []);
      await pump(tester);

      expect(said('practice_new'.tr()), findsOneWidget);
      expect(said('practice_review'.tr()), findsNothing);
      expect(said('practice_concepts'.plural(0)), findsNothing);
    });

    testLayouts('it fits', (tester, layout) async {
      for (final bank in [
        mockBank(_today),
        laterBank(),
        const WordBank(words: []),
      ]) {
        practice.bank = bank;
        await pump(
          tester,
          locale: layout.locale,
          size: layout.size,
          themeMode: layout.themeMode,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('a review', () {
    ReviewCubit cubit() {
      final subject = ReviewCubit(practice, player, now: () => _today)..start();
      addTearDown(subject.close);
      return subject;
    }

    test(
      'it takes the words due, and turning comes before answering',
      () async {
        final subject = cubit();

        expect(subject.state.words, hasLength(9));
        await subject.answer(known: true);
        expect(practice.answers, isEmpty);

        subject.flip();
        await subject.answer(known: true);
        final first = subject.state.words.first;
        expect(practice.answers.single, (first.id, true));
        expect(
          subject.state.flash,
          ReviewFlash(known: true, days: [1, 3, 7, 14, 30][first.box]),
        );

        subject.next();
        expect(subject.state.index, 1);
        expect(subject.state.flipped, isFalse);
      },
    );

    test('«لم أعرفها» comes back tomorrow, and the end counts', () async {
      final subject = cubit();
      final total = subject.state.words.length;

      for (var i = 0; i < total; i++) {
        subject.flip();
        await subject.answer(known: i.isEven);
        if (i == 1) {
          expect(subject.state.flash, const ReviewFlash(known: false, days: 1));
        }
        subject.next();
      }

      expect(subject.state.done, isTrue);
      expect(subject.state.known, (total + 1) ~/ 2);
    });

    test('the word and its sentence are said', () async {
      final subject = cubit();

      await subject.sayWord();
      await subject.saySentence();

      expect(player.loaded, [
        subject.state.word!.audioUrl,
        subject.state.word!.sentenceAudioUrl,
      ]);
    });

    test('leaving sends what waits', () async {
      await cubit().close();

      expect(practice.sends, 1);
    });

    Future<ReviewCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
      VoidCallback? onExit,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: ReviewPage(onExit: onExit ?? () {}),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await settle(tester);
      return subject;
    }

    testWidgets('the face, then the back, by the button or the card', (
      tester,
    ) async {
      final subject = await pump(tester);
      final word = subject.state.word!;

      expect(said(word.word), findsOneWidget);
      expect(said('practice_tap_meaning'.tr()), findsOneWidget);
      expect(said(word.arabic), findsNothing);

      await tester.tap(said(word.word));
      await settle(tester);

      expect(said(word.arabic), findsOneWidget);
      expect(said('practice_known'.tr()), findsOneWidget);
      expect(said('practice_again'.tr()), findsOneWidget);
      expect(
        said('practice_from'.tr(namedArgs: {'title': word.lessonTitle!})),
        findsOneWidget,
      );
    });

    testWidgets('an answer leaves its line, then the next card', (
      tester,
    ) async {
      final subject = await pump(tester);
      await tester.tap(said('practice_flip'.tr()));
      await settle(tester);

      await tester.tap(said('practice_again'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(said('practice_see_in'.plural(1)), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(subject.state.index, 1);
      expect(said('practice_flip'.tr()), findsOneWidget);
    });

    testWidgets('a word from a video shows its clip, not yet to open', (
      tester,
    ) async {
      final subject = await pump(tester);
      while (subject.state.word?.moment == null) {
        subject.flip();
        await subject.answer(known: true);
        subject.next();
      }
      subject.flip();
      await settle(tester);

      expect(said('practice_watch_clip'.tr()), findsOneWidget);
      expect(said('practice_soon'.tr()), findsOneWidget);
    });

    testWidgets('the end, and «انتهيت»', (tester) async {
      var exits = 0;
      final subject = await pump(tester, onExit: () => exits++);
      while (!subject.state.done) {
        subject.flip();
        await subject.answer(known: true);
        subject.next();
      }
      await settle(tester);

      expect(said('practice_done'.plural(9)), findsOneWidget);
      expect(said('practice_done_up'.plural(9)), findsOneWidget);
      expect(said('practice_done_again'.plural(0)), findsOneWidget);

      await tester.tap(said('practice_finish'.tr()));
      expect(exits, 1);
    });

    testLayouts('face, back and end fit', (tester, layout) async {
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      subject.flip();
      await settle(tester);
      expect(tester.takeException(), isNull);
      while (!subject.state.done) {
        subject.flip();
        await subject.answer(known: false);
        subject.next();
      }
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('my words', () {
    MyWordsCubit cubit() {
      final subject = MyWordsCubit(practice, player, now: () => _today)
        ..start();
      addTearDown(subject.close);
      return subject;
    }

    test('filters and search, in English or Arabic', () {
      final subject = cubit();
      expect(subject.shown, hasLength(12));

      subject.setFilter(WordFilter.due);
      expect(subject.shown, hasLength(9));
      subject.setFilter(WordFilter.learning);
      expect(subject.shown.every((w) => w.box <= 2), isTrue);
      subject.setFilter(WordFilter.firm);
      expect(subject.shown.every((w) => w.box >= 3), isTrue);

      subject
        ..setFilter(WordFilter.all)
        ..search('BA');
      expect(subject.shown.map((w) => w.word), ['barn', 'basket']);
      subject.search('حظيرة');
      expect(subject.shown.single.word, 'barn');

      subject.closeSearch();
      expect(subject.shown, hasLength(12));
    });

    test('removing takes it out at once', () async {
      final subject = cubit();
      final barn = subject.state.words.firstWhere((w) => w.word == 'barn');

      await subject.remove(barn);

      expect(subject.state.words.contains(barn), isFalse);
      expect(practice.removed, [barn.id]);
    });

    Future<MyWordsCubit> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: MyWordsPage(onBack: () {}),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await settle(tester);
      return subject;
    }

    testWidgets('searching takes the title\'s place, and finds nothing too', (
      tester,
    ) async {
      await pump(tester);
      expect(said('practice_my_words'.tr()), findsOneWidget);

      await tester.tap(find.byTooltip('practice_search'.tr()));
      await settle(tester);
      expect(said('practice_my_words'.tr()), findsNothing);

      await tester.enterText(find.byType(TextField), 'ba');
      await settle(tester);
      expect(said('barn'), findsOneWidget);
      expect(said('chicken'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await settle(tester);
      expect(said('practice_no_results'.tr()), findsOneWidget);
    });

    testWidgets('a filter chip narrows the list', (tester) async {
      await pump(tester);

      await tester.tap(said('practice_filter_firm'.tr()));
      await settle(tester);

      expect(said('chicken'), findsNothing);
      expect(said('basket'), findsOneWidget);
    });

    testWidgets('a word\'s sheet, and removing it after asking', (
      tester,
    ) async {
      final subject = await pump(tester);

      await tester.tap(said('barn'));
      await settle(tester);
      expect(said('حظيرة'), findsWidgets);

      await tester.tap(said('practice_delete'.tr()));
      await settle(tester);
      expect(said('practice_delete_body'.tr()), findsOneWidget);

      await tester.tap(said('practice_cancel'.tr()));
      await settle(tester);
      expect(said('practice_delete'.tr()), findsOneWidget);

      await tester.tap(said('practice_delete'.tr()));
      await settle(tester);
      await tester.tap(said('practice_delete_confirm'.tr()));
      await settle(tester);

      expect(practice.removed.single, 'bw_barn');
      expect(subject.state.words.any((w) => w.word == 'barn'), isFalse);
      expect(said('barn'), findsNothing);
    });

    testWidgets('a row says the word', (tester) async {
      await pump(tester);

      await tester.tap(find.byType(SayButton).first);
      await tester.pump();

      expect(player.loaded, isNotEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testLayouts('the list, the search and the sheet fit', (
      tester,
      layout,
    ) async {
      final subject = await pump(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      subject.openSearch();
      await settle(tester);
      expect(tester.takeException(), isNull);
      subject.closeSearch();
      await settle(tester);
      await tester.tap(said('barn'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
