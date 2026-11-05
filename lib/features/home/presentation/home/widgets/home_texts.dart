import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/domain/services/home_rules.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/kind_icon.dart';
import 'package:flutter/widgets.dart';

/// «5 دقائق».
String minutesText(int n) => 'unit_minutes'.plural(n);

/// A stone's chip: «قواعد», «فحص المستوى».
String kindShort(HomeLesson lesson) => switch (lesson.kind) {
  LessonKind.vocabulary => 'lesson_kind_vocabulary'.tr(),
  LessonKind.interactiveVideo => 'home_short_video'.tr(),
  LessonKind.grammarVideo => 'home_short_grammar'.tr(),
  LessonKind.interactiveText => 'home_short_text'.tr(),
  LessonKind.conversation => 'lesson_kind_conversation'.tr(),
  LessonKind.unitReview =>
    lesson.levelCheck
        ? 'home_check_title'.tr()
        : 'lesson_kind_unit_review'.tr(),
  LessonKind.other => 'lesson_kind_other'.tr(),
};

/// The kind in a lesson's line: «فيديو قواعد», «محادثة ذكية».
String kindLong(HomeLesson lesson) => switch (lesson.kind) {
  LessonKind.vocabulary => 'lesson_kind_vocabulary'.tr(),
  LessonKind.interactiveVideo => 'lesson_kind_interactive_video'.tr(),
  LessonKind.grammarVideo => 'home_kind_grammar_video'.tr(),
  LessonKind.interactiveText => 'lesson_kind_interactive_text'.tr(),
  LessonKind.conversation =>
    lesson.ai
        ? 'home_kind_ai_conversation'.tr()
        : 'lesson_kind_conversation'.tr(),
  LessonKind.unitReview => 'home_kind_test'.tr(),
  LessonKind.other => 'lesson_kind_other'.tr(),
};

/// «محادثة ذكية، 5 دقائق».
String lessonMeta(HomeLesson lesson) => 'unit_lesson_meta'.tr(
  namedArgs: {'kind': kindLong(lesson), 'minutes': minutesText(lesson.minutes)},
);

/// The lesson's kind as one icon across the app; the level check's gate.
Widget kindIcon(
  HomeLesson lesson, {
  required Color color,
  required double size,
}) => AppIconView(
  lesson.levelCheck ? AppIcon.levelGate : lessonKindIcon(lesson.kind),
  color: color,
  size: size,
);

/// The streak kept by a lesson: «يومك», «يوميك», «أيامك السبعة», «أيامك الـ12»
/// (D14).
String yourDays(int n) {
  if (n == 1) return 'home_your_day'.tr();
  if (n == 2) return 'home_your_two_days'.tr();
  final word = switch (n) {
    3 => 'home_word_3'.tr(),
    4 => 'home_word_4'.tr(),
    5 => 'home_word_5'.tr(),
    6 => 'home_word_6'.tr(),
    7 => 'home_word_7'.tr(),
    8 => 'home_word_8'.tr(),
    9 => 'home_word_9'.tr(),
    10 => 'home_word_10'.tr(),
    _ => 'home_word_numeral'.tr(args: ['$n']),
  };
  return 'home_your_days'.tr(args: [word]);
}

/// «7 أيام».
String daysText(int n) => 'home_days'.plural(n);

/// «الوحدة 3 · يوم في المزرعة».
String unitTitle(HomeUnit unit) => 'home_isle_title'.tr(
  namedArgs: {'number': '${unit.number}', 'name': unit.title},
);

/// «12 كلمة و3 مفاهيم، نحو 5 دقائق»; one part when the other is nothing.
String reviewLine(HomeReview review) {
  final minutes = minutesText(review.minutes);
  final concepts = review.conceptsDue ?? 0;
  if (review.wordsDue > 0 && concepts > 0) {
    return 'home_review_line'.tr(
      namedArgs: {
        'words': 'home_review_words'.plural(review.wordsDue),
        'concepts': 'home_review_concepts'.plural(concepts),
        'minutes': minutes,
      },
    );
  }
  return 'home_review_line_single'.tr(
    namedArgs: {
      'items': review.wordsDue > 0 || concepts == 0
          ? 'home_review_words'.plural(review.wordsDue)
          : 'home_review_concepts'.plural(concepts),
      'minutes': minutes,
    },
  );
}

/// The level header's title: «A2، ما قبل المتوسط»; a grade by its name,
/// «الصف السابع».
String levelTitle(HomeSnapshot home) {
  final level = home.level;
  if (home.enrollment.levelLabel == HomeLevelLabel.grade &&
      level.name.isNotEmpty) {
    return level.name;
  }
  if (level.name.isEmpty) return level.label;
  return 'home_level_title'.tr(
    namedArgs: {'label': level.label, 'name': level.name},
  );
}

/// The greeting; [spoken] drops the comma, for the screen reader's group.
String greetingText(
  HomeGreeting greeting,
  String name, {
  bool spoken = false,
}) => switch (greeting) {
  HomeGreeting.kids => 'home_kid_hello'.tr(args: [name]),
  HomeGreeting.firstDay => 'home_greet_first'.tr(args: [name]),
  HomeGreeting.back => 'home_greet_back'.tr(args: [name]),
  HomeGreeting.morning =>
    spoken
        ? 'home_greet_morning_spoken'.tr(args: [name])
        : 'home_greet_morning'.tr(args: [name]),
  HomeGreeting.evening =>
    spoken
        ? 'home_greet_evening_spoken'.tr(args: [name])
        : 'home_greet_evening'.tr(args: [name]),
};

/// The line under the greeting: «3 دقائق وتحقق هدف اليوم».
String statusText(HomeStatus status) => switch (status.kind) {
  HomeStatusKind.next => 'home_status_next'.tr(),
  HomeStatusKind.firstLesson => 'home_status_first'.tr(),
  HomeStatusKind.goalReached => 'home_status_goal'.tr(),
  HomeStatusKind.minutesLeft => 'home_status_left'.tr(
    args: [minutesText(status.minutesLeft)],
  ),
};

/// The evening's line instead: «5 دقائق تحافظ على أيامك السبعة».
String riskText(int minutesLeft, int streak) => 'home_risk'.tr(
  namedArgs: {'minutes': minutesText(minutesLeft), 'days': yourDays(streak)},
);
