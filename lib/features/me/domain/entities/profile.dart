import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:equatable/equatable.dart';

/// How the learner signs in: a password to change, or another account's.
enum SignInMethod { email, google, apple }

/// What the learner chose for their learning and reminders, kept on the
/// server so it follows the account (S §19.2).
final class Preferences extends Equatable {
  const Preferences({
    required this.dailyGoalMinutes,
    required this.notifications,
    this.reminderHour,
    this.reminderMinute = 0,
  });

  final int dailyGoalMinutes;

  /// The phone may show notifications: all of them, or none.
  final bool notifications;

  /// The daily reminder's time, or none chosen.
  final int? reminderHour;
  final int reminderMinute;

  Preferences copyWith({
    int? dailyGoalMinutes,
    bool? notifications,
    int? reminderHour,
    int? reminderMinute,
  }) => Preferences(
    dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    notifications: notifications ?? this.notifications,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
  );

  @override
  List<Object?> get props => [
    dailyGoalMinutes,
    notifications,
    reminderHour,
    reminderMinute,
  ];
}

/// A track the learner has joined, with how far they are in it (S §19.1).
final class ProfileTrack extends Equatable {
  const ProfileTrack({
    required this.enrollmentId,
    required this.trackId,
    required this.title,
    required this.unit,
    required this.units,
    this.audience,
    this.levelId,
    this.levelLabel = '',
    this.levelName = '',
    this.unitCoverUrl,
    this.active = false,
  });

  final String enrollmentId;
  final String trackId;
  final String title;

  /// Who it is for, which picks its sea: general, school (Emar) or kids.
  final TrackAudience? audience;
  final String? levelId;

  /// The level's short name on the picture's badge: «A2», «ص7»; empty when
  /// the track has no levels.
  final String levelLabel;

  /// «ما قبل المتوسط», «الصف السابع».
  final String levelName;

  /// The unit reached, from 1, of [units].
  final int unit;
  final int units;

  /// The current unit's cover, on the band's island.
  final String? unitCoverUrl;
  final bool active;

  bool get isSchool => audience == TrackAudience.schoolStudent;

  ProfileTrack withActive({required bool active}) => ProfileTrack(
    enrollmentId: enrollmentId,
    trackId: trackId,
    title: title,
    unit: unit,
    units: units,
    audience: audience,
    levelId: levelId,
    levelLabel: levelLabel,
    levelName: levelName,
    unitCoverUrl: unitCoverUrl,
    active: active,
  );

  @override
  List<Object?> get props => [
    enrollmentId,
    trackId,
    title,
    audience,
    levelId,
    levelLabel,
    levelName,
    unit,
    units,
    unitCoverUrl,
    active,
  ];
}

/// The days in a row the daily goal was reached, and the freezes that keep it.
final class Streak extends Equatable {
  const Streak({
    required this.current,
    required this.longest,
    required this.freezes,
    required this.maxFreezes,
    this.nextFreezeWeekday,
  });

  final int current;
  final int longest;
  final int freezes;
  final int maxFreezes;

  /// The day of the week the next freeze is added, as [DateTime.weekday].
  final int? nextFreezeWeekday;

  @override
  List<Object?> get props => [
    current,
    longest,
    freezes,
    maxFreezes,
    nextFreezeWeekday,
  ];
}

/// One day of the week's chart.
final class StudyDay extends Equatable {
  const StudyDay({required this.date, this.minutes, this.frozen = false});

  final DateTime date;

  /// Null for a day still to come.
  final int? minutes;

  /// Missed, and kept by a freeze.
  final bool frozen;

  bool get future => minutes == null && !frozen;

  @override
  List<Object?> get props => [date, minutes, frozen];
}

/// This week against the daily goal, with the day's start in the learner's
/// time zone (S §15).
final class StudyWeek extends Equatable {
  const StudyWeek({
    required this.goalMinutes,
    required this.days,
    required this.today,
    this.dayStart = '',
  });

