import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:equatable/equatable.dart';

/// What the track calls its levels: «المستوى التالي: B1» or «الصف التالي».
enum HomeLevelLabel { level, grade, book }

/// A level's CEFR band, which picks its sea.
enum HomeCefr { preA1, a1, a2, b1, b2, c1 }

/// A one-time notice the server tells once (S §15).
enum HomeEventKind { freezeUsed, streakBroken }

/// The «تعلّم» tab for the active enrollment (S §6.1, design "Home
/// Archipelago"): the learner, the level's units in order, the current unit's
/// lessons, today against the goal, and what is due. A part the server leaves
/// out isn't shown.
final class HomeSnapshot extends Equatable {
  const HomeSnapshot({
    required this.learner,
    required this.enrollment,
    required this.enrollments,
    required this.level,
    required this.units,
    this.week,
    this.streak,
    this.freezesPerWeek = 1,
    this.review,
    this.cards = const HomeCards(),
    this.events = const [],
  });

  final HomeLearner learner;
  final HomeEnrollment enrollment;

  /// Every joined track, as «أنا» lists them.
  final List<ProfileTrack> enrollments;
  final HomeLevel level;

  /// All the units of the level, in order.
  final List<HomeUnit> units;

  /// Null on a v0.1 server: no ring, no flame (with [streak]).
  final StudyWeek? week;
  final Streak? streak;

  /// Freezes added each week (0–3); 0 hides «يُضاف واحد كل أسبوع».
  final int freezesPerWeek;

  /// Null when nothing is due: no review box, no badge.
  final HomeReview? review;
  final HomeCards cards;
  final List<HomeEvent> events;

  bool get kids => enrollment.kidsMode;

  /// The v0.1 frame: no ring, flame, review box, tab badge or page search.
  bool get v01 => week == null || streak == null;

  /// The unit being learned, or -1 when there is none (the level is done).
  int get currentUnitIndex =>
      units.indexWhere((unit) => unit.status == UnitLessonStatus.current);

  HomeUnit? get currentUnit {
    final index = currentUnitIndex;
    return index < 0 ? null : units[index];
  }

  int get unitsDone => HomeRules.unitsDone(this);

  /// 0 once today has rolled past the week's days ([HomeRules.rollOver]).
  int get todayMinutes {
    final week = this.week;
    if (week == null || v01 || week.today >= week.days.length) return 0;
    return week.days[week.today].minutes ?? 0;
  }

  int get goalMinutes => week?.goalMinutes ?? 0;

  /// Merged with what the phone knows of the current unit's lessons: those
  /// completed here, where one left off, which open offline.
  HomeSnapshot withPhone(LessonOnPhone Function(String lessonId) phone) =>
      copyWith(units: [for (final unit in units) unit.withPhone(phone)]);

  HomeSnapshot copyWith({
    HomeLearner? learner,
    HomeEnrollment? enrollment,
    List<ProfileTrack>? enrollments,
    HomeLevel? level,
    List<HomeUnit>? units,
    StudyWeek? Function()? week,
    Streak? Function()? streak,
    int? freezesPerWeek,
    HomeReview? Function()? review,
    HomeCards? cards,
    List<HomeEvent>? events,
  }) => HomeSnapshot(
    learner: learner ?? this.learner,
    enrollment: enrollment ?? this.enrollment,
    enrollments: enrollments ?? this.enrollments,
    level: level ?? this.level,
    units: units ?? this.units,
    week: week != null ? week() : this.week,
    streak: streak != null ? streak() : this.streak,
    freezesPerWeek: freezesPerWeek ?? this.freezesPerWeek,
    review: review != null ? review() : this.review,
    cards: cards ?? this.cards,
    events: events ?? this.events,
  );

  @override
  List<Object?> get props => [
    learner,
    enrollment,
    enrollments,
    level,
    units,
    week,
    streak,
    freezesPerWeek,
    review,
    cards,
    events,
  ];
}

final class HomeLearner extends Equatable {
  const HomeLearner({
    required this.name,
    this.lessonsDone = 0,
    this.welcomeBack = false,
    this.emailVerified = false,
    this.signIn = SignInMethod.email,
    this.stars,
    this.greetingAudioUrl,
  });

  final String name;

  /// 0 is the first day.
  final int lessonsDone;

  /// No activity for three days or more, by the learner's day (server).
  final bool welcomeBack;
  final bool emailVerified;

