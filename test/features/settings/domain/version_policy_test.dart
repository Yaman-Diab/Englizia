import 'package:englizia/features/settings/domain/entities/app_version.dart';
import 'package:englizia/features/settings/domain/entities/version_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion', () {
    test('reads a release number, without its build or tag', () {
      expect(AppVersion.tryParse('1.4.2'), const AppVersion(1, 4, 2));
      expect(AppVersion.tryParse(' 1.4.2+17 '), const AppVersion(1, 4, 2));
      expect(AppVersion.tryParse('2.0.0-beta'), const AppVersion(2));
      expect(AppVersion.tryParse('3.1'), const AppVersion(3, 1));
      expect(AppVersion.tryParse('3'), const AppVersion(3));
    });

    test('anything else is not one', () {
      for (final text in [null, '', 'v1.0', '1..2', '1.2.3.4', 'x', '1.-2']) {
        expect(AppVersion.tryParse(text), isNull, reason: '$text');
      }
    });

    test('compares part by part, as numbers', () {
      expect(const AppVersion(1, 10) < const AppVersion(1, 9), isFalse);
      expect(const AppVersion(1, 9) < const AppVersion(1, 10), isTrue);
      expect(const AppVersion(0, 9, 9) < const AppVersion(1), isTrue);
      expect(const AppVersion(1, 2, 3) < const AppVersion(1, 2, 3), isFalse);
    });
  });

  group('the gate (design App Update: GATE DECISION)', () {
    const installed = AppVersion(1, 2);
    const policy = VersionPolicy(
      minimum: AppVersion(1, 1),
      recommended: AppVersion(1, 3),
    );

    test('older than the minimum: the update screen', () {
      expect(
        const VersionPolicy(
          minimum: AppVersion(1, 3),
          recommended: AppVersion(1, 4),
        ).needOf(installed),
        UpdateNeed.required,
      );
    });

    test('older than the recommended only: the reminder', () {
      expect(policy.needOf(installed), UpdateNeed.suggested);
    });

    test('older than neither, the same, or nothing known: nothing', () {
      expect(policy.needOf(const AppVersion(1, 3)), UpdateNeed.none);
      expect(policy.needOf(const AppVersion(2)), UpdateNeed.none);
      expect(VersionPolicy.none.needOf(installed), UpdateNeed.none);
      expect(policy.needOf(null), UpdateNeed.none);
    });

    test('a missing minimum leaves the recommended to decide', () {
      expect(
        const VersionPolicy(recommended: AppVersion(1, 3)).needOf(installed),
        UpdateNeed.suggested,
      );
    });
  });
}
