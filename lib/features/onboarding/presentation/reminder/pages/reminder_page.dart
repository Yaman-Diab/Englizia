import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/onboarding/domain/entities/onboarding_steps.dart';
import 'package:englizia/features/onboarding/presentation/reminder/cubit/reminder_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reminder/cubit/reminder_state.dart';
import 'package:englizia/features/onboarding/presentation/reminder/widgets/reminder_preview.dart';
import 'package:englizia/features/onboarding/presentation/reminder/widgets/reminder_time_sheet.dart';
import 'package:englizia/features/onboarding/presentation/widgets/loaded_answers.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_option.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_question_scaffold.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding "when should we remind you?" (requirements v3.0 §4.2, in v1.0
/// per §27, built ahead of plan). A configured time or the learner's own,
/// with a preview of the reminder. The phone isn't asked here: the
/// reminders' prompt after the first lesson does (design "Notifications").
class ReminderPage extends StatefulWidget {
  const ReminderPage({
    required this.path,
    required this.onContinue,
    required this.onBack,
    super.key,
  });

  /// The branch the learner is on, for the progress bar.
  final OnboardingPath path;

  /// The chosen time, or null for no reminder.
  final ValueChanged<ReminderTime?> onContinue;
  final VoidCallback onBack;

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  void _enable() => widget.onContinue(context.read<ReminderCubit>().state.time);

  Future<void> _pickTime(ReminderState state) async {
    final cubit = context.read<ReminderCubit>();
    final initial =
        state.custom ?? state.time ?? state.settings!.defaultPreset.time;
    final time = await showReminderTimeSheet(context, initial: initial);
    if (time != null) cubit.setCustom(time);
  }

  @override
  Widget build(BuildContext context) {
    final position = onboardingPosition(
      OnboardingStep.reminder,
      path: widget.path,
    );
    final languageCode = context.locale.languageCode;
    return BlocBuilder<ReminderCubit, ReminderState>(
      builder: (context, state) {
        final cubit = context.read<ReminderCubit>();
        final settings = state.settings;
        final time = state.time;
        return OnboardingQuestionScaffold(
          question: 'onboarding_reminder_question'.tr(),
          expression: MascotExpression.welcome,
          step: position.current,
          totalSteps: position.total,
          lead: settings == null || time == null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReminderPreview(
                      time: formatClock(time.hour, time.minute),
                      title: settings.title.of(languageCode),
                      body: settings.bodyIn(
                        languageCode,
                        goalMinutes:
                            widget.path.dailyGoalMinutes ??
                            state.defaultGoalMinutes ??
                            0,
                      ),
                    ),
                  ],
                ),
          options: loadedAnswers(
            status: state.status,
            failure: state.failure,
            onRetry: cubit.load,
            ready: () => [
              for (final preset in settings!.presets)
                OnboardingOption(
                  icon: _icon(preset.slot),
                  iconTone: TileTone.neutral,
                  inline: true,
                  title: _title(preset.slot),
                  description: formatClock(
                    preset.time.hour,
                    preset.time.minute,
                  ),
                  selected: !state.useCustom && state.slot == preset.slot,
                  onTap: () => cubit.choose(preset.slot),
                ),
              OnboardingOption(
                icon: AppIcon.clock,
                iconTone: TileTone.neutral,
                inline: true,
                title: 'onboarding_reminder_other'.tr(),
                description: switch (state.custom) {
                  final custom? => formatClock(custom.hour, custom.minute),
                  null => 'onboarding_reminder_pick'.tr(),
                },
                selected: state.useCustom,
                onTap: () => _pickTime(state),
              ),
            ],
          ),
          continueLabel: 'onboarding_reminder_enable'.tr(),
          onContinue: switch (state) {
            ReminderState(status: LoadStatus.ready, canEnable: true) => _enable,
            _ => null,
          },
          secondaryLabel: 'onboarding_reminder_skip'.tr(),
          onSecondary: () => widget.onContinue(null),
          onBack: widget.onBack,
        );
      },
    );
  }

  static AppIcon _icon(ReminderSlot slot) => switch (slot) {
    ReminderSlot.morning => AppIcon.sunrise,
    ReminderSlot.noon => AppIcon.sun,
    ReminderSlot.evening => AppIcon.moon,
  };

  static String _title(ReminderSlot slot) => switch (slot) {
    ReminderSlot.morning => 'onboarding_reminder_morning'.tr(),
    ReminderSlot.noon => 'onboarding_reminder_noon'.tr(),
    ReminderSlot.evening => 'onboarding_reminder_evening'.tr(),
  };
}
