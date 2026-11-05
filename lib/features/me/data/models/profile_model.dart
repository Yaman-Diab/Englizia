import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/me.md).

/// «أنا» as `GET /api/v1/app/me/profile` sends it. The raw [json] is what the
/// phone keeps.
final class ProfileModel {
  const ProfileModel(this.json);

  final Map<String, Object?> json;

  /// A part that can't be read is left out; with no name, nothing shows.
  Profile toEntity() {
    final name = json.readString('name');
    if (name == null) throw const FormatException('Profile without a name');
    return Profile(
      name: name,
      email: json.readString('email'),
      emailVerified: json.readBool('emailVerified') ?? false,
      learningSince: json.readDateTime('learningSince'),
      accountNumber: json.readString('accountNumber'),
      whatsapp: json.readString('whatsapp'),
      tracks: [
        for (final item in json.readList('tracks') ?? const <Object?>[])
          ?_track(item),
      ],
      lessonsDone: json.readInt('lessonsDone') ?? 0,
      learningDays: json.readInt('learningDays') ?? 0,
      wordsSaved: json.readInt('wordsSaved'),
      streak: _streak(json.readMap('streak')),
      points: _points(json.readMap('points')),
      week: _week(json.readMap('week')),
      placement: _placement(json.readMap('placement')),
      wordBank: _wordBank(json.readMap('wordBank')),
      stars: json.readInt('stars'),
      signIn: switch (json.readString('signIn')) {
        'google' => SignInMethod.google,
        'apple' => SignInMethod.apple,
        _ => SignInMethod.email,
      },
    );
  }

  static Preferences? preferences(Map<String, Object?> json) {
    final goal = json.readInt('dailyGoalMinutes');
    if (goal == null) return null;
    final reminder = json.readString('reminderTime')?.split(':');
    return Preferences(
      dailyGoalMinutes: goal,
      notifications: json.readBool('notifications') ?? true,
      reminderHour: reminder == null ? null : int.tryParse(reminder.first),
      reminderMinute: reminder == null || reminder.length < 2
          ? 0
          : int.tryParse(reminder[1]) ?? 0,
    );
  }

  static Map<String, Object?> preferencesToJson(Preferences preferences) {
    final hour = preferences.reminderHour;
    String two(int value) => value.toString().padLeft(2, '0');
    return {
      'dailyGoalMinutes': preferences.dailyGoalMinutes,
      'notifications': preferences.notifications,
      'reminderTime': hour == null
          ? null
          : '${two(hour)}:${two(preferences.reminderMinute)}',
    };
  }

  static const _audiences = {
    'self': TrackAudience.self,
    'child': TrackAudience.child,
    'schoolStudent': TrackAudience.schoolStudent,
  };

  static ProfileTrack? _track(Object? item) {
    if (item is! Map<String, Object?>) return null;
    final enrollmentId = item.readString('enrollmentId');
    final trackId = item.readString('trackId');
    final title = item.readString('title');
    if (enrollmentId == null || trackId == null || title == null) return null;
    final units = item.readInt('units') ?? 0;
    return ProfileTrack(
      enrollmentId: enrollmentId,
      trackId: trackId,
      title: title,
      audience: _audiences[item.readString('audience')],
      levelId: item.readString('levelId'),
      levelLabel: item.readString('levelLabel') ?? '',
      levelName: item.readString('levelName') ?? '',
      unit: (item.readInt('unit') ?? 1).clamp(1, units < 1 ? 1 : units),
      units: units,
      unitCoverUrl: item.readString('unitCover'),
      active: item.readBool('active') ?? false,
    );
  }

  static Streak? _streak(Map<String, Object?>? json) {
    final current = json?.readInt('current');
    if (json == null || current == null) return null;
    return Streak(
      current: current,
      longest: json.readInt('longest') ?? current,
      freezes: json.readInt('freezes') ?? 0,
      maxFreezes: json.readInt('maxFreezes') ?? 0,
      nextFreezeWeekday: json.readInt('nextFreezeWeekday'),
    );
  }

  static Points? _points(Map<String, Object?>? json) {
    final total = json?.readInt('total');
    if (json == null || total == null) return null;
    return Points(total: total, week: json.readInt('week') ?? 0);
  }

  static StudyWeek? _week(Map<String, Object?>? json) {
    final goal = json?.readInt('goalMinutes');
    if (json == null || goal == null || goal <= 0) return null;
    final days = <StudyDay>[];
    for (final item in json.readList('days') ?? const <Object?>[]) {
      final day = asJsonMap(item);
      final date = day.readDateTime('date');
      if (date == null) continue;
      days.add(
        StudyDay(
          date: date,
          minutes: day.readInt('minutes'),
          frozen: day.readBool('frozen') ?? false,
        ),
      );
    }
    if (days.isEmpty) return null;
    return StudyWeek(
      goalMinutes: goal,
      days: days,
      today: (json.readInt('today') ?? 0).clamp(0, days.length - 1),
      dayStart: json.readString('dayStart') ?? '',
    );
  }

  static PlacementResult? _placement(Map<String, Object?>? json) {
    final level = json?.readString('level');
    final takenAt = json?.readDateTime('takenAt');
    final retestAt = json?.readDateTime('retestAt');
    if (json == null || level == null || takenAt == null || retestAt == null) {
      return null;
    }
    return PlacementResult(
      level: level,
      takenAt: takenAt,
      retestAt: retestAt,
      waitDays: json.readInt('waitDays') ?? retestAt.difference(takenAt).inDays,
    );
  }

  static WordBankTally? _wordBank(Map<String, Object?>? json) {
    final words = json?.readInt('words');
    if (json == null || words == null) return null;
    return WordBankTally(words: words, due: json.readInt('due') ?? 0);
  }
}
