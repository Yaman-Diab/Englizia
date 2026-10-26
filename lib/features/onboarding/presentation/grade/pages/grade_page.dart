import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_cubit.dart';
import 'package:englizia/features/onboarding/presentation/grade/cubit/grade_state.dart';
import 'package:englizia/features/onboarding/presentation/grade/widgets/grade_cell.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding "which grade are you in?" for school students (requirements
/// v3.0 §4.2, in v0.1 per §27). Grades and their groups come from the
/// published curriculum track, never from the app.
class GradePage extends StatelessWidget {
  const GradePage({required this.onContinue, required this.onBack, super.key});

  final ValueChanged<TrackLevel> onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final position = onboardingPosition(
      OnboardingStep.grade,
      audience: TrackAudience.schoolStudent,
    );
    return BlocBuilder<GradeCubit, GradeState>(
      builder: (context, state) {
        final cubit = context.read<GradeCubit>();
        return OnboardingQuestionScaffold(
          question: 'onboarding_grade_question'.tr(),
          expression: MascotExpression.curious,
          step: position.current,
          totalSteps: position.total,
          continueLabel: 'common_continue'.tr(),
          onContinue: state.canContinue
              ? () => onContinue(state.selected!)
              : null,
          onBack: onBack,
          options: switch (state.status) {
            GradeStatus.loading => const [
              Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  vertical: AppSpacing.xxl,
                ),
                child: AppStateView.loading(),
              ),
            ],
            GradeStatus.failure => [
              AppStateView.error(
                message: state.failure!.localizedMessage,
                onRetry: cubit.load,
              ),
            ],
            GradeStatus.ready => [
              for (final group in state.groups)
                _GradeSection(
                  group: group,
                  selected: state.selected,
                  onSelect: cubit.select,
                ),
            ],
          },
        );
      },
    );
  }
}

class _GradeSection extends StatelessWidget {
  const _GradeSection({
    required this.group,
    required this.selected,
    required this.onSelect,
  });

  final GradeGroup group;
  final TrackLevel? selected;
  final ValueChanged<TrackLevel> onSelect;

  static const _columns = 3;

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;
    final rows = [
      for (var i = 0; i < group.levels.length; i += _columns)
        group.levels.sublist(i, (i + _columns).clamp(0, group.levels.length)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (group.title case final title?) ...[
          Row(
            children: [
              Text(
                title.of(languageCode),
                style: context.texts.captionStrong.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var c = 0; c < _columns; c++) ...[
                if (c > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: c < row.length
                      ? GradeCell(
                          number: row[c].schoolGrade ?? row[c].order,
                          label: row[c].name.of(languageCode),
                          selected: row[c] == selected,
                          onTap: () => onSelect(row[c]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
