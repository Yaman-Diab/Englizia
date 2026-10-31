import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';

/// Each kind of lesson has one icon across the app (S §8).
AppIcon lessonKindIcon(LessonKind kind) => switch (kind) {
  LessonKind.vocabulary => AppIcon.lessonVocabulary,
  LessonKind.interactiveVideo => AppIcon.lessonInteractiveVideo,
  LessonKind.grammarVideo => AppIcon.lessonGrammarVideo,
  LessonKind.interactiveText => AppIcon.lessonInteractiveText,
  LessonKind.conversation => AppIcon.lessonConversation,
  LessonKind.unitReview => AppIcon.lessonReview,
  LessonKind.other => AppIcon.book,
};

String lessonKindName(LessonKind kind) => switch (kind) {
  LessonKind.vocabulary => 'lesson_kind_vocabulary'.tr(),
  LessonKind.interactiveVideo => 'lesson_kind_interactive_video'.tr(),
  LessonKind.grammarVideo => 'lesson_kind_grammar_video'.tr(),
  LessonKind.interactiveText => 'lesson_kind_interactive_text'.tr(),
  LessonKind.conversation => 'lesson_kind_conversation'.tr(),
  LessonKind.unitReview => 'lesson_kind_unit_review'.tr(),
  LessonKind.other => 'lesson_kind_other'.tr(),
};
