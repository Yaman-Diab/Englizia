import 'dart:math' as math;

import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_text_styles.dart';
import 'package:englizia/core/design_system/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const textMin = 4.5;
  const fillMin = 3.0;
  // Identity 1.0 fills that v2 keeps although they sit below 3:1 on white
  // (success 2.28, streak 2.80, reward 2.15, info 2.43). States always pair
  // the color with an icon and text, so the color is never the only signal.
  const docFillsBelowThree = {'success', 'streak', 'reward', 'info'};

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

      test('fills on surface (doc-mandated light fills excepted)', () {
        for (final MapEntry(key: tone, value: colors) in tones.entries) {
          if (name == 'light' && docFillsBelowThree.contains(tone)) continue;
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

  test('identity 1.0 light tokens are pinned', () {
    const light = AppSemanticColors.light;
    final expected = <String, (Color, int)>{
      'PRIMARY': (light.primary.fill, 0xFF3B82F6),
      'PRIMARY_DARK (button)': (light.primaryStrong, 0xFF2563EB),
      'PRIMARY_SURFACE': (light.primary.surface, 0xFFDBEAFE),
      'SUCCESS': (light.success.fill, 0xFF22C55E),
      'SUCCESS_SURFACE': (light.success.surface, 0xFFDCFCE7),
      'STREAK': (light.streak.fill, 0xFFF97316),
      'AI_SPECIAL': (light.ai.fill, 0xFF8B5CF6),
      'REWARD': (light.reward.fill, 0xFFF59E0B),
      'ERROR': (light.error.fill, 0xFFEF4444),
      'ERROR_SURFACE': (light.error.surface, 0xFFFEE2E2),
      'INFO_COMMUNICATION': (light.info.fill, 0xFF06B6D4),
      'TEXT_PRIMARY': (light.textPrimary, 0xFF1E293B),
      'TEXT_SECONDARY': (light.textSecondary, 0xFF64748B),
      'BACKGROUND': (light.background, 0xFFF8FAFC),
      'SURFACE': (light.surface, 0xFFFFFFFF),
      'BORDER': (light.border, 0xFFE2E8F0),
    };
    expected.forEach((token, pair) {
      expect(pair.$1, Color(pair.$2), reason: token);
    });
  });

  test('identity v2 tokens are pinned', () {
    const light = AppSemanticColors.light;
    const dark = AppSemanticColors.dark;
    // "Button background is always #2563EB" (5.17:1 with white), both modes.
    for (final colors in [light, dark]) {
      expect(colors.primaryStrong, const Color(0xFF2563EB));
      expect(colors.onPrimaryStrong, const Color(0xFFFFFFFF));
    }
    expect(
      contrast(dark.onPrimaryStrong, dark.primaryStrong),
      closeTo(5.17, 0.01),
    );
    expect(dark.reward.fill, const Color(0xFFFBBF24));
    expect(light.reader.karaokeBackground, const Color(0xFFBFDBFE));
    expect(dark.reader.karaokeBackground, const Color(0xFF1E3A8A));
    expect(light.reader.sentenceBand, const Color(0xFFEFF6FF));
    expect(dark.reader.sentenceBand, const Color(0xFF172554));
    expect(light.reader.tappableUnderline, const Color(0xFF3B82F6));
    expect(dark.reader.tappableUnderline, const Color(0xFF60A5FA));
    expect(light.reader.selectedWord, const Color(0xFF2563EB));
    expect(dark.reader.selectedWord, const Color(0xFF60A5FA));
    expect(light.reader.captionArabic, const Color(0xFFFDE047));
  });

  test("dark tokens from the designs' token table are pinned", () {
    const dark = AppSemanticColors.dark;
    final expected = <String, (Color, int)>{
      'BACKGROUND': (dark.background, 0xFF0C1220),
      'SURFACE': (dark.surface, 0xFF131C2E),
      'BORDER': (dark.border, 0xFF5F6E8A),
      'TEXT_PRIMARY': (dark.textPrimary, 0xFFE8EEF8),
      'TEXT_SECONDARY': (dark.textSecondary, 0xFFA9B5C8),
      'PRIMARY_TEXT': (dark.primary.text, 0xFF8AB4FF),
      'ERROR': (dark.error.fill, 0xFFF28B82),
      'ERROR_TEXT': (dark.error.text, 0xFFF2B8B5),
      'ERROR_SURFACE': (dark.error.surface, 0xFF3A1A18),
      'SUCCESS': (dark.success.fill, 0xFF5FD394),
      'SUCCESS_TEXT': (dark.success.text, 0xFF8BE0B0),
    };
    expected.forEach((token, pair) {
      expect(pair.$1, Color(pair.$2), reason: token);
    });
  });

  test('category tiles follow the designs and keep the icon readable', () {
    const expected = {
      TileTone.blue: (0xFFE3EDFE, 0xFF2563EB, 0xFF17284A, 0xFF8AB4FF),
      TileTone.amber: (0xFFFDF1DC, 0xFFB86E00, 0xFF33270F, 0xFFF5B54E),
      TileTone.green: (0xFFDDF5E8, 0xFF1F8A4C, 0xFF10301F, 0xFF5FD394),
      TileTone.sky: (0xFFDDF3FA, 0xFF0E7FA6, 0xFF0F2C36, 0xFF5CCBEA),
      TileTone.orange: (0xFFFFE8DA, 0xFFD2560F, 0xFF3A2012, 0xFFFF9A5C),
      TileTone.navy: (0xFFE1E6F2, 0xFF1E3A8A, 0xFF1A2236, 0xFF9DB3E8),
    };
    for (final MapEntry(key: tone, value: v) in expected.entries) {
      final light = AppSemanticColors.light.tiles.of(tone);
      final dark = AppSemanticColors.dark.tiles.of(tone);
      expect(light.background, Color(v.$1), reason: '$tone light bg');
      expect(light.icon, Color(v.$2), reason: '$tone light icon');
      expect(dark.background, Color(v.$3), reason: '$tone dark bg');
      expect(dark.icon, Color(v.$4), reason: '$tone dark icon');
      // Icons need 3:1 against what they sit on.
      expect(
        contrast(light.icon, light.background),
        greaterThanOrEqualTo(fillMin),
      );
      expect(
        contrast(dark.icon, dark.background),
        greaterThanOrEqualTo(fillMin),
      );
    }
  });

  test('doc contrast figures hold', () {
    expect(
      contrast(
        AppSemanticColors.light.textPrimary,
        AppSemanticColors.light.reader.karaokeBackground,
      ),
      closeTo(10.3, 0.05),
    );
    // v2 states 9.45 with a TEXT_PRIMARY it never publishes; the designs'
    // #E8EEF8 gives this figure, still well above 4.5.
    expect(
      contrast(
        AppSemanticColors.dark.textPrimary,
        AppSemanticColors.dark.reader.karaokeBackground,
      ),
      closeTo(8.89, 0.05),
    );
  });

  testWidgets('every font weight in use loads from bundled assets', (
    tester,
  ) async {
    // Runtime fetching is off (flutter_test_config.dart), so a missing or
    // misnamed file in assets/fonts makes this throw.
    await tester.runAsync(() async {
      AppFonts.primary(const TextStyle(fontWeight: FontWeight.w400));
      AppFonts.primary(const TextStyle(fontWeight: FontWeight.w600));
      AppFonts.kids(const TextStyle(fontWeight: FontWeight.w400));
      AppFonts.kids(const TextStyle(fontWeight: FontWeight.w700));
      await GoogleFonts.pendingFonts();
    });
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
    expect(english.captionStrong.fontWeight, FontWeight.w600);
    expect(english.body.fontFamily, isNot(english.bodyStrong.fontFamily));
    // Arabic running text never goes below 1.7.
    expect(arabic.body.height, 1.7);
    expect(arabic.caption.height, 1.7);
    expect(arabic.reading.height, closeTo(36 / 20, 0.001));
  });
}
