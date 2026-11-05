import 'package:englizia/core/design_system/color_mix.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Within one step of 255 on each channel, as the designs round them.
Matcher _near(int argb) => predicate<Color>((color) {
  final expected = Color(argb);
  int byte(double v) => (v * 255).round();
  return (byte(color.r) - byte(expected.r)).abs() <= 1 &&
      (byte(color.g) - byte(expected.g)).abs() <= 1 &&
      (byte(color.b) - byte(expected.b)).abs() <= 1 &&
      (byte(color.a) - byte(expected.a)).abs() <= 1;
}, '≈ 0x${argb.toRadixString(16).toUpperCase()}');

void main() {
  group('colour mixes (CSS color-mix, the board\'s vectors)', () {
    test('oklab', () {
      expect(
        mixOklab(const Color(0xFFFFFFFF), const Color(0xFFFEF3C7), .55),
        _near(0xFFFFFAE6),
      );
      expect(
        mixOklab(const Color(0xFF131C2E), const Color(0xFF3A2A0A), .55),
        _near(0xFF252322),
      );
    });

    test('oklch: the seas\' depths', () {
      const depth = Color(0xFFBFDBFE);
      for (final (sea, bottom) in [
        (0xFFE6EEFD, 0xFFD5E5FE),
        (0xFFD3E4FE, 0xFFCAE0FE),
        (0xFFCBE0FE, 0xFFC6DEFE),
        (0xFFDDEEF5, 0xFFCDE7F8),
        (0xFFEFF6FF, 0xFFD9EAFF),
        (0xFFEBF2FE, 0xFFD8E7FE),
        (0xFFAACFFE, 0xFFB3D4FE),
      ]) {
        expect(mixOklch(Color(sea), depth, .55), _near(bottom), reason: '$sea');
      }
      expect(
        mixOklch(const Color(0xFF172554), const Color(0xFF0C1220), .55),
        _near(0xFF121D3C),
      );
    });

    test('oklch: lips towards black keep their hue', () {
      const black = Color(0xFF000000);
      expect(mixOklch(const Color(0xFF1F8A4C), black, .72), _near(0xFF10572E));
      expect(mixOklch(const Color(0xFF5FD394), black, .72), _near(0xFF3A875D));
      expect(mixOklch(const Color(0xFF2563EB), black, .72), _near(0xFF143D97));
    });

    test('the ends are the colours themselves', () {
      const a = Color(0xFF3B82F6);
      const b = Color(0xFFF59E0B);
      expect(mixOklch(a, b, 1), _near(0xFF3B82F6));
      expect(mixOklab(a, b, 0), _near(0xFFF59E0B));
    });
  });

  group('the sea', () {
    test('each CEFR band has its sea; an unknown one is the general', () {
      const sea = SeaPalette.light;
      expect(sea.cefrSea('preA1'), sea.preA1);
      expect(sea.cefrSea('a1'), sea.a1);
      expect(sea.cefrSea('a2'), sea.general);
      expect(sea.cefrSea('b1'), sea.deep);
      expect(sea.cefrSea('b2'), sea.b2);
      expect(sea.cefrSea('c1'), sea.b2);
      expect(sea.cefrSea(null), sea.general);
      expect(sea.cefrSea('z9'), sea.general);
    });

    test('a sea deepens to its bottom', () {
      expect(
        SeaPalette.light.seaBottom(SeaPalette.light.general),
        _near(0xFFD5E5FE),
      );
      expect(
        SeaPalette.dark.seaBottom(SeaPalette.dark.general),
        _near(0xFF121D3C),
      );
    });
  });

  group('home motion', () {
    test('the design\'s own curves, exact', () {
      expect(
        AppMotion.homeScrollCurve.transform(.25),
        closeTo(4 * .25 * .25 * .25, 1e-9),
      );
      expect(AppMotion.homeScrollCurve.transform(.5), closeTo(.5, 1e-9));
      expect(AppMotion.homeRowsCurve.transform(.75), closeTo(1 - .125, 1e-9));
      expect(AppMotion.homeSnapCurve.transform(.5), closeTo(.875, 1e-9));
      expect(AppMotion.homeSnapCurve.transform(1), 1);
    });

    test(
      'the opening\'s islands rise in turn, then everything has arrived',
      () {
        expect(HomeEntrance.isle(0), const Duration(milliseconds: 80));
        expect(HomeEntrance.isle(7), const Duration(milliseconds: 500));
        expect(HomeEntrance.settled(8), const Duration(milliseconds: 1240));
        expect(HomeEntrance.settled(16), const Duration(milliseconds: 1300));
      },
    );
  });
}
