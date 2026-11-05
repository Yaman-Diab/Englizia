import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/home/presentation/home/widgets/sheets/locked_unit_sheet.dart';
import 'package:englizia/features/home/presentation/home/widgets/sheets/page_search_sheet.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/me/widgets/me_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_track_repository.dart';
import '../../helpers/pump_app.dart';

/// Counts the reads of «أنا»'s first view of the day, which home must not
/// spend.
class _Profiles extends FakeProfileRepository {
  _Profiles(super.profile);

  int firstViews = 0;

  @override
  bool firstViewOn(DateTime day) {
    firstViews++;
    return super.firstViewOn(day);
  }
}

/// Home's sheets: the locked unit's preview, Emar's page
/// search, the flame's sheet with its way to «أنا», and «مساراتك» from home.
void main() {
  setUpAll(initLocalizationForTests);

  final today = DateTime(2026, 11, 5, 10);

  /// A screen whose button runs [open]; what each sheet returned is kept.
  Future<List<Object?>> host(
    WidgetTester tester,
    Future<Object?> Function(BuildContext context) open, {
    Locale locale = const Locale('ar'),
    Size size = defaultViewport,
    ThemeMode themeMode = ThemeMode.light,
    Widget Function(Widget child)? wrap,
  }) async {
    final results = <Object?>[];
    final screen = Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async => results.add(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpLocalized(
      wrap?.call(screen) ?? screen,
      locale: locale,
      size: size,
      themeMode: themeMode,
    );
    return results;
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Finder button(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(FilledButton));

  Finder liveRegion(Finder of) => find.ancestor(
    of: of,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && (widget.properties.liveRegion ?? false),
    ),
  );

  group('the locked unit\'s preview', () {
    final home = mockHome(now: today);
    final market = home.units[3];
    final current = home.currentUnit!;

    Future<List<Object?>> pump(
      WidgetTester tester, {
      HomeUnit? unit,
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) => host(
      tester,
      (context) =>
          showLockedUnitSheet(context, unit: unit ?? market, current: current),
      locale: locale,
      size: size,
      themeMode: themeMode,
    );

    testWidgets('what it teaches, its first five lessons, the unit before', (
      tester,
    ) async {
      await pump(tester);
      await openSheet(tester);

      expect(find.text('معاينة'), findsOneWidget);
      expect(find.text('الوحدة 4 · في السوق'), findsOneWidget);
      expect(
        find.text('ستتعلّم أن تسأل عن الأسعار وتشتري ما تحتاجه'),
        findsOneWidget,
      );
      expect(find.text('6 دروس · نحو 40 دقيقة'), findsOneWidget);
      for (final lesson in market.preview!.lessons.take(5)) {
        expect(find.text(lesson.title), findsOneWidget);
      }
      expect(find.text(market.preview!.lessons.last.title), findsNothing);
      expect(find.text('اعرض محتوى الوحدة'), findsOneWidget);
      expect(find.text('أكمل الوحدة 3 لتفتح هذه الوحدة'), findsOneWidget);
      expect(liveRegion(find.text('أكمل الوحدة 3 لتفتح هذه الوحدة')), findsOne);
      expect(button('اذهب إلى الوحدة 3'), findsOneWidget);
      expect(
        find.bySemanticsLabel('معاينة الوحدة 4، في السوق، مقفلة'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('«اذهب إلى الوحدة 3» and the link each close it with theirs', (
      tester,
    ) async {
      final results = await pump(tester);

      await openSheet(tester);
      await tester.tap(find.text('اذهب إلى الوحدة 3'));
      await settle(tester);
      expect(find.text('الوحدة 4 · في السوق'), findsNothing);

      await openSheet(tester);
      final link = find.ancestor(
        of: find.text('اعرض محتوى الوحدة'),
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
      await tester.tap(link);
      await settle(tester);

      await openSheet(tester);
      await tester.tapAt(const Offset(20, 20));
      await settle(tester);

      expect(results, [
        LockedSheetAction.goToCurrent,
        LockedSheetAction.openUnit,
        null,
      ]);
    });

    testWidgets('without a preview: the unit, its way in and the way back', (
      tester,
    ) async {
      await pump(
        tester,
        unit: const HomeUnit(
          id: 'unit_x',
          number: 6,
          title: 'unit',
          status: UnitLessonStatus.locked,
        ),
      );
      await openSheet(tester);

      expect(find.text('الوحدة 6 · unit'), findsOneWidget);
      expect(find.text('أكمل الوحدة 5 لتفتح هذه الوحدة'), findsOneWidget);
      expect(find.textContaining('ستتعلّم'), findsNothing);
      expect(button('اذهب إلى الوحدة 3'), findsOneWidget);
    });

    testWidgets('in English', (tester) async {
      await pump(tester, locale: const Locale('en'));
      await openSheet(tester);

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('6 lessons · about 40 minutes'), findsOneWidget);
      expect(find.text('Finish unit 3 to open this unit'), findsOneWidget);
      expect(find.text('Go to unit 3'), findsOneWidget);
    });
  });

  group('the page search', () {
    final home = mockHome(emar: true, now: today);

    Future<List<Object?>> pump(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) => host(
      tester,
      (context) => showPageSearchSheet(context, home: home),
      locale: locale,
      size: size,
      themeMode: themeMode,
    );

    VoidCallback? go(WidgetTester tester) =>
        tester.widget<FilledButton>(button('اذهب')).onPressed;

    testWidgets('empty: the book\'s range, and «اذهب» waits for a page', (
      tester,
    ) async {
      await pump(tester);
      await openSheet(tester);

      expect(find.text('ابحث برقم الصفحة'), findsOneWidget);
      expect(find.text('كتاب الطالب، الصف السابع'), findsOneWidget);
      expect(find.text('رقم الصفحة'), findsOneWidget);
      expect(find.text('مثلًا 34'), findsOneWidget);
      expect(find.text('اكتب رقم صفحة من 6 إلى 77'), findsOneWidget);
      expect(liveRegion(find.text('اكتب رقم صفحة من 6 إلى 77')), findsOne);
      final field = tester.getSemantics(find.byType(TextField));
      expect(field.label, 'رقم الصفحة\nمثلًا 34');
      expect(field.getSemanticsData().flagsCollection.isTextField, isTrue);
      expect(tester.getSize(find.byType(TextField)).height, 56);
      expect(go(tester), isNull);
    });

    testWidgets('a lesson of the current unit, then another unit', (
      tester,
    ) async {
      final results = await pump(tester);
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), '39');
      await tester.pump();
      expect(find.text('ص 39 · الصندوق القابل للكسر، الدرس 5'), findsOneWidget);
      expect(go(tester), isNotNull);
      await tester.tap(find.text('اذهب'));
      await settle(tester);

      await openSheet(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), '٤٥');
      await tester.pump();
      expect(find.text('ص 45 · الوحدة 4، في السوق'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await settle(tester);

      expect(results, [const PageHit.lesson(2, 4), const PageHit.unit(3)]);
    });

    testWidgets('a page the book hasn\'t; only three digits are kept', (
      tester,
    ) async {
      final results = await pump(tester);
      await openSheet(tester);

      for (final typed in ['100', '0']) {
        await tester.enterText(find.byType(TextField), typed);
        await tester.pump();
        expect(
          find.text('لا توجد هذه الصفحة في كتاب الصف السابع'),
          findsOneWidget,
        );
        expect(go(tester), isNull);
      }

      await tester.enterText(find.byType(TextField), 'a1b2c3d4');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '123',
      );
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await settle(tester);
      expect(find.text('ابحث برقم الصفحة'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('اكتب رقم صفحة من 6 إلى 77'), findsOneWidget);
      expect(results, isEmpty);
    });

    testWidgets('in English', (tester) async {
      await pump(tester, locale: const Locale('en'));
      await openSheet(tester);

      expect(find.text('Type a page from 6 to 77'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '30');
      await tester.pump();
      expect(
        find.text('p. 30 · ${home.units[2].lessons.first.title}, lesson 1'),
        findsOneWidget,
      );
    });
  });

  group('the flame\'s sheet', () {
    final profile = mockProfile(now: today);

    testWidgets('from home: «هذا الأسبوع في «أنا»» closes it, then goes', (
      tester,
    ) async {
      final home = mockHome(now: today);
      var toMe = 0;
      await host(
        tester,
        (context) => showStreakSheetOf(
          context,
          streak: home.streak!,
          week: home.week,
          onWeekInMe: () => toMe++,
        ),
      );
      await openSheet(tester);

      expect(find.text('me_streak_count'.plural(7)), findsOneWidget);
      final link = find.ancestor(
        of: find.text('هذا الأسبوع في «أنا»'),
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
      await tester.tap(link);
      await settle(tester);

      expect(find.text('me_got_it'.tr()), findsNothing);
      expect(toMe, 1);
    });

    testWidgets('from «أنا»: no link', (tester) async {
      await host(tester, (context) => showStreakSheet(context, profile));
      await openSheet(tester);

      expect(find.text('me_got_it'.tr()), findsOneWidget);
      expect(find.text('هذا الأسبوع في «أنا»'), findsNothing);
    });
  });

  group('«مساراتك» from home', () {
    late _Profiles profiles;

    MeCubit cubit() {
      final subject = MeCubit(
        profiles,
        FakeTrackRepository(tracks: [Ok(mockPublishedTracks())]),
        isGuest: () => false,
        now: () => today,
      );
      addTearDown(subject.close);
      return subject;
    }

    setUp(() => profiles = _Profiles(mockProfile(now: today)));

    test(
      'the kept profile at once, then the server\'s; the day unspent',
      () async {
        profiles.kept = mockProfile(now: today).copyWith(name: 'Kept');
        final subject = cubit();
        final names = <String?>[];
        final listening = subject.stream.listen(
          (s) => names.add(s.profile?.name),
        );
        addTearDown(listening.cancel);

        await subject.openTracks();

        expect(names.first, 'Kept');
        expect(subject.state.load, LoadStatus.ready);
        expect(subject.state.profile?.name, profiles.profile.name);
        expect(subject.state.firstView, isFalse);
        expect(profiles.firstViews, 0);
      },
    );

    test('nothing kept: the server\'s; loaded already: refreshed', () async {
      final subject = cubit();

      await subject.openTracks();
      expect(subject.state.profile, profiles.profile);

      profiles.profile = profiles.profile.copyWith(name: 'Later');
      await subject.openTracks();
      expect(subject.state.profile?.name, 'Later');
      expect(profiles.firstViews, 0);
    });

    testWidgets('the sheet lists the tracks of a cubit home made', (
      tester,
    ) async {
      final subject = cubit();
      final results = await host(tester, (context) {
        context.read<MeCubit>().openTracks();
        return showTracksSheet(context, onJoin: (_) {});
      }, wrap: (child) => BlocProvider.value(value: subject, child: child));
      await openSheet(tester);

      expect(find.text('مساراتك'), findsOneWidget);
      await tester.tap(find.text('منهاج إيمار'));
      await settle(tester);

      expect((results.single! as ProfileTrack).enrollmentId, 'enr_emar');
    });
  });

  testLayouts('every sheet fits', (tester, layout) async {
    final home = mockHome(now: today);
    final emar = mockHome(emar: true, now: today);
    final opens = <Future<Object?> Function(BuildContext)>[
      (context) => showLockedUnitSheet(
        context,
        unit: home.units[3],
        current: home.currentUnit!,
      ),
      (context) => showPageSearchSheet(context, home: emar),
      (context) => showStreakSheetOf(
        context,
        streak: home.streak!,
        week: home.week,
        onWeekInMe: () {},
      ),
    ];
    for (final open in opens) {
      await host(
        tester,
        open,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await openSheet(tester);
      if (find.byType(TextField).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), '39');
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
    }
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
