import 'package:englizia/core/audio/clip_playback.dart';
import 'package:englizia/features/lessons/domain/entities/exercise_answer.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_card.dart';
import 'package:flutter/services.dart';

/// What a template's body gets of the answer. Bodies don't read the session's
/// cubit, so another session can show them too (S §11.2: concept reviews).
final class BodyAnswer {
  const BodyAnswer({
    required this.draft,
    required this.evaluation,
    required this.onDraft,
    required this.onSubmit,
  });

  final ExerciseDraft? draft;
  final Evaluation? evaluation;
  final ValueChanged<ExerciseDraft> onDraft;

  /// Checks the answer, for a body with no «تحقق» under it.
  final VoidCallback onSubmit;

  /// How the option [id] of a choice looks now.
  AnswerLook lookOf(String id) {
    if (evaluation case ChoiceEvaluation(:final chosenId, :final rightId)) {
      if (id == rightId) return AnswerLook.correct;
      return id == chosenId ? AnswerLook.wrong : AnswerLook.dimmed;
    }
    return draft == ChoiceDraft(id) ? AnswerLook.selected : AnswerLook.idle;
  }

  /// Chooses the option [id], with a light haptic; null once it is checked.
  VoidCallback? chooser(String id) => evaluation != null
      ? null
      : () {
          HapticFeedback.selectionClick();
          onDraft(ChoiceDraft(id));
        };
}

/// What a template's body gets of the question's clip.
final class BodyClip {
  const BodyClip({
    required this.status,
    required this.slow,
    required this.length,
    required this.playCount,
    required this.onToggle,
    required this.onSlow,
    required this.onStop,
  });

  final ClipStatus status;
  final bool slow;
  final Duration length;
  final int playCount;
  final VoidCallback onToggle;
  final VoidCallback onSlow;
  final VoidCallback onStop;

  bool get playingSlow => status == ClipStatus.playing && slow;
}