  /// Null for a guest.
  final SignInMethod? signIn;

  /// Kids: the stars earned in all.
  final int? stars;

  /// Kids: the greeting the listen button plays.
  final String? greetingAudioUrl;

  /// The greeting's name: the first word of [name] (D35).
  String get firstName {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.first.isEmpty ? name : words.first;
  }

  HomeLearner copyWith({int? lessonsDone, bool? welcomeBack}) => HomeLearner(
    name: name,
    lessonsDone: lessonsDone ?? this.lessonsDone,
    welcomeBack: welcomeBack ?? this.welcomeBack,
    emailVerified: emailVerified,
    signIn: signIn,
    stars: stars,
    greetingAudioUrl: greetingAudioUrl,
  );

  @override
  List<Object?> get props => [
    name,
    lessonsDone,
    welcomeBack,
    emailVerified,
    signIn,
    stars,
    greetingAudioUrl,
  ];
}

/// The active enrollment, which shapes the whole tab.
final class HomeEnrollment extends Equatable {
  const HomeEnrollment({
    required this.id,
    required this.trackId,
    required this.title,
    this.audience,
    this.kidsMode = false,
    this.ordered = true,
    this.levelLabel = HomeLevelLabel.level,
  });

  final String id;
  final String trackId;
  final String title;

  /// Picks the sea: general, school (Emar) or kids.
  final TrackAudience? audience;
  final bool kidsMode;

  /// Lessons and units open one after another; otherwise all are open and
  /// the first left is the one suggested (Emar).
  final bool ordered;
  final HomeLevelLabel levelLabel;

  @override
  List<Object?> get props => [
    id,
    trackId,
    title,
    audience,
    kidsMode,
    ordered,
    levelLabel,
  ];
}

/// The level after this one, for the horizon and «ابدأ B1».
final class HomeLevelRef extends Equatable {
  const HomeLevelRef({
    required this.id,
    required this.label,
    this.name = '',
    this.cefr,
  });

  final String id;

  /// «B1», «الصف 8».
  final String label;
  final String name;
  final HomeCefr? cefr;

  @override
  List<Object?> get props => [id, label, name, cefr];
}

final class HomeLevel extends Equatable {
  const HomeLevel({
    required this.id,
    required this.label,
    this.name = '',
    this.cefr,
    this.completed = false,
    this.next,
  });

  final String id;

  /// «A2», «الصف 7», «Starter 2».
  final String label;

  /// «ما قبل المتوسط», «الصف السابع».
  final String name;
  final HomeCefr? cefr;

  /// Every unit done: the horizon opens and the level card shows until the
  /// next level starts.
  final bool completed;

  /// Null at the track's last level.
  final HomeLevelRef? next;

  HomeLevel copyWith({bool? completed}) => HomeLevel(
    id: id,
    label: label,
    name: name,
    cefr: cefr,
    completed: completed ?? this.completed,
    next: next,
  );

  @override
  List<Object?> get props => [id, label, name, cefr, completed, next];
}

/// One island: a unit of the level.
final class HomeUnit extends Equatable {
  const HomeUnit({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    this.titleEn,
    this.coverUrl,
    this.bookPages,
    this.stars,
    this.titleAudioUrl,
    this.lockedBy,
    this.preview,
    this.lessons = const [],
  });

  final String id;
  final int number;

  /// In Arabic; [titleEn] shows beside it for kids.
  final String title;
  final String? titleEn;
  final String? coverUrl;
  final UnitLessonStatus status;

  /// The unit's pages in the student's book (Emar).
  final ({int from, int to})? bookPages;

  /// Kids: the stars the unit earned, out of five.
  final int? stars;

  /// Kids: the unit's name, said by the guide.
  final String? titleAudioUrl;

  /// Locked: the unit to finish first.
  final UnitLink? lockedBy;

  /// Locked: what it teaches, for its preview sheet.
  final HomeUnitPreview? preview;

  /// The current unit's lessons; empty for every other unit.
  final List<HomeLesson> lessons;

  int get doneCount => lessons.where((lesson) => lesson.done).length;

  /// The lesson to do now; [lessons]`.length` once all are done.
  int get currentLesson => HomeRules.currentLessonIndex(lessons);

  bool isLast(int i) => i == lessons.length - 1;

