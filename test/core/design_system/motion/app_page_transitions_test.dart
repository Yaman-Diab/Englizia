import 'dart:async';

import 'package:englizia/core/design_system/app_theme.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/app_page_transitions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pageKey = Key('pushed-page');
  final halfway = Duration(microseconds: AppMotion.fast.inMicroseconds ~/ 2);

  /// A navigator themed with [AppTheme.pageTransitionsTheme]; the platform
  /// comes from the test (Android by default, iOS under a variant).
  Future<GlobalKey<NavigatorState>> pumpHost(
    WidgetTester tester, {
    TextDirection direction = TextDirection.ltr,
  }) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: ThemeData(pageTransitionsTheme: AppTheme.pageTransitionsTheme),
        builder: (context, child) =>
            Directionality(textDirection: direction, child: child!),
        home: const Scaffold(),
      ),
    );
    return navigator;
  }

  /// Pushes a page and pumps until it is on screen at the start of its
  /// transition: the first frame after a push builds the page offstage (for
  /// Hero measurement), the second shows it with no time elapsed.
  Future<MaterialPageRoute<void>> pushPage(
    WidgetTester tester,
    GlobalKey<NavigatorState> navigator,
  ) async {
    final route = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(key: pageKey),
    );
    unawaited(navigator.currentState!.push(route));
    await tester.pump();
    await tester.pump();
    return route;
  }

  double pageOffset(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(pageKey)).dx;

  double pageOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(pageKey),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  group('Android', () {
    testWidgets('runs AppMotion.fast both ways', (tester) async {
      final navigator = await pumpHost(tester);
      final route = await pushPage(tester, navigator);

      expect(route.transitionDuration, AppMotion.fast);
      expect(route.reverseTransitionDuration, AppMotion.fast);
      await tester.pump(AppMotion.fast - const Duration(milliseconds: 1));
      expect(route.animation!.status, AnimationStatus.forward);
      // An AnimationController completes only once elapsed time exceeds it.
      await tester.pump(const Duration(milliseconds: 2));
      expect(route.animation!.status, AnimationStatus.completed);
    });

    for (final (direction, sign) in [
      (TextDirection.ltr, 1.0),
      (TextDirection.rtl, -1.0),
    ]) {
      testWidgets('${direction.name}: enters from the end side', (
        tester,
      ) async {
        final navigator = await pumpHost(tester, direction: direction);
        await pushPage(tester, navigator);

        expect(pageOffset(tester), sign * AppMotion.distanceLarge);
        expect(pageOpacity(tester), 0);

        // Halfway in time, the page follows AppMotion.smoothOut exactly.
        await tester.pump(halfway);
        final eased = AppMotion.smoothOut.transform(0.5);
        expect(pageOpacity(tester), moreOrLessEquals(eased, epsilon: 1e-6));
        expect(
          pageOffset(tester),
          moreOrLessEquals(
            sign * AppMotion.distanceLarge * (1 - eased),
            epsilon: 1e-3,
          ),
        );

        await tester.pumpAndSettle();
        expect(pageOffset(tester), 0);
      });

      testWidgets('${direction.name}: leaves toward the end side on pop', (
        tester,
      ) async {
        final navigator = await pumpHost(tester, direction: direction);
        await pushPage(tester, navigator);
        await tester.pumpAndSettle();

        // Leaving uses the flipped curve, so most of the fade and slide
        // happens early: halfway in time the page is nearly gone.
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(halfway);
        final eased = AppMotion.smoothOut.flipped.transform(0.5);
        expect(eased, lessThan(0.1));
        expect(pageOpacity(tester), moreOrLessEquals(eased, epsilon: 1e-6));
        expect(
          pageOffset(tester),
          moreOrLessEquals(
            sign * AppMotion.distanceLarge * (1 - eased),
            epsilon: 1e-3,
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byKey(pageKey), findsNothing);
      });
    }

    testWidgets('never moves the page more than 30px', (tester) async {
      final navigator = await pumpHost(tester);
      await pushPage(tester, navigator);
      for (var frame = 0; frame < 12; frame++) {
        expect(pageOffset(tester).abs(), lessThanOrEqualTo(30));
        await tester.pump(const Duration(milliseconds: 25));
      }
    });

    testWidgets('appears in place when the platform disables animations', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final navigator = await pumpHost(tester);
      await pushPage(tester, navigator);

      expect(pageOffset(tester), 0);
      expect(
        find.ancestor(
          of: find.byKey(pageKey),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    });
  });

  testWidgets(
    'iOS keeps the native transition and edge-swipe back',
    (tester) async {
      final navigator = await pumpHost(tester);
      final route = await pushPage(tester, navigator);
      await tester.pumpAndSettle();

      expect(route.transitionDuration, const Duration(milliseconds: 500));
      expect(
        find.ancestor(
          of: find.byKey(pageKey),
          matching: find.byType(CupertinoPageTransition),
        ),
        findsOneWidget,
      );

      await tester.dragFrom(const Offset(5, 300), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(pageKey), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('AppTheme wires the builders in light and dark', (tester) async {
    late List<ThemeData> themes;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppTheme.designSize,
        builder: (context, _) {
          themes = [
            AppTheme.light(isArabic: true),
            AppTheme.dark(isArabic: false),
          ];
          return const SizedBox.shrink();
        },
      ),
    );

    for (final theme in themes) {
      final builders = theme.pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.android],
        isA<AppPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.macOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    }
  });
}
