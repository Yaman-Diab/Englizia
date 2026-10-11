import 'dart:math' as math;

import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_text_styles.dart';
import 'package:englizia/core/design_system/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const textMin = 4.5;
  const fillMin = 3.0;

  for (final (name, c) in [
    ('light', AppSemanticColors.light),
    ('dark', AppSemanticColors.dark),
  ]) {
    group('$name contrast (WCAG AA)', () {
      test('neutral text on background and surface', () {
        for (final bg in [c.background, c.surface]) {
          expect(contrast(c.textPrimary, bg), greaterThanOrEqualTo(textMin));
          expect(contrast(c.textSecondary, bg), greaterThanOrEqualTo(textMin));
        }
      });

      test('button label on primaryStrong', () {
        expect(
          contrast(c.onPrimaryStrong, c.primaryStrong),
          greaterThanOrEqualTo(textMin),
        );
      });

      final tones = {
        'primary': c.primary,
        'success': c.success,
        'streak': c.streak,
        'reward': c.reward,
        'ai': c.ai,
        'error': c.error,
        'info': c.info,
      };

      for (final MapEntry(key: tone, value: colors) in tones.entries) {
        test('$tone text on surface, background and its own surface', () {
          for (final bg in [c.surface, c.background, colors.surface]) {
            expect(
              contrast(colors.text, bg),
              greaterThanOrEqualTo(textMin),
              reason: '$tone text on $bg',
            );
          }
        });
      }

      test('fills on surface (reward excepted, see below)', () {
        for (final MapEntry(key: tone, value: colors) in tones.entries) {
          if (tone == 'reward') continue;
          expect(
            contrast(colors.fill, c.surface),
            greaterThanOrEqualTo(fillMin),
            reason: '$tone fill',
          );
        }
      });

      test('spoken word stays readable on the karaoke highlight', () {
        expect(
          contrast(c.textPrimary, c.reader.karaokeBackground),
          greaterThanOrEqualTo(textMin),
        );
      });
    });
  }

  test('identity doc values are pinned', () {
    // Reward fill #F59E0B (2.15:1 on white) is mandated by the identity doc
    // for the save star; it is always paired with an icon shape.
    expect(AppSemanticColors.light.reward.fill, const Color(0xFFF59E0B));
    expect(AppSemanticColors.light.primaryStrong, const Color(0xFF2563EB));
    expect(
      contrast(
        AppSemanticColors.light.onPrimaryStrong,
        const Color(0xFF2563EB),
      ),
      closeTo(5.17, 0.01),
    );
    expect(
      contrast(
        AppSemanticColors.light.textPrimary,
        AppSemanticColors.light.reader.karaokeBackground,
      ),
      closeTo(10.3, 0.05),
    );
    expect(
      contrast(
        AppSemanticColors.dark.textPrimary,
        AppSemanticColors.dark.reader.karaokeBackground,
      ),
      closeTo(9.45, 0.05),
    );
  });

  testWidgets('type scale matches the identity doc at the design width', (
    tester,
  ) async {
    tester.view
      ..physicalSize = AppTheme.designSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late AppTextStyles arabic;
    late AppTextStyles english;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppTheme.designSize,
        builder: (context, _) {
          arabic = AppTheme.light(isArabic: true).extension<AppTextStyles>()!;
          english = AppTheme.light(isArabic: false).extension<AppTextStyles>()!;
          return const SizedBox();
        },
      ),
    );

    expect(english.display.fontSize, 28);
    expect(english.title.fontSize, 22);
    expect(english.reading.fontSize, 20);
    expect(english.body.fontSize, 16);
    expect(english.caption.fontSize, 13);
    expect(english.body.height, closeTo(26 / 16, 0.001));
    expect(english.display.fontWeight, FontWeight.w600);
    expect(english.body.fontWeight, FontWeight.w400);
    // Arabic running text never goes below 1.7.
    expect(arabic.body.height, 1.7);
    expect(arabic.caption.height, 1.7);
    expect(arabic.reading.height, closeTo(36 / 20, 0.001));
  });
}
