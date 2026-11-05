import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/connection_strip.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/home_no_data.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/home_skeleton.dart';
import 'package:englizia/features/home/presentation/home/widgets/states/switch_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Home's states without a map (header §8, §10): the skeleton, nothing to
/// show, the connection strips and the track-switched strip.
void main() {
  setUpAll(initLocalizationForTests);

  /// The stage below a 56 top bar, as the page lays it out.
  Widget stage(Widget child) => Scaffold(
    body: Column(
      children: [
        const SizedBox(height: 56),
        Expanded(child: child),
      ],
    ),
  );

  /// The header's top slot: the header's padding 20 less the design's −4.
  Widget slot(Widget strip) => Scaffold(
    body: Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Column(children: [strip]),
    ),
  );

  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  group('HomeSkeleton', () {
    Finder sheen() => find.descendant(
      of: find.byType(HomeSkeleton),
      matching: find.byType(FractionalTranslation),
    );
    double sheenX(WidgetTester tester) =>
        tester.widget<FractionalTranslation>(sheen()).translation.dx;

    Finder ring() => find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).border != null,
    );

    testWidgets('says it loads, and its shapes stay silent', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpLocalized(stage(const HomeSkeleton()));

      final label = find.bySemanticsLabel('home_loading'.tr());
      expect(label, findsOneWidget);
      final node = tester.getSemantics(label);
      expect(node, isSemantics(isLiveRegion: true));
      expect(node.childrenCount, 0);
      semantics.dispose();
    });

    testWidgets('lays out the design\'s shapes, mirrored in English', (
      tester,
    ) async {
      for (final locale in AppLocales.supported) {
        await tester.pumpLocalized(stage(const HomeSkeleton()), locale: locale);
        final origin = tester.getTopLeft(find.byType(HomeSkeleton));
        final width = tester.getSize(find.byType(HomeSkeleton)).width;
        final rect = tester.getRect(ring()).shift(-origin);
        expect(rect.size, const Size(96, 96));
        expect(rect.top, 0);
        // The ring is at the end: left 20 in Arabic, right 20 in English.
        expect(
          locale == AppLocales.arabic ? rect.left : width - rect.right,
          20,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the sheen sweeps from −120% to 220% and loops', (
      tester,
    ) async {
      await tester.pumpLocalized(stage(const HomeSkeleton()));
      expect(sheenX(tester), closeTo(-1.2, 1e-9));

      await tester.pump(AppMotion.homeShimmer ~/ 2);
      // Halfway through the ease-in-out: halfway across.
      expect(sheenX(tester), closeTo(.5, 1e-6));

      // Past the end it starts over.
      await tester.pump(
        AppMotion.homeShimmer ~/ 2 + const Duration(milliseconds: 1),
      );
      expect(sheenX(tester), lessThan(-1.1));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('in English the sheen runs the other way', (tester) async {
      await tester.pumpLocalized(
        stage(const HomeSkeleton()),
        locale: AppLocales.english,
      );
      expect(sheenX(tester), closeTo(1.2, 1e-9));
      await tester.pump(AppMotion.homeShimmer ~/ 4);
      expect(sheenX(tester), lessThan(1.2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rests where the design draws it under reduce motion', (
      tester,
    ) async {
      reduceMotion(tester);
      await tester.pumpLocalized(stage(const HomeSkeleton()));
      expect(sheenX(tester), closeTo(.4, 1e-9));
      await tester.pump(AppMotion.homeShimmer);
      expect(sheenX(tester), closeTo(.4, 1e-9));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('HomeNoData', () {
    Future<void> pumpNoData(
      WidgetTester tester,
      Failure failure, {
      VoidCallback? onRetry,
    }) => tester.pumpLocalized(
      stage(HomeNoData(failure: failure, onRetry: onRetry ?? () {})),
    );

    testWidgets('a lost connection asks for one, and retries', (tester) async {
      final semantics = tester.ensureSemantics();
      var retries = 0;
      await pumpNoData(
        tester,
        const NetworkFailure(),
        onRetry: () => retries++,
      );

      final heading = find.text('home_no_data'.tr());
      expect(heading, findsOneWidget);
      expect(tester.getSemantics(heading), isSemantics(isHeader: true));
      // The guide is decoration.
      expect(find.bySemanticsLabel('mascot_name'.tr()), findsNothing);

      await tester.tap(find.text('common_retry'.tr()));
      expect(retries, 1);
      semantics.dispose();
    });

    testWidgets('another failure says what went wrong', (tester) async {
      const failure = ServerFailure(statusCode: 500);
      await pumpNoData(tester, failure);
      expect(find.text(failure.localizedMessage), findsOneWidget);
      expect(find.text('home_no_data'.tr()), findsNothing);
    });

    testWidgets('a 52 pill on the general sea, without error colours', (
      tester,
    ) async {
      await pumpNoData(tester, const NetworkFailure());
      final button = find.byType(FilledButton);
      expect(tester.getSize(button).height, 52);

      final context = tester.element(find.byType(HomeNoData));
      final material = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)),
      );
      expect(material.color, context.colors.primaryStrong);
      expect(material.shape, isA<StadiumBorder>());

      final sea = SeaPalette.of(context);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(HomeNoData),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final gradient =
          (box.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, [sea.general, sea.seaBottom(sea.general)]);
    });

    testWidgets('large text scrolls instead of overflowing', (tester) async {
      await tester.pumpLocalized(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: stage(
            HomeNoData(failure: const NetworkFailure(), onRetry: () {}),
          ),
        ),
        size: narrowViewport,
        locale: AppLocales.english,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ConnectionStrip', () {
    Finder drawn(WidgetTester tester, Color color) => find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == color,
    );

    testWidgets('offline: a polite live region filling the 52 slot', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpLocalized(slot(const ConnectionStrip.offline()));

      final text = find.text('home_offline'.tr());
      expect(text, findsOneWidget);
      expect(
        tester.getSemantics(text),
        isSemantics(isLiveRegion: true, label: 'home_offline'.tr()),
      );
      expect(tester.takeAnnouncements(), isEmpty);

      final strip = find.byType(ConnectionStrip);
      expect(tester.getSize(strip).height, ConnectionStrip.slotHeight);
      final context = tester.element(strip);
      final box = tester.getRect(drawn(tester, context.colors.info.surface));
      // 4 above the 40 strip, 8 under it.
      expect(box.height, 40);
      expect(box.top - tester.getTopLeft(strip).dy, 4);
      expect(tester.getBottomLeft(strip).dy - box.bottom, 8);
      expect(find.byType(TextButton), findsNothing);
      semantics.dispose();
    });

    testWidgets('failed: said at once, and «إعادة» retries', (tester) async {
      final semantics = tester.ensureSemantics();
      var retries = 0;
      await tester.pumpLocalized(
        slot(ConnectionStrip.failed(onRetry: () => retries++)),
      );

      expect(find.text('home_refresh_failed'.tr()), findsOneWidget);
      expect(
        tester.takeAnnouncements(),
        contains(
          isAccessibilityAnnouncement(
            'home_refresh_failed'.tr(),
            assertiveness: Assertiveness.assertive,
          ),
        ),
      );

      final context = tester.element(find.byType(ConnectionStrip));
      expect(
        tester.getSize(drawn(tester, context.colors.error.surface)).height,
        40,
      );

      await tester.tap(find.text('home_refresh_retry'.tr()));
      expect(retries, 1);
      semantics.dispose();
    });

    testWidgets('«إعادة» is drawn 40 high with a 48 target', (tester) async {
      await tester.pumpLocalized(slot(ConnectionStrip.failed(onRetry: () {})));
      final button = find.byType(TextButton);
      expect(tester.getSize(button).height, 48);
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      final ink = find.descendant(of: button, matching: find.byType(Material));
      expect(tester.getSize(ink).height, 40);
    });

    testWidgets('a long line wraps and the strip grows', (tester) async {
      await tester.pumpLocalized(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: slot(ConnectionStrip.failed(onRetry: () {})),
        ),
        size: narrowViewport,
        locale: AppLocales.english,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ConnectionStrip)).height,
        greaterThan(ConnectionStrip.slotHeight),
      );
    });
  });

  group('SwitchStrip', () {
    Widget host(String? title) => Scaffold(
      body: Stack(children: [SwitchStrip(title: title)]),
    );
    Finder strip() => find.descendant(
      of: find.byType(SwitchStrip),
      matching: find.byType(Container),
    );

    testWidgets('null shows nothing', (tester) async {
      await tester.pumpLocalized(host(null));
      expect(
        find.descendant(
          of: find.byType(SwitchStrip),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('says where you moved, politely', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpLocalized(host('منهاج إيمار'));
      final text = find.text('انتقلت إلى منهاج إيمار');
      expect(text, findsOneWidget);
      expect(tester.getSemantics(text), isSemantics(isLiveRegion: true));
      semantics.dispose();
    });

    testWidgets('8 under the top bar, 16 from the edges, 48 high, inverse', (
      tester,
    ) async {
      for (final locale in AppLocales.supported) {
        await tester.pumpLocalized(host('Emar'), locale: locale);
        final rect = tester.getRect(strip());
        expect(rect.top, 64);
        expect(rect.height, 48);
        expect(rect.left, 16);
        expect(rect.right, defaultViewport.width - 16);

        final context = tester.element(strip());
        final box = tester.widget<Container>(strip()).decoration!;
        expect((box as BoxDecoration).color, context.colors.textPrimary);
        expect(
          tester.widget<Text>(find.textContaining('Emar')).style?.color,
          context.colors.background,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('fades away when the title goes', (tester) async {
      await tester.pumpLocalized(host('Emar'));
      await tester.pumpLocalized(host(null));
      expect(find.textContaining('Emar'), findsOneWidget);
      await tester.pump(AppMotion.quick + const Duration(milliseconds: 1));
      expect(find.textContaining('Emar'), findsNothing);
    });
  });

  testLayouts('every state fits', (tester, layout) async {
    Future<void> show(Widget child) async {
      await tester.pumpLocalized(
        child,
        locale: layout.locale,
        size: layout.size,
        themeMode: layout.themeMode,
      );
      await tester.pump(AppMotion.homeShimmer ~/ 3);
      expect(tester.takeException(), isNull);
    }

    await show(
      Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 56),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      const ConnectionStrip.offline(),
                      ConnectionStrip.failed(onRetry: () {}),
                    ],
                  ),
                ),
                const Expanded(child: HomeSkeleton()),
              ],
            ),
            const SwitchStrip(title: 'Emar'),
          ],
        ),
      ),
    );
    await show(
      stage(HomeNoData(failure: const NetworkFailure(), onRetry: () {})),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
