import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/lessons/data/datasources/unit_remote_data_source.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/lessons/presentation/unit/cubit/unit_cubit.dart';
import 'package:englizia/features/lessons/presentation/unit/pages/unit_page.dart';
import 'package:englizia/features/lessons/presentation/unit/widgets/kid_unit_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_lesson_repository.dart';
import '../../../helpers/fake_unit_repository.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  late FakeUnitRepository units;
  late FakeLessonRepository lessons;
  late FakeConnectivityService connectivity;
  late FakeClipPlayer player;

  setUp(() {
    units = FakeUnitRepository(mockUnit(UnitFakeDataSource.farm));
    lessons = FakeLessonRepository();
    connectivity = FakeConnectivityService();
    player = FakeClipPlayer(length: const Duration(milliseconds: 300));
  });

  UnitCubit cubit([String unitId = UnitFakeDataSource.farm]) {
    final subject = UnitCubit(
      units,
      lessons,
      connectivity,
      player,
      unitId: unitId,
    );
    addTearDown(subject.close);
    return subject;
  }

  group('the cubit', () {
    test('the unit with what the phone knows; goals open once', () async {
      lessons.phone['les_it'] = const LessonOnPhone(
        kept: true,
        resume: LessonResume(question: 3, share: .4),
      );
      final first = cubit();
      await first.start();

      expect(first.state.load, LoadStatus.ready);
      expect(first.state.goalsOpen, isTrue);
      expect(first.state.plan!.lessons[3].resume?.question, 3);
      expect(units.seen, {UnitFakeDataSource.farm});

      final again = cubit();
      await again.start();
      expect(again.state.goalsOpen, isFalse);
    });

    test('back from a lesson done: it settles, then the chain moves', () async {
      final subject = cubit();
      await subject.start();
      expect(subject.state.plan!.current, 3);

      lessons.phone['les_it'] = const LessonOnPhone(done: true);
      await subject.returned();

      expect(subject.state.settling, 'les_it');
      expect(subject.state.plan!.doneCount, 4);
      expect(subject.state.status(4), UnitLessonStatus.locked);
      subject.settled();
      expect(subject.state.status(4), UnitLessonStatus.current);
    });

    test('offline: only what is kept opens', () async {
      connectivity.online = false;
      lessons.phone['les_it'] = const LessonOnPhone(kept: true);
      final subject = cubit();
      await subject.start();

      expect(subject.state.online, isFalse);
      final plan = subject.state.plan!;
      expect(subject.state.available(plan.lessons[3]), isTrue);
      expect(subject.state.available(plan.lessons[4]), isFalse);

      connectivity.online = true;
      await Future<void>.delayed(Duration.zero);
      expect(subject.state.online, isTrue);
    });

    test('nothing kept and no server: the failure', () async {
      units.failure = const NetworkFailure();
      final subject = cubit();
      await subject.start();
      expect(subject.state.load, LoadStatus.failure);
    });

    test('kids: the guide says the unit, a card its lesson', () async {
      units.unit = mockUnit(UnitFakeDataSource.kids);
      final subject = cubit(UnitFakeDataSource.kids);
      await subject.start();
      await Future<void>.delayed(Duration.zero);

      expect(player.loaded.first, units.unit.titleAudioUrl);
      expect(subject.state.speaking, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(subject.state.speaking, isFalse);

      await subject.sayLesson(units.unit.lessons.first);
      expect(player.loaded.last, units.unit.lessons.first.audioUrl);
    });
  });

  group('the page', () {
    late List<(String, bool)> opened;
    late List<String> unitsOpened;

    Future<UnitCubit> pump(
      WidgetTester tester, {
      String unitId = UnitFakeDataSource.farm,
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      opened = [];
      unitsOpened = [];
      units.unit = mockUnit(unitId);
      final subject = cubit(unitId);
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: UnitPage(
            onBack: () {},
            onOpen: (lesson, {required kids}) => opened.add((lesson.id, kids)),
            onUnit: (unit) => unitsOpened.add(unit.id),
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

    testWidgets('the header, the timeline and «ابدأ»', (tester) async {
      final subject = await pump(tester);

      expect(find.text('يوم في المزرعة'), findsWidgets);
      expect(find.text('unit_number'.tr(args: ['3'])), findsOneWidget);
      expect(find.text('ستتعلّم أن…'), findsOneWidget);
      expect(find.text('تصف يومًا في الريف'), findsOneWidget);
      expect(find.text('المضارع البسيط'), findsWidgets);
      expect(find.text('unit_redo'.tr()), findsNWidgets(3));
      expect(find.text('unit_review_after'.tr()), findsOneWidget);

      // It opened scrolled to the current lesson.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
      await settle(tester);
      await tester.tap(find.text('ستتعلّم أن…'));
      await settle(tester);
      expect(subject.state.goalsOpen, isFalse);
      expect(find.text('تصف يومًا في الريف'), findsNothing);

      await tester.ensureVisible(find.text('unit_start'.tr()));
      await tester.tap(find.text('unit_start'.tr()));
      expect(opened, [('les_it', false)]);
      await tester.tap(find.text('unit_redo'.tr()).first);
      expect(opened.last, ('les_voc', false));
    });

    testWidgets('a lesson left half way: «تابع» and where it stopped', (
      tester,
    ) async {
      lessons.phone['les_it'] = const LessonOnPhone(
        kept: true,
        resume: LessonResume(question: 3, share: .4),
      );
      await pump(tester);

      expect(find.text('unit_continue'.tr()), findsOneWidget);
      expect(find.text('unit_stopped_at'.tr(args: ['3'])), findsOneWidget);
    });

    testWidgets('done: the chain fills, then the next card opens', (
      tester,
    ) async {
      final subject = await pump(tester);
      lessons.phone['les_it'] = const LessonOnPhone(done: true);
      await subject.returned();
      await tester.pump();
      expect(find.text('unit_start'.tr()), findsNothing);

      await settle(tester);
      expect(subject.state.settling, isNull);
      expect(find.text('unit_start'.tr()), findsOneWidget);
      await tester.tap(find.text('unit_start'.tr()));
      expect(opened.last.$1, 'les_chat_box');
    });

    testWidgets('complete: the next unit', (tester) async {
      for (final id in ['les_it', 'les_chat_box', 'les_mock']) {
        lessons.phone[id] = const LessonOnPhone(done: true);
      }
      await pump(tester);

      expect(find.text('unit_done'.tr(args: ['3'])), findsOneWidget);
      await tester.tap(find.text('unit_next'.tr(args: ['في السوق'])));
      expect(unitsOpened, [UnitFakeDataSource.market]);
    });

    testWidgets('locked: a preview, and the unit to finish first', (
      tester,
    ) async {
      await pump(tester, unitId: UnitFakeDataSource.market);

      expect(find.text('unit_locked'.tr(args: ['3'])), findsOneWidget);
      expect(find.text('unit_start'.tr()), findsNothing);
      await tester.tap(find.text('unit_go_to'.tr(args: ['3'])));
      expect(unitsOpened, [UnitFakeDataSource.farm]);
    });

    testWidgets('Emar: the pages, and every lesson open', (tester) async {
      await pump(tester, unitId: UnitFakeDataSource.emar);

      expect(
        find.text('unit_book_pages'.tr(namedArgs: {'from': '30', 'to': '41'})),
        findsOneWidget,
      );
      expect(find.text('unit_page'.tr(args: ['36'])), findsOneWidget);
      final open = find.byTooltip('unit_start'.tr());
      expect(open, findsNWidgets(2));
      await tester.ensureVisible(open.first);
      await tester.tap(open.first);
      expect(opened, [('les_it', false)]);
    });

    testWidgets('kids: picture cards; a locked one only says its name', (
      tester,
    ) async {
      await pump(tester, unitId: UnitFakeDataSource.kids);

      expect(find.byType(KidUnitGrid), findsOneWidget);
      expect(find.text('ستتعلّم أن…'), findsNothing);
      await tester.ensureVisible(find.text('Eggs'));
      await tester.tap(find.text('Eggs'));
      expect(opened, [('les_kid_eggs', true)]);
      await tester.ensureVisible(find.text('Play'));
      await tester.tap(find.text('Play'));
      expect(opened, hasLength(1));
      expect(player.loaded.last, endsWith('dog_title.mp3'));
      await settle(tester);
    });

    testWidgets('offline: the band, and the lessons not kept dimmed', (
      tester,
    ) async {
      connectivity.online = false;
      await pump(tester);

      expect(find.text('unit_offline'.tr()), findsOneWidget);
      await tester.ensureVisible(find.text('unit_start'.tr()));
      await tester.tap(find.text('unit_start'.tr()));
      expect(opened, isEmpty, reason: 'not kept on the phone');
    });

    testWidgets('loading shows the shape of the screen', (tester) async {
      units.failure = const NetworkFailure();
      final subject = cubit();
      await tester.pumpLocalized(
        BlocProvider.value(
          value: subject,
          child: UnitPage(
            onBack: () {},
            onOpen: (_, {required kids}) {},
            onUnit: (_) {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('common_loading'.tr()), findsOneWidget);
      await subject.start();
      await settle(tester);
      expect(find.text('common_retry'.tr()), findsOneWidget);
    });

    testLayouts('every kind of unit fits', (tester, layout) async {
      for (final id in UnitFakeDataSource.units) {
        await pump(
          tester,
          unitId: id,
          locale: layout.locale,
          size: layout.size,
          themeMode: layout.themeMode,
        );
        expect(tester.takeException(), isNull, reason: id);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: id);
      }
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
