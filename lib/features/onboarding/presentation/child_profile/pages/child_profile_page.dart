import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/widgets/choice_surface.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/child_profile/cubit/child_profile_cubit.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding "tell us about your child" (requirements v3.0 §4.2; a v0.5
/// step built ahead of plan): the child's name with a live greeting, and the
/// age. Wording never assumes the child's gender (§4.5).
class ChildProfilePage extends StatefulWidget {
  const ChildProfilePage({
    required this.path,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  final ValueChanged<ChildProfileState> onContinue;
  final VoidCallback onBack;

  /// The branch the learner is on, for the progress bar.
  final OnboardingPath path;

  @override
  State<ChildProfilePage> createState() => _ChildProfilePageState();
}

class _ChildProfilePageState extends State<ChildProfilePage> {
  final _name = TextEditingController();

  static const _nameMaxLength = 20;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = onboardingPosition(
      OnboardingStep.childProfile,
      path: widget.path,
    );
    final texts = context.texts;
    final colors = context.colors;

    return BlocBuilder<ChildProfileCubit, ChildProfileState>(
      builder: (context, state) {
        final cubit = context.read<ChildProfileCubit>();
        return OnboardingQuestionScaffold(
          question: 'onboarding_child_question'.tr(),
          expression: MascotExpression.happy,
          mascotSize: OnboardingQuestionScaffold.playfulMascotSize,
          step: position.current,
          totalSteps: position.total,
          helper: 'onboarding_child_helper'.tr(),
          helperIcon: Icons.lock_outline_rounded,
          helperIsInfo: true,
          continueLabel: 'common_continue'.tr(),
          onContinue: state.canContinue ? () => widget.onContinue(state) : null,
          onBack: widget.onBack,
          options: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'onboarding_child_name_label'.tr(),
                  style: texts.captionStrong.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _name,
                  onChanged: cubit.setName,
                  maxLength: _nameMaxLength,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: texts.title,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'onboarding_child_name_label'.tr(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Greeting(name: state.displayName),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'onboarding_child_age_question'.tr(),
                  style: texts.bodyStrong,
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Row(
                  children: [
                    for (final (i, age) in childAges.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _AgePill(
                          age: age,
                          selected: state.age == age,
                          onTap: () => cubit.setAge(age),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// "مرحبًا [الاسم]!" as the child will see it, updated while typing.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  static const _minHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _minHeight),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + AppSpacing.xxs,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.selectionSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          name.isEmpty
              ? 'onboarding_child_greeting_empty'.tr()
              : 'onboarding_child_greeting'.tr(namedArgs: {'name': name}),
          textAlign: TextAlign.center,
          style: context.texts.display.copyWith(color: colors.selection),
        ),
      ),
    );
  }
}

class _AgePill extends StatelessWidget {
  const _AgePill({
    required this.age,
    required this.selected,
    required this.onTap,
  });

  final int age;
  final bool selected;
  final VoidCallback onTap;

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ChoiceSurface(
      selected: selected,
      onTap: onTap,
      shape: ChoiceShape.pill,
      semanticLabel: 'onboarding_child_age_label'.tr(
        namedArgs: {'age': '$age'},
      ),
      child: SizedBox(
        height: _height,
        child: Center(
          child: Text(
            '$age',
            style: context.texts.bodyStrong.copyWith(
              color: selected ? colors.onPrimaryStrong : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
