import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/entities/home_moment.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/entities/unit_plan.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:equatable/equatable.dart';

/// The greeting's line, first match wins (design "Home Archipelago").
enum HomeGreeting { kids, firstDay, back, morning, evening }

enum HomeStatusKind { next, firstLesson, goalReached, minutesLeft }

/// The line under the greeting, with the minutes left to today's goal.
typedef HomeStatus = ({HomeStatusKind kind, int minutesLeft});

/// The strip under the top bar.
enum HomeTopNotice { none, email, offline, refreshFailed }

/// The card between the header and the map.
enum HomeCardNotice { none, freeze, broke, levelDone, levelCheck, placement }

/// What the notice area shows: one card at most, and the strip; [event] is
/// the one-time notice behind a freeze or broke card.
typedef HomeNotices = ({
  HomeTopNotice top,
  HomeCardNotice card,
  HomeEvent? event,
});

/// Where a page of the student's book is (Emar's page search).
sealed class PageHit extends Equatable {
  const PageHit(this.unitIndex);

  /// A lesson of the current unit.
  const factory PageHit.lesson(int unitIndex, int lessonIndex) = PageLessonHit;

  /// Another unit.
  const factory PageHit.unit(int unitIndex) = PageUnitHit;

  final int unitIndex;

  @override
  List<Object?> get props => [unitIndex];
}

final class PageLessonHit extends PageHit {
  const PageLessonHit(super.unitIndex, this.lessonIndex);

  final int lessonIndex;

  @override
  List<Object?> get props => [unitIndex, lessonIndex];
}

final class PageUnitHit extends PageHit {
  const PageUnitHit(super.unitIndex);
}

/// Home's rules, from its data and the clock. Pure, so every frame of the
/// design can be checked without a screen.
abstract final class HomeRules {
  /// ASSUMPTION(design): «صباح الخير» until noon and the streak at risk from
  /// 18:00 are product constants, not panel settings (D-096).
  static const morningUntilHour = 12;
  static const riskFromHour = 18;

  /// When the learner's day starts before home has data of its own: the
  /// contract's default (docs/api/README.md, Times).
  static const defaultDayStart = '04:00';

  /// The kept one-time notices.
  static const seenEventsKept = 20;

  /// The learner's day [now] belongs to, as `yyyy-mm-dd`: a day that starts
  /// at [dayStart] («04:00») still counts as yesterday before it.
  static String dayKey(DateTime now, String dayStart) {
    final parts = dayStart.split(':');
    final hours = int.tryParse(parts.first.trim()) ?? 0;
    final minutes = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    return _dateKey(now.subtract(Duration(hours: hours, minutes: minutes)));
  }

