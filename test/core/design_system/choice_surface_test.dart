import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(initLocalizationForTests);

  Color fillOf(WidgetTester tester) => tester
      .widget<Material>(
        find.descendant(
          of: find.byType(ChoiceSurface),
          matching: find.byType(Material),
        ),
      )
      .color!;

  testWidgets('a selected card is a checked radio on the selection tint', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpLocalized(
      ChoiceSurface(
        selected: true,
        onTap: () => taps++,
        child: const Text('Option'),
      ),
    );

    expect(
      tester.getSemantics(find.text('Option')),
      isSemantics(
        label: 'Option',
        isChecked: true,
        hasCheckedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(fillOf(tester), AppSemanticColors.light.selectionSurface);
    await tester.tap(find.text('Option'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a selected pill fills with the button color', (tester) async {
    await tester.pumpLocalized(
      ChoiceSurface(
        selected: true,
        onTap: () {},
        shape: ChoiceShape.pill,
        child: const Text('6'),
      ),
    );
    expect(fillOf(tester), AppSemanticColors.light.primaryStrong);
  });

  testWidgets('semanticLabel replaces the visible content', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(
      ChoiceSurface(
        selected: false,
        onTap: () {},
        semanticLabel: '6 سنوات',
        child: const Text('6'),
      ),
    );
    expect(find.bySemanticsLabel('6 سنوات'), findsOneWidget);
    expect(find.bySemanticsLabel('6'), findsNothing);
    handle.dispose();
  });

  testWidgets('without onTap it cannot be activated', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpLocalized(
      const ChoiceSurface(selected: false, onTap: null, child: Text('Soon')),
    );
    expect(
      tester.getSemantics(find.text('Soon')),
      isSemantics(hasTapAction: false, hasCheckedState: true),
    );
    handle.dispose();
  });

  testWidgets('the check pops in when selected and hides its ring on demand', (
    tester,
  ) async {
    await tester.pumpLocalized(
      const Row(
        children: [
          ChoiceCheck(selected: true),
          ChoiceCheck(selected: false, showRing: false),
        ],
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(DecoratedBox), findsOneWidget);
  });
}
