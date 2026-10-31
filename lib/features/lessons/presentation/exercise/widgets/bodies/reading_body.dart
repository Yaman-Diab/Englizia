import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/slide_swap.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/bodies/body_props.dart';
import 'package:englizia/features/lessons/presentation/exercise/widgets/shared/answer_card.dart';
import 'package:flutter/material.dart';

/// A question about the text pinned above it. Only this part moves between the
/// text's questions: the text stays where the learner left it (S §7.3).
class ReadingBody extends StatelessWidget {
  const ReadingBody({required this.exercise, required this.answer, super.key});

  final ReadingExercise exercise;
  final BodyAnswer answer;

  @override
  Widget build(BuildContext context) => SlideSwap(
    child: KeyedSubtree(
      key: ValueKey(exercise.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'lesson_reading_step'.tr(
              namedArgs: {
                'step': '${exercise.step}',
                'steps': '${exercise.steps}',
              },
            ),
            style: context.texts.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            exercise.ask,
            locale: const Locale('en'),
            textDirection: TextDirection.ltr,
            style: context.texts.bodyStrong.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextAnswers(options: exercise.options, answer: answer),
        ],
      ),
    ),
  );
}
