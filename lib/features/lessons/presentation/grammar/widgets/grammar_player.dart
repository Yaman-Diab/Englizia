import 'package:englizia/features/lessons/presentation/grammar/cubit/grammar_lesson_cubit.dart';
import 'package:englizia/features/lessons/presentation/video/lesson_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The grammar lesson's player, following its cubit.
class GrammarPlayer extends StatelessWidget {
  const GrammarPlayer({
    required this.fullscreen,
    required this.onToggleFullscreen,
    super.key,
  });

  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<GrammarLessonCubit, GrammarLessonState>(
        builder: (context, state) => LessonPlayer(
          state: state,
          actions: context.read<GrammarLessonCubit>(),
          fullscreen: fullscreen,
          onToggleFullscreen: onToggleFullscreen,
        ),
      );
}
