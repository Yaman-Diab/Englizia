import 'package:englizia/app/router/lesson_paths.dart';
import 'package:englizia/features/lessons/data/models/lesson_result_model.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a lesson opens by its kind', () {
    test('each of the five kinds on its own screen', () {
      expect(
        lessonPath(id: 'l1', kind: LessonKind.vocabulary),
        '/lessons/l1/vocabulary',
      );
      expect(
        lessonPath(id: 'l1', kind: LessonKind.grammarVideo),
        '/lessons/l1/grammar',
      );
      expect(
        lessonPath(id: 'l1', kind: LessonKind.interactiveText),
        '/lessons/l1/text',
      );
      expect(
        lessonPath(id: 'l1', kind: LessonKind.interactiveVideo),
        '/lessons/l1/video',
      );
      expect(
        lessonPath(
          id: 'l1',
          kind: LessonKind.conversation,
          scenarioId: 'sc_fragile_box',
        ),
        '/talk/scenarios/sc_fragile_box',
      );
    });

    test('a conversation naming no scenario, a review, an unknown kind: '
        'its exercises', () {
      for (final kind in [
        LessonKind.conversation,
        LessonKind.unitReview,
        LessonKind.other,
      ]) {
        expect(lessonPath(id: 'l1', kind: kind), '/lessons/l1/exercises');
      }
    });

    test('in kids mode every kind opens the kids\' screens', () {
      expect(
        lessonPath(
          id: 'l1',
          kind: LessonKind.conversation,
          scenarioId: 'sc',
          kids: true,
        ),
        '/lessons/l1/kids',
      );
    });
  });

  test('a lesson\'s end reads the next conversation\'s scenario', () {
    final outline = lessonOutlineFromJson(const {
      'title': 'Shopping',
      'next': {
        'kind': 'lesson',
        'lessonId': 'les_chat_box',
        'lessonKind': 'conversation',
        'scenarioId': 'sc_fragile_box',
        'title': 'الصندوق القابل للكسر',
      },
    });

    final next = outline.next!;
    expect(next.lessonKind, LessonKind.conversation);
    expect(next.scenarioId, 'sc_fragile_box');
    // The end of a lesson opens it where home and the unit would.
    expect(
      lessonPath(
        id: next.lessonId!,
        kind: next.lessonKind,
        scenarioId: next.scenarioId,
      ),
      '/talk/scenarios/sc_fragile_box',
    );
  });
}