  final int goalMinutes;
  final List<StudyDay> days;

  /// The index of today in [days]; their length when today isn't one of
  /// them (a week rolled over on the phone past its last day).
  final int today;

  /// «4:00», when a new day begins.
  final String dayStart;

  int get goalDays => [
    for (final day in days)
      if (!day.frozen && (day.minutes ?? 0) >= goalMinutes) day,
  ].length;

  @override
  List<Object?> get props => [goalMinutes, days, today, dayStart];
}

final class Points extends Equatable {
  const Points({required this.total, required this.week});

  final int total;
  final int week;

  @override
  List<Object?> get props => [total, week];
}

/// The placement test's result, and when it can be taken again (S §12).
final class PlacementResult extends Equatable {
  const PlacementResult({
    required this.level,
    required this.takenAt,
    required this.retestAt,
    required this.waitDays,
  });

  final String level;
  final DateTime takenAt;
  final DateTime retestAt;

  /// The whole wait between two tests, from the panel.
  final int waitDays;

  /// Whole days left before it can be taken again; 0 once it can.
  int daysLeft(DateTime now) {
    final left = retestAt.difference(now);
    if (left <= Duration.zero) return 0;
    return (left.inHours / 24).ceil();
  }

  @override
  List<Object?> get props => [level, takenAt, retestAt, waitDays];
}

final class WordBankTally extends Equatable {
  const WordBankTally({required this.words, required this.due});

  final int words;
  final int due;

  @override
  List<Object?> get props => [words, due];
}

/// «أنا» (S §19.1, §13.5): who the learner is, their tracks and what they
/// have done. A part the server leaves out isn't shown.
final class Profile extends Equatable {
  const Profile({
    required this.name,
    required this.tracks,
    required this.lessonsDone,
    required this.learningDays,
    this.email,
    this.emailVerified = false,
    this.learningSince,
    this.accountNumber,
    this.wordsSaved,
    this.streak,
    this.points,
    this.week,
    this.placement,
    this.wordBank,
    this.stars,
    this.whatsapp,
    this.signIn = SignInMethod.email,
  });

  final String name;
  final String? email;
  final bool emailVerified;
  final DateTime? learningSince;

  /// Said to support on WhatsApp, so they can find the account.
  final String? accountNumber;
  final List<ProfileTrack> tracks;
  final int lessonsDone;
  final int learningDays;
  final int? wordsSaved;
  final Streak? streak;
  final Points? points;
  final StudyWeek? week;
  final PlacementResult? placement;
  final WordBankTally? wordBank;

  /// Kids: the stars earned in all.
  final int? stars;

  /// Support's WhatsApp number, from the panel.
  final String? whatsapp;
  final SignInMethod signIn;

  ProfileTrack? get active {
    for (final track in tracks) {
      if (track.active) return track;
    }
    return tracks.firstOrNull;
  }

  Profile copyWith({
    String? name,
    bool? emailVerified,
    List<ProfileTrack>? tracks,
  }) => Profile(
    name: name ?? this.name,
    tracks: tracks ?? this.tracks,
    lessonsDone: lessonsDone,
    learningDays: learningDays,
    email: email,
    emailVerified: emailVerified ?? this.emailVerified,
    learningSince: learningSince,
    accountNumber: accountNumber,
    wordsSaved: wordsSaved,
    streak: streak,
    points: points,
    week: week,
    placement: placement,
    wordBank: wordBank,
    stars: stars,
    whatsapp: whatsapp,
    signIn: signIn,
  );

  @override
  List<Object?> get props => [
    name,
    email,
    emailVerified,
    learningSince,
    accountNumber,
    tracks,
    lessonsDone,
    learningDays,
    wordsSaved,
    streak,
    points,
    week,
    placement,
    wordBank,
    stars,
    whatsapp,
    signIn,
  ];
}
