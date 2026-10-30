import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/account/presentation/password_changed/pages/password_changed_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  late int continues;
  late int leaves;

  setUp(() {
    continues = 0;
    leaves = 0;
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    bool signedIn = true,
    LayoutCase? layout,
    bool settled = true,
  }) async {
    await tester.pumpLocalized(
      PasswordChangedPage(
        signedIn: signedIn,
        onContinue: () => continues++,
        onLeave: () => leaves++,
      ),
      locale: layout?.locale ?? const Locale('ar'),
      size: layout?.size ?? defaultViewport,
      themeMode: layout?.themeMode ?? ThemeMode.light,
    );
    if (settled) await tester.settleEntrance(PasswordChangedEntrance.settled);
  }

  testLayouts('signed in lays out without overflow', (tester, layout) async {
    await pumpPage(tester, layout: layout);
    expect(tester.takeException(), isNull);
  });

  testLayouts('signing in by hand lays out without overflow', (
    tester,
    layout,
  ) async {
    await pumpPage(tester, signedIn: false, layout: layout);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed in: carries on learning', (tester) async {
    await pumpPage(tester);
    expect(find.text('password_changed_title'.tr()), findsOneWidget);
    expect(find.text('password_changed_signed_in'.tr()), findsOneWidget);
    await tester.tap(find.text('password_changed_continue'.tr()));
    expect(continues, 1);
  });

  testWidgets('not signed in: asks to sign in', (tester) async {
    await pumpPage(tester, signedIn: false);
    expect(find.text('password_changed_sign_in'.tr()), findsOneWidget);
    await tester.tap(find.text('sign_in_submit'.tr()));
    expect(continues, 1);
  });

  testWidgets('a quiet success: the happy guide, with no sparkles', (
    tester,
  ) async {
    await pumpPage(tester);
    final guide = tester.widget<Mascot>(find.byType(Mascot));
    expect(guide.expression, MascotExpression.happy);
    expect(guide.sparkles, isFalse);
  });

  testWidgets('no back button, and the system\'s back leaves', (tester) async {
    await pumpPage(tester);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(leaves, 1);
  });

  testWidgets('the action fades in last', (tester) async {
    await pumpPage(tester, settled: false);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    final fade = find.ancestor(
      of: find.byType(AppButton),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(fade.first).opacity.value, 0);

    await tester.pump(PasswordChangedEntrance.settled);
    expect(tester.widget<FadeTransition>(fade.first).opacity.value, 1);
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('under reduce motion, everything is simply there', (
    tester,
  ) async {
    await tester.pumpLocalized(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: PasswordChangedPage(
          signedIn: true,
          onContinue: () => continues++,
          onLeave: () => leaves++,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Animate), findsNothing);
    await tester.tap(find.byType(AppButton));
    expect(continues, 1);
  });

  testWidgets('announces the change, and meets the tap target', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPage(tester);
    final title = tester.getSemantics(find.text('password_changed_title'.tr()));
    expect(title.label, contains('password_changed_title'.tr()));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
