import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Activates the node labelled [label] as a screen reader does.
void _semanticTap(WidgetTester tester, String label) =>
    tester.semantics.tap(find.semantics.byLabel(label));

void main() {
  setUpAll(initLocalizationForTests);

  group('a screen reader presses the kids\' buttons', () {
    testWidgets('a round button', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpLocalized(
        Center(
          child: KidRoundButton(
            icon: const Icon(Icons.volume_up_rounded),
            label: 'استمع',
            onPressed: () => taps++,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('استمع')),
        matchesSemantics(
          label: 'استمع',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      _semanticTap(tester, 'استمع');
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a round button without an action says it is off', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpLocalized(
        const Center(
          child: KidRoundButton(
            icon: Icon(Icons.volume_up_rounded),
            label: 'استمع',
            onPressed: null,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('استمع')),
        matchesSemantics(label: 'استمع', isButton: true, hasEnabledState: true),
      );
      handle.dispose();
    });

    testWidgets('the guide', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpLocalized(
        Center(
          child: KidGuideButton(
            speaking: false,
            expression: MascotExpression.welcome,
            onPressed: () => taps++,
          ),
        ),
      );
      final label = 'kid_say_again'.tr();
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(label: label, isButton: true, hasTapAction: true),
      );
      _semanticTap(tester, label);
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('the way out\'s two pictures', (tester) async {
      final handle = tester.ensureSemantics();
      late BuildContext context;
      await tester.pumpLocalized(
        Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.expand();
          },
        ),
      );
      bool? leave;
      unawaited(showKidExitSheet(context).then((value) => leave = value));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final label = 'kid_leave'.tr();
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        matchesSemantics(label: label, isButton: true, hasTapAction: true),
      );
      _semanticTap(tester, label);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(leave, isTrue);
      handle.dispose();
    });
  });
}
