import 'package:englizia/features/me/data/datasources/profile_remote_data_source.dart';
import 'package:englizia/features/me/data/models/profile_model.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// A week as the bundle has it: today is its fourth day, with minutes
/// on the first three and the goal's on today.
Map<String, Object?> _bundled() => {
  'week': {
    'goalMinutes': 10,
    'dayStart': '04:00',
    'today': 3,
    'days': [
      {'date': '2026-10-31', 'minutes': 12},
      {'date': '2026-11-01', 'minutes': 10},
      {'date': '2026-11-02', 'minutes': 15},
      {'date': '2026-11-03', 'minutes': 10},
      {'date': '2026-11-04'},
      {'date': '2026-11-05'},
      {'date': '2026-11-06'},
    ],
  },
};

StudyWeek _weekOn(DateTime now) {
  final json = ProfileFakeDataSource.moveToToday(_bundled(), now);
  return ProfileModel.weekOf((json['week'] as Map).cast<String, Object?>())!;
}

void main() {
  group('the study week runs from Saturday to Friday', () {
    // 2026-10-31 is a Saturday.
    final saturday = DateTime(2026, 10, 31, 9);

    test('every day of the week places its week on the same Saturday', () {
      for (var offset = 0; offset < 7; offset++) {
        final now = saturday.add(Duration(days: offset));
        final week = _weekOn(now);

        expect(week.days.first.date, DateTime(2026, 10, 31));
        expect(week.days.last.date, DateTime(2026, 11, 6));
        expect(week.today, offset, reason: 'index for $now');
        expect(
          week.days[week.today].date,
          DateTime(now.year, now.month, now.day),
        );
      }
    });

    test('a Saturday is the first day, a Friday the last', () {
      expect(_weekOn(saturday).today, 0);
      expect(_weekOn(DateTime(2026, 11, 6, 23)).today, 6);
    });

    test('each day keeps the minutes it had around today', () {
      // Thursday 2026-11-05 is the sixth day. Each bundled day keeps its
      // distance from the bundle's today (the fourth day).
      final week = _weekOn(DateTime(2026, 11, 5, 10));

      expect(week.today, 5);
      expect(week.days[5].minutes, 10, reason: 'today keeps its minutes');
      expect(week.days[2].minutes, 12, reason: 'the bundle\'s first day');
      expect(week.days[3].minutes, 10);
      expect(week.days[4].minutes, 15);
      expect(week.days[1].minutes, isNull, reason: 'not in the bundle');
    });

    test('days the bundle lacks come with no minutes', () {
      // On Saturday today is the first day: the bundle's today (10 minutes)
      // moves there, and the days after it are past the bundle's last day.
      final week = _weekOn(saturday);

      expect(week.days.first.minutes, 10);
      expect(week.days[1].minutes, isNull);
      expect(week.days.last.minutes, isNull);
      expect(week.days.last.frozen, isFalse);
    });
  });
}
