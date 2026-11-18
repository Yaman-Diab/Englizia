import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/downloads/domain/entities/lesson_download.dart';
import 'package:englizia/features/downloads/presentation/downloads/cubit/downloads_cubit.dart';
import 'package:englizia/features/downloads/presentation/downloads/pages/downloads_page.dart';
import 'package:englizia/features/downloads/presentation/downloads/widgets/download_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_downloads.dart';
import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  late FakeDownloadRepository downloads;
  late DownloadsCubit cubit;

  const hello = DownloadRequest(lessonId: 'l1', title: 'Hello');
  const colors = DownloadRequest(lessonId: 'l2', title: 'Colors');

  setUp(() {
    downloads = FakeDownloadRepository();
    cubit = DownloadsCubit(downloads);
  });

  tearDown(() async {
    await cubit.close();
    await downloads.dispose();
  });

  group('the cubit', () {
    test('nothing is shown until downloads are known to be offered', () async {
      downloads.isAvailable = false;
      expect(cubit.state.available, isFalse);
      await cubit.start();
      expect(cubit.state.available, isFalse);
      expect(downloads.tidied, 0);

      // The settings came later: the next screen asks again.
      downloads.isAvailable = true;
      await cubit.start();
      expect(cubit.state.available, isTrue);
      expect(downloads.tidied, 1);

      await cubit.start();
      expect(downloads.tidied, 1);
    });

    test('follows every download, by lesson', () async {
      await cubit.start();
      downloads
        ..set('l1', DownloadStatus.done)
        ..set('l2', DownloadStatus.downloading, received: 500);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.lessons['l1']?.status, DownloadStatus.done);
      expect(cubit.state.lessons['l2']?.progress, .5);
      expect(cubit.state.keptOf(['l1', 'l2', 'l3']), 1);
      expect(cubit.state.anyActive(['l1']), isFalse);
      expect(cubit.state.anyActive(['l2']), isTrue);
    });

    test('Wi-Fi only, the usage and completed lessons', () async {
      await cubit.start();
      await cubit.setWifiOnly(on: false);
      expect((cubit.state.wifiOnly, downloads.wifi), (false, false));

      expect(await cubit.loadUsage(), isNull);
      expect(cubit.state.usage?.lessons, 3);
      downloads.used = const Err(networkDown);
      expect(await cubit.loadUsage(), networkDown);

      await cubit.markDone({'l1'});
      expect(downloads.done, {'l1'});
    });
  });

  /// A change reaches the cubit with one pump and the screen with the next.
  Future<void> shown(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('ar'),
    Size size = defaultViewport,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpLocalized(
      BlocProvider.value(
        value: cubit,
        child: Scaffold(body: Center(child: child)),
      ),
      locale: locale,
      size: size,
      themeMode: themeMode,
    );
    // Inside the test's own clock, so each change reaches the screen with
    // the next pump.
    await cubit.start();
    await shown(tester);
  }

  Finder icon(AppIcon icon) => find.byWidgetPredicate(
    (widget) => widget is AppIconView && widget.icon == icon,
  );

  group('a lesson\'s button', () {
    testWidgets('hidden while downloads aren\'t offered', (tester) async {
      downloads.isAvailable = false;
      await pump(tester, const LessonDownloadButton(request: hello));
      expect(find.byType(InkResponse), findsNothing);
    });

    testWidgets('each state has its own mark, and its own press', (
      tester,
    ) async {
      await pump(tester, const LessonDownloadButton(request: hello));
      final button = find.byType(LessonDownloadButton);

      // Not kept: download.
      expect(icon(AppIcon.download), findsOneWidget);
      expect(
        tester.getSemantics(button).label,
        'downloads_action_download'.tr(namedArgs: {'title': 'Hello'}),
      );
      await tester.tap(button);
      await shown(tester);
      expect(downloads.started.single, [hello]);

      // Waiting its turn, then for Wi-Fi.
      expect(icon(AppIcon.clock), findsOneWidget);
      downloads.set(
        'l1',
        DownloadStatus.queued,
        problem: DownloadProblem.waitingForWifi,
      );
      await shown(tester);
      expect(icon(AppIcon.wifiOff), findsOneWidget);

      // On its way: a ring that fills, and a press stops it.
      downloads.set('l1', DownloadStatus.downloading, received: 250);
      await shown(tester);
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, .25);
      expect(icon(AppIcon.cross), findsOneWidget);
      await tester.tap(button);
      await shown(tester);
      expect(downloads.removed, ['l1']);

      // Cut: its reason is said, and a press tries again.
      downloads.set(
        'l1',
        DownloadStatus.failed,
        problem: DownloadProblem.noRoom,
      );
      await shown(tester);
      expect(icon(AppIcon.alertTriangle), findsOneWidget);
      expect(
        tester.getSemantics(button).value,
        'downloads_problem_no_room'.tr(),
      );
      await tester.tap(button);
      await shown(tester);
      expect(downloads.started, hasLength(2));
    });

    testWidgets('on the phone: removing asks first', (tester) async {
      await pump(tester, const LessonDownloadButton(request: hello));
      downloads.set('l1', DownloadStatus.done);
      await shown(tester);
      expect(icon(AppIcon.checkCircle), findsOneWidget);

      await tester.tap(find.byType(LessonDownloadButton));
      await tester.pumpAndSettle();
      expect(find.text('downloads_remove_title'.tr()), findsOneWidget);
      await tester.tap(find.text('downloads_keep'.tr()));
      await tester.pumpAndSettle();
      expect(downloads.removed, isEmpty);

      await tester.tap(find.byType(LessonDownloadButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('downloads_remove'.tr()));
      await tester.pumpAndSettle();
      expect(downloads.removed, ['l1']);
    });
  });

  group('«نزّل الوحدة»', () {
    const unit = UnitDownloadButton(requests: [hello, colors]);

    testWidgets('says what it takes, then downloads', (tester) async {
      await pump(tester, unit);
      await tester.tap(find.text('downloads_unit_action'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('downloads_confirm_title'.tr()), findsOneWidget);
      expect(
        find.textContaining('downloads_size'.tr(namedArgs: {'size': '12'})),
        findsOneWidget,
      );
      expect(
        find.textContaining('downloads_lessons'.plural(2)),
        findsOneWidget,
      );
      expect(downloads.started, isEmpty);

      await tester.tap(find.text('downloads_confirm_start'.tr()));
      // The button now turns while the lessons come: it never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(downloads.started.single, [hello, colors]);
    });

    testWidgets('what doesn\'t fit isn\'t offered', (tester) async {
      downloads.estimated = Ok(
        DownloadEstimate(
          lessons: 2,
          bytes: 9,
          usage: (downloads.used as Ok<DownloadUsage>).value,
          problem: DownloadProblem.overLimit,
        ),
      );
      await pump(tester, unit);
      await tester.tap(find.text('downloads_unit_action'.tr()));
      await tester.pumpAndSettle();

      expect(find.text('downloads_problem_over_limit'.tr()), findsOneWidget);
      expect(find.text('downloads_confirm_title'.tr()), findsNothing);
    });

    testWidgets('a failure to ask is said', (tester) async {
      downloads.estimated = const Err(networkDown);
      await pump(tester, unit);
      await tester.tap(find.text('downloads_unit_action'.tr()));
      await tester.pumpAndSettle();
      expect(find.text('downloads_confirm_title'.tr()), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('all on the phone: it says so', (tester) async {
      await pump(tester, unit);
      downloads
        ..set('l1', DownloadStatus.done)
        ..set('l2', DownloadStatus.done);
      await shown(tester);

      expect(find.text('downloads_unit_done'.tr()), findsOneWidget);
      expect(find.text('downloads_unit_action'.tr()), findsNothing);
    });

    testWidgets('part of it: how far', (tester) async {
      await pump(tester, unit);
      downloads.set('l1', DownloadStatus.done);
      await shown(tester);
      expect(
        find.text(
          'downloads_unit_progress'.tr(namedArgs: {'done': '1', 'total': '2'}),
        ),
        findsOneWidget,
      );
    });
  });

  group('the downloads\' page', () {
    Future<void> open(
      WidgetTester tester, {
      Locale locale = const Locale('ar'),
      Size size = defaultViewport,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      await tester.pumpLocalized(
        BlocProvider.value(
          value: cubit,
          child: DownloadsPage(onBack: () {}),
        ),
        locale: locale,
        size: size,
        themeMode: themeMode,
      );
      await cubit.start();
      await cubit.loadUsage();
      await shown(tester);
    }

    testWidgets('empty: how to download, and Wi-Fi only', (tester) async {
      await open(tester);
      expect(find.text('downloads_empty_title'.tr()), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await shown(tester);
      expect(downloads.wifi, isFalse);
    });

    testWidgets('the room taken and each lesson, removed after asking', (
      tester,
    ) async {
      await open(tester);
      downloads
        ..set('l1', DownloadStatus.done, title: 'Hello', bytes: 3 * 1024 * 1024)
        ..set('l2', DownloadStatus.downloading, title: 'Colors', received: 500);
      await shown(tester);

      expect(
        find.text(
          'downloads_used'.tr(
            namedArgs: {
              'used': 'downloads_size'.tr(namedArgs: {'size': '120'}),
              'max': 'downloads_size'.tr(namedArgs: {'size': '1024'}),
            },
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Hello'), findsOneWidget);
      // The lesson's own line, and the group's title over it.
      expect(find.textContaining('downloads_status_done'.tr()), findsWidgets);

      // One still on its way stops at once.
      await tester.tap(find.text('Colors'));
      await tester.pumpAndSettle();
      expect(downloads.removed, ['l2']);

      await tester.tap(find.text('Hello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('downloads_remove'.tr()));
      await tester.pumpAndSettle();
      expect(downloads.removed, ['l2', 'l1']);
    });

    testWidgets('everything at once, after asking', (tester) async {
      await open(tester);
      downloads.set('l1', DownloadStatus.done);
      await shown(tester);

      await tester.tap(find.text('downloads_remove_all'.tr()));
      await tester.pumpAndSettle();
      expect(find.text('downloads_remove_all_title'.tr()), findsOneWidget);
      await tester.tap(find.text('downloads_remove'.tr()));
      await tester.pumpAndSettle();
      expect(downloads.removedAll, 1);
    });

    testLayouts('it fits', (tester, layout) async {
      await open(
        tester,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      expect(tester.takeException(), isNull);
      downloads
        ..set(
          'l1',
          DownloadStatus.done,
          title: 'The breakable box and what was found inside it',
          bytes: 48 * 1024 * 1024,
        )
        ..set(
          'l2',
          DownloadStatus.failed,
          title: 'Colors',
          problem: DownloadProblem.overLimit,
        )
        ..set('l3', DownloadStatus.downloading, received: 400);
      await shown(tester);
      expect(tester.takeException(), isNull);
    });
  });

  testLayouts('the unit\'s parts fit', (tester, layout) async {
    await pump(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UnitDownloadButton(requests: [hello, colors]),
          LessonDownloadButton(request: hello),
        ],
      ),
      locale: layout.locale,
      size: layout.size,
      themeMode: layout.themeMode,
    );
    downloads.set('l1', DownloadStatus.downloading, received: 300);
    await shown(tester);
    expect(tester.takeException(), isNull);
  });

  test('sizes: one decimal under ten megabytes, none above', () {
    expect(downloadSize(500), 'downloads_size_small'.tr());
    expect(
      downloadSize((2.5 * 1024 * 1024).round()),
      'downloads_size'.tr(namedArgs: {'size': '2.5'}),
    );
    expect(
      downloadSize(48 * 1024 * 1024),
      'downloads_size'.tr(namedArgs: {'size': '48'}),
    );
  });
}
