import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  late TextEditingController controller;
  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pumpField(
    WidgetTester tester, {
    FieldMessage? message,
    bool obscurable = false,
    bool readOnly = false,
    TextDirection? textDirection,
  }) async {
    await tester.pumpLocalized(
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: AppTextField(
            label: 'كلمة المرور',
            icon: AppIcon.lock,
            controller: controller,
            message: message,
            obscurable: obscurable,
            readOnly: readOnly,
            textDirection: textDirection,
          ),
        ),
      ),
    );
    await tester.pump(AppMotion.fast);
  }

  testWidgets('shows the label above and the message under', (tester) async {
    await pumpField(
      tester,
      message: const FieldMessage('8 أحرف على الأقل', FieldMessageTone.hint),
    );
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('8 أحرف على الأقل'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('كلمة المرور')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
  });

  testWidgets('each tone has its own mark, never color alone', (tester) async {
    Future<AppIcon> markFor(FieldMessageTone tone) async {
      await pumpField(tester, message: FieldMessage('x', tone));
      return tester
          .widgetList<AppIconView>(find.byType(AppIconView))
          .map((view) => view.icon)
          .lastWhere(
            (icon) => [
              AppIcon.circle,
              AppIcon.errorCircle,
              AppIcon.checkCircle,
            ].contains(icon),
          );
    }

    expect(await markFor(FieldMessageTone.hint), AppIcon.circle);
    expect(await markFor(FieldMessageTone.error), AppIcon.errorCircle);
    expect(await markFor(FieldMessageTone.success), AppIcon.checkCircle);
  });

  testWidgets('the eye shows and hides a password', (tester) async {
    await pumpField(tester, obscurable: true);
    bool obscured() =>
        tester.widget<EditableText>(find.byType(EditableText)).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('field_password_show'.tr()));
    await tester.pump();
    expect(obscured(), isFalse);
    expect(find.byTooltip('field_password_hide'.tr()), findsOneWidget);
  });

  testWidgets('read-only takes no edits and hides the eye action', (
    tester,
  ) async {
    await pumpField(tester, obscurable: true, readOnly: true);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).readOnly,
      isTrue,
    );
    final eye = tester.widget<IconButton>(find.byType(IconButton));
    expect(eye.onPressed, isNull);
  });

  testWidgets('a Latin value in Arabic is typed left to right, aligned '
      'under its label', (tester) async {
    await pumpField(tester, textDirection: TextDirection.ltr);
    final text = tester.widget<EditableText>(find.byType(EditableText));
    expect(text.textDirection, TextDirection.ltr);
    expect(text.textAlign, TextAlign.end);
  });
}