  HomeUnit withPhone(LessonOnPhone Function(String lessonId) phone) =>
      lessons.isEmpty
      ? this
      : copyWith(lessons: [for (final l in lessons) l.withPhone(phone(l.id))]);

  HomeUnit copyWith({
    UnitLessonStatus? status,
    List<HomeLesson>? lessons,
    int? stars,
  }) => HomeUnit(
    id: id,
    number: number,
    title: title,
    status: status ?? this.status,
    titleEn: titleEn,
    coverUrl: coverUrl,
    bookPages: bookPages,
    stars: stars ?? this.stars,
    titleAudioUrl: titleAudioUrl,
    lockedBy: lockedBy,
    preview: preview,
    lessons: lessons ?? this.lessons,
  );

  @override
  List<Object?> get props => [
    id,
    number,
    title,
    titleEn,
    coverUrl,
    status,
    bookPages,
    stars,
    titleAudioUrl,
    lockedBy,
    preview,
    lessons,
  ];
}

/// A locked unit's preview, without fetching the unit.
final class HomeUnitPreview extends Equatable {
  const HomeUnitPreview({required this.goal, required this.lessons});

  /// What follows «ستتعلّم أن».
  final String goal;
  final List<HomePreviewLesson> lessons;

  /// The lessons' minutes to the nearest five: «نحو 40 دقيقة».
  int get roundedMinutes {
    final sum = lessons.fold(0, (total, lesson) => total + lesson.minutes);
    return (sum / 5).round() * 5;
  }

  @override
  List<Object?> get props => [goal, lessons];
}

final class HomePreviewLesson extends Equatable {
  const HomePreviewLesson({
    required this.kind,
    required this.title,
    this.minutes = 0,
  });

  final LessonKind kind;
  final String title;
  final int minutes;

  @override
  List<Object?> get props => [kind, title, minutes];
}

/// A stone: one lesson of the current unit, with what only home shows.
final class HomeLesson extends Equatable {
  const HomeLesson({
    required this.base,
    this.ai = false,
    this.levelCheck = false,
    this.questions,
  });

  /// The lesson as the unit's screen has it.
  final UnitLesson base;

  /// An AI conversation: ✦ and «محادثة ذكية».
  final bool ai;

  /// The unit's review is the level check: a gate, «فحص المستوى».
  final bool levelCheck;

  /// Questions in all, for «السؤال 3 من 6» when it was left off.
  final int? questions;

  String get id => base.id;
  LessonKind get kind => base.kind;
  String get title => base.title;
  int get minutes => base.minutes ?? 0;
  int? get page => base.page;
  bool get done => base.done;
  LessonResume? get resume => base.resume;

  /// It opens offline.
  bool get kept => base.kept;

  HomeLesson withPhone(LessonOnPhone phone) => HomeLesson(
    base: base.withPhone(phone),
    ai: ai,
    levelCheck: levelCheck,
    questions: questions,
  );

  @override
  List<Object?> get props => [base, ai, levelCheck, questions];
}

/// What is due for review today: «12 كلمة و3 مفاهيم، نحو 5 دقائق».
final class HomeReview extends Equatable {
  const HomeReview({
    required this.wordsDue,
    this.conceptsDue,
    this.minutes = 0,
  });

  final int wordsDue;

  /// Null while the mistakes' bank is off.
  final int? conceptsDue;
  final int minutes;

  int get total => wordsDue + (conceptsDue ?? 0);

  @override
  List<Object?> get props => [wordsDue, conceptsDue, minutes];
}

/// Cards the server offers between the header and the map.
final class HomeCards extends Equatable {
  const HomeCards({this.levelCheckLessonId, this.placementMinutes});

  /// The level check is available and not taken: «ابدأ الفحص» opens it.
  final String? levelCheckLessonId;

  /// The placement test was put off: «12 إلى 15 دقيقة».
  final ({int min, int max})? placementMinutes;

  @override
  List<Object?> get props => [levelCheckLessonId, placementMinutes];
}

/// A freeze used, or a streak ended, told once.
final class HomeEvent extends Equatable {
  const HomeEvent({
    required this.id,
    required this.kind,
    required this.on,
    required this.streak,
    this.freezesLeft,
  });

  final String id;
  final HomeEventKind kind;

  /// The learner's day it happened on.
  final DateTime on;

  /// The streak kept, or lost.
  final int streak;
  final int? freezesLeft;

  @override
  List<Object?> get props => [id, kind, on, streak, freezesLeft];
}
