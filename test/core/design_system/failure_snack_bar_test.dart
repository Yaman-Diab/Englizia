import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Future<void> show(WidgetTester tester, {VoidCallback? onRetry}) async {
    await tester.pumpLocalized(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFailureSnackBar(
              context,
              const NetworkFailure(),
              onRetry: onRetry,
            ),
            child: const Text('fail'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('fail'));
    await tester.pumpAndSettle();
  }

  testWidgets('a band goes by itself', (tester) async {
    await show(tester);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('one with a retry stays long enough to reach it, then goes', (
    tester,
  ) async {
    var retried = 0;
    await show(tester, onRetry: () => retried++);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('common_retry'.tr()), findsOneWidget);
    await tester.tap(find.text('common_retry'.tr()));
    expect(retried, 1);

    await show(tester, onRetry: () {});
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('with a screen reader, one with a retry stays until used', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await show(tester, onRetry: () {});
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('common_retry'.tr()), findsOneWidget);
  });
}
