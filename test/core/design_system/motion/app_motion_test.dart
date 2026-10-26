import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('durations follow the source scale in ascending order', () {
    const scale = [
      AppMotion.stagger,
      AppMotion.micro,
      AppMotion.quick,
      AppMotion.fast,
      AppMotion.medium,
      AppMotion.slow,
      AppMotion.verySlow,
    ];
    expect(scale.map((d) => d.inMilliseconds), [
      40,
      80,
      150,
      250,
      350,
      400,
      500,
    ]);
  });

  test('curves match their CSS easings', () {
    void expectCubic(Curve curve, List<double> controlPoints, String name) {
      expect(curve, isA<Cubic>(), reason: name);
      final cubic = curve as Cubic;
      expect([cubic.a, cubic.b, cubic.c, cubic.d], controlPoints, reason: name);
    }

    expectCubic(AppMotion.smoothOut, [0.22, 1, 0.36, 1], 'smoothOut');
    expectCubic(AppMotion.inOut, [0.42, 0, 0.58, 1], 'CSS ease-in-out');
    expectCubic(AppMotion.out, [0, 0, 0.58, 1], 'CSS ease-out');
    expectCubic(AppMotion.bounce, [0.34, 1.36, 0.64, 1], 'bounce');
    expect(AppMotion.linear, same(Curves.linear));
  });

  test('only bounce overshoots its end value', () {
    double peak(Curve curve) => [
      for (var i = 1; i < 100; i++) curve.transform(i / 100),
    ].reduce((a, b) => a > b ? a : b);

    expect(peak(AppMotion.bounce), greaterThan(1));
    expect(peak(AppMotion.smoothOut), lessThanOrEqualTo(1));
    expect(peak(AppMotion.inOut), lessThanOrEqualTo(1));
  });

  test('distances and scales follow the source scale', () {
    expect(
      [
        AppMotion.distanceMicro,
        AppMotion.distanceSmall,
        AppMotion.distanceBase,
        AppMotion.distanceMedium,
        AppMotion.distanceLarge,
      ],
      [4, 6, 8, 12, 30],
    );
    expect(
      [
        AppMotion.scaleLarge,
        AppMotion.scaleMedium,
        AppMotion.scaleSmall,
        AppMotion.scaleTiny,
      ],
      [0.96, 0.97, 0.98, 0.99],
    );
  });

  group('reduced motion', () {
    Future<(bool, Duration)> readUnder(
      WidgetTester tester, {
      required bool disableAnimations,
    }) async {
      late (bool, Duration) result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (context) {
              result = (
                AppMotion.reduceMotion(context),
                AppMotion.resolve(context, AppMotion.fast),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('keeps the duration when animations are enabled', (
      tester,
    ) async {
      final (reduce, duration) = await readUnder(
        tester,
        disableAnimations: false,
      );
      expect(reduce, isFalse);
      expect(duration, AppMotion.fast);
    });

    testWidgets('drops the movement when the platform disables animations', (
      tester,
    ) async {
      final (reduce, duration) = await readUnder(
        tester,
        disableAnimations: true,
      );
      expect(reduce, isTrue);
      expect(duration, Duration.zero);
    });
  });
}
