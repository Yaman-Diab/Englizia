import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Future<int> pumpButton(
    WidgetTester tester, {
    required bool loading,
    AppButtonVariant variant = AppButtonVariant.primary,
    AppButtonSize size = AppButtonSize.large,
  }) async {
    var taps = 0;
    await tester.pumpLocalized(
      Scaffold(
        body: Center(
          child: AppButton(
            label: 'إنشاء الحساب',
            variant: variant,
            size: size,
            expand: false,
            isLoading: loading,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump(AppMotion.quick);
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    return taps;
  }

  testWidgets('waits with the spinner instead of the label', (tester) async {
    final taps = await pumpButton(tester, loading: true);
    expect(taps, 0);
    expect(find.byType(AppSpinner), findsOneWidget);
    expect(find.bySemanticsLabel('common_loading'.tr()), findsOneWidget);
    expect(find.bySemanticsLabel('إنشاء الحساب'), findsNothing);
  });

  testWidgets('keeps its size and its full color while waiting', (
    tester,
  ) async {
    await pumpButton(tester, loading: false);
    final idleSize = tester.getSize(find.byType(FilledButton));

    await pumpButton(tester, loading: true);
    expect(tester.getSize(find.byType(FilledButton)), idleSize);

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    final context = tester.element(find.byType(FilledButton));
    expect(material.color, context.colors.primaryStrong);
  });

  testWidgets('a text button waits the same way, in its own color', (
    tester,
  ) async {
    await pumpButton(
      tester,
      loading: true,
      variant: AppButtonVariant.text,
      size: AppButtonSize.regular,
    );
    final spinner = tester.widget<AppSpinner>(find.byType(AppSpinner));
    expect(spinner.size, AppSpinner.compactSize);
  });

  testWidgets('taps when not waiting', (tester) async {
    expect(await pumpButton(tester, loading: false), 1);
    expect(find.byType(AppSpinner), findsNothing);
  });
}