  static String _dateKey(DateTime day) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${day.year.toString().padLeft(4, '0')}-'
        '${two(day.month)}-${two(day.day)}';
  }

  /// [week] with today where the phone's clock has it (A30): once the
  /// learner's day is past the server's «today», today is the day of that
  /// date, or none of [StudyWeek.days] (`today` is then their length), with
  /// no minutes yet. Never back: a phone's clock behind the server's day
  /// doesn't undo it.
  static StudyWeek rollOver(StudyWeek week, DateTime now) {
    final days = week.days;
    if (week.today >= days.length) return week;
    final today = dayKey(
      now,
      week.dayStart.isEmpty ? defaultDayStart : week.dayStart,
    );
    if (_dateKey(days[week.today].date).compareTo(today) >= 0) return week;
    final index = days.indexWhere((day) => _dateKey(day.date) == today);
    return StudyWeek(
      goalMinutes: week.goalMinutes,
      days: days,
      today: index < 0 ? days.length : index,
      dayStart: week.dayStart,
    );
  }

  /// [home] on the learner's day of [now]: its week rolled over on the
  /// phone ([rollOver]), so today's minutes, the ring and the risk move on
  /// without a fetch.
  static HomeSnapshot asOf(HomeSnapshot home, DateTime now) {
    final week = home.week;
    if (week == null) return home;
    final rolled = rollOver(week, now);
    return identical(rolled, week) ? home : home.copyWith(week: () => rolled);
  }

  /// The first lesson not done; a unit review only once all the others are.
  /// [lessons]`.length` when every lesson is done.
  static int currentLessonIndex(List<HomeLesson> lessons) {
    final othersDone = lessons.every(
      (lesson) => lesson.done || lesson.kind == LessonKind.unitReview,
    );
    for (final (index, lesson) in lessons.indexed) {
      if (lesson.done) continue;
      if (lesson.kind == LessonKind.unitReview && !othersDone) continue;
      return index;
    }
    return lessons.length;
  }

  static HomeGreeting greeting(HomeSnapshot home, DateTime now) {
    if (home.kids) return HomeGreeting.kids;
    if (home.learner.lessonsDone == 0) return HomeGreeting.firstDay;
    if (home.learner.welcomeBack) return HomeGreeting.back;
    if (now.hour < morningUntilHour) return HomeGreeting.morning;
    return HomeGreeting.evening;
  }

  static HomeStatus status(HomeSnapshot home) {
    final left = home.goalMinutes - home.todayMinutes;
    final minutesLeft = left < 0 ? 0 : left;
    final kind = home.v01
        ? HomeStatusKind.next
        : home.learner.lessonsDone == 0
        ? HomeStatusKind.firstLesson
        : home.todayMinutes >= home.goalMinutes
        ? HomeStatusKind.goalReached
        : HomeStatusKind.minutesLeft;
    return (kind: kind, minutesLeft: minutesLeft);
  }

  /// The streak can still be kept today, and the evening has come (D15).
  static bool atRisk(HomeSnapshot home, DateTime now) =>
      !home.kids &&
      !home.v01 &&
      now.hour >= riskFromHour &&
      (home.streak?.current ?? 0) > 0 &&
      home.todayMinutes < home.goalMinutes;

  /// How much of an island's colour shows: done 1, locked 0, open .15, the
  /// current one by its share of lessons done (D7).
  static double saturation(HomeUnit unit, {int? doneOverride}) {
    switch (unit.status) {
      case UnitLessonStatus.done:
        return 1;
      case UnitLessonStatus.locked:
        return 0;
      case UnitLessonStatus.open:
        return .15;
      case UnitLessonStatus.current:
        final n = unit.lessons.length;
        if (n == 0) return .15;
        final share = (doneOverride ?? unit.doneCount) / n;
        return share < .15 ? .15 : (share > 1 ? 1 : share);
    }
  }

  /// Units done: those before the current one, and the current one once its
  /// every lesson is; every done unit when none is current.
  static int unitsDone(HomeSnapshot home) {
    final current = home.currentUnitIndex;
    final count = home.units.length;
    if (current < 0) {
      return home.units
          .where((unit) => unit.status == UnitLessonStatus.done)
          .length;
    }
    final lessons = home.units[current].lessons;
    final finished = lessons.isNotEmpty && lessons.every((l) => l.done);
    final done = current + (finished ? 1 : 0);
    return done > count ? count : done;
  }

  /// Back after a while with something due: the review is the path's first
  /// station, before the current stone.
  static bool reviewFirst(HomeSnapshot home) =>
      home.learner.welcomeBack &&
      (home.review?.total ?? 0) > 0 &&
      !home.kids &&
      !home.v01 &&
      home.currentUnit != null;

  /// The review box floats in the sea.
  static bool reviewBox(HomeSnapshot home) =>
      (home.review?.total ?? 0) > 0 &&
      !reviewFirst(home) &&
      !home.kids &&
      !home.v01 &&
      home.currentUnit != null;

  /// One card at most, by priority (D13): a one-time notice not [seen], the
  /// level done, the email (a strip), the level check, the deferred test.
  /// A connection strip takes the top slot; the email then waits.
  static HomeNotices notices(
    HomeSnapshot home, {
    required Set<String> seen,
    required bool emailReminder,
    required bool offline,
    required bool refreshFailed,
  }) {
    HomeEvent? event;
    if (!home.kids) {
      for (final candidate in home.events) {
        if (!seen.contains(candidate.id)) {
          event = candidate;
          break;
        }
      }
    }
    final email = emailReminder && !home.kids && home.learner.lessonsDone >= 1;
    final card = event != null
        ? (event.kind == HomeEventKind.freezeUsed
              ? HomeCardNotice.freeze
              : HomeCardNotice.broke)
        : home.level.completed && home.level.next != null
        ? HomeCardNotice.levelDone
        : email
        ? HomeCardNotice.none
        : home.cards.levelCheckLessonId != null
        ? HomeCardNotice.levelCheck
        : home.cards.placementMinutes != null
        ? HomeCardNotice.placement
        : HomeCardNotice.none;
    final emailWins =
        event == null &&
        !(home.level.completed && home.level.next != null) &&
        email;
    final top = refreshFailed
        ? HomeTopNotice.refreshFailed
        : offline
        ? HomeTopNotice.offline
        : emailWins
        ? HomeTopNotice.email
        : HomeTopNotice.none;
    return (top: top, card: card, event: event);
  }

  /// The page typed, as Latin digits: digits only (Arabic-Indic ones read as
  /// Latin), at most three.
  static String pageDigits(String input) {
    final digits = StringBuffer();
    for (final rune in input.runes) {
      if (digits.length == 3) break;
      if (rune >= _zero && rune <= _zero + 9) {
        digits.writeCharCode(rune);
      } else if (rune >= _arabicZero && rune <= _arabicZero + 9) {
        digits.writeCharCode(rune - _arabicZero + _zero);
      }
    }
    return digits.toString();
  }

  /// The page number typed; null when empty or 0.
  static int? parsePage(String input) {
    final page = int.tryParse(pageDigits(input));
    return page == null || page == 0 ? null : page;
  }

  static const _zero = 0x30;
  static const _arabicZero = 0x0660;

  /// The book's pages, from the first unit's to the last's.
  static ({int from, int to})? bookRange(HomeSnapshot home) {
    final pages = [for (final unit in home.units) ?unit.bookPages];
    if (pages.isEmpty) return null;
    return (from: pages.first.from, to: pages.last.to);
  }

  /// The unit whose pages hold [page] (A8); in the current unit, the last
  /// lesson that starts at or before it.
  static PageHit? findPage(HomeSnapshot home, int page) {
    for (final (index, unit) in home.units.indexed) {
      final pages = unit.bookPages;
      if (pages == null || page < pages.from || page > pages.to) continue;
      if (index != home.currentUnitIndex) return PageHit.unit(index);
      int? lesson;
      for (final (k, item) in unit.lessons.indexed) {
        final start = item.page;
        if (start != null && start <= page) lesson = k;
      }
      return lesson == null
          ? PageHit.unit(index)
          : PageHit.lesson(index, lesson);
    }
    return null;
  }

  /// What to celebrate between [before] and [after] (a return from a
  /// lesson); null for a plain swap: another track or level, nothing new, or
  /// more than one lesson done at once.
  static HomeMoment? diff(HomeSnapshot before, HomeSnapshot after) {
    if (before.enrollment.id != after.enrollment.id ||
        before.level.id != after.level.id) {
      return null;
    }
    final b = before.currentUnit;
    if (b == null) return null;
    final unitIndex = before.currentUnitIndex;
    final minutesFrom = before.todayMinutes;
    final minutesTo = after.todayMinutes;
    final goal = after.goalMinutes;
    final streakFrom = before.streak?.current ?? 0;
    final streakTo = after.streak?.current ?? 0;
    final a = after.currentUnit;
    final levelDone = after.level.completed && !before.level.completed;
    if (a != null && a.id == b.id) {
      final wasDone = {
        for (final lesson in b.lessons)
          if (lesson.done) lesson.id,
      };
      final newly = {
        for (final lesson in a.lessons)
          if (lesson.done && !wasDone.contains(lesson.id)) lesson.id,
      };
      final current = b.currentLesson;
      if (newly.length != 1 ||
          current >= b.lessons.length ||
          newly.single != b.lessons[current].id) {
        return null;
      }
      if (a.currentLesson >= a.lessons.length) {
        return UnitDoneMoment(
          before: before,
          after: after,
          unit: unitIndex,
          nextUnit: null,
          levelDone: levelDone,
          minutesFrom: minutesFrom,
          minutesTo: minutesTo,
          goal: goal,
          streakFrom: streakFrom,
          streakTo: streakTo,
        );
      }
      return LessonDoneMoment(
        before: before,
        after: after,
        lesson: current,
        next: a.currentLesson,
        minutesFrom: minutesFrom,
        minutesTo: minutesTo,
        goal: goal,
        streakFrom: streakFrom,
        streakTo: streakTo,
      );
    }
    final finished = after.units.indexWhere((unit) => unit.id == b.id);
    if (finished < 0 || after.units[finished].status != UnitLessonStatus.done) {
      return null;
    }
    final next = after.currentUnitIndex;
    return UnitDoneMoment(
      before: before,
      after: after,
      unit: unitIndex,
      nextUnit: next < 0 ? null : next,
      levelDone: levelDone,
      minutesFrom: minutesFrom,
      minutesTo: minutesTo,
      goal: goal,
      streakFrom: streakFrom,
      streakTo: streakTo,
    );
  }
}
