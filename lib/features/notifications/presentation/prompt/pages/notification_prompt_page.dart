import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/features/notifications/presentation/prompt/cubit/notification_prompt_cubit.dart';
import 'package:englizia/features/onboarding/presentation/reminder/widgets/reminder_time_sheet.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «نذكّرك بدرسك؟» (design "Notifications" 06–08, "Notif Prompt Form"):
/// once, after the first lesson's end. The guide with a bell, when to remind
/// (the panel's morning and evening, or «وقت آخر» on the wheel sheet), then
/// «فعّل التذكيرات» and the phone's own question. «ليس الآن» at the top and
/// the bottom do the same. A child's version is a size larger, with its
/// question read out.
class NotificationPromptPage extends StatefulWidget {
  const NotificationPromptPage({
    required this.kids,
    required this.onDone,
    super.key,
  });

  final bool kids;

  /// Answered, or put off: the prompt closes.
  final VoidCallback onDone;

  @override
  State<NotificationPromptPage> createState() => _NotificationPromptPageState();
}

class _NotificationPromptPageState extends State<NotificationPromptPage> {
  /// ×1.25 for a child (design 08).
  double get _k => widget.kids ? 1.25 : 1;

  @override
  void initState() {
    super.initState();
    if (widget.kids) _speak();
  }

  void _speak() => context.read<NotificationPromptCubit>().speak();

  Future<void> _pickTime(NotificationPromptState state) async {
    final cubit = context.read<NotificationPromptCubit>();
    final time = await showReminderTimeSheet(
      context,
      initial: state.custom ?? state.evening ?? state.morning ?? _fallbackTime,
    );
    if (time != null) cubit.setCustom(time);
  }

  /// Where the wheel starts with no time to start from (design: 9:30 م).
  static const _fallbackTime = ReminderTime(21, 30);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return BlocConsumer<NotificationPromptCubit, NotificationPromptState>(
      listenWhen: (before, now) => !before.finished && now.finished,
      listener: (_, _) => widget.onDone(),
      builder: (context, state) {
        final cubit = context.read<NotificationPromptCubit>();
        final skip = state.asking || state.finished ? null : cubit.skip;
        final skipLabel = Text('notification_prompt_skip'.tr());
        // Back is «ليس الآن»: the prompt closes once it counted.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (popped, _) {
            if (!popped && !state.asking) unawaited(cubit.skip());
          },
          child: Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: widget.kids ? 72 : 56,
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: widget.kids ? AppSpacing.md : AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          if (widget.kids)
                            KidRoundButton(
                              info: true,
                              size: 56,
                              label: 'notification_prompt_listen'.tr(),
                              icon: AppIconView(
                                AppIcon.volume,
                                size: 28,
                                color: colors.surface,
                              ),
                              onPressed: _speak,
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: skip,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.primary.text,
                              minimumSize: Size(0, widget.kids ? 56 : 44),
                              textStyle: texts.captionStrong.copyWith(
                                fontSize: widget.kids ? 17 : 14,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: skipLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: EdgeInsetsDirectional.symmetric(
                          horizontal: widget.kids ? 20 : AppSpacing.xl,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: _content(context, state),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, NotificationPromptState state) {
    final colors = context.colors;
    final texts = context.texts;
    final cubit = context.read<NotificationPromptCubit>();
    final kids = widget.kids;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: kids ? 0 : AppSpacing.md),
        Center(child: _Hero(kids: kids)),
        SizedBox(height: kids ? 20 : AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            kids
                ? 'notification_prompt_title_kids'.tr()
                : 'notification_prompt_title'.tr(),
            textAlign: TextAlign.center,
            style: texts.title.copyWith(
              color: colors.textPrimary,
              fontSize: kids ? 30 : 24,
              height: kids ? 42 / 30 : 34 / 24,
            ),
          ),
        ),
        SizedBox(height: kids ? AppSpacing.xs : AppSpacing.sm),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              kids
                  ? 'notification_prompt_body_kids'.tr()
                  : 'notification_prompt_body'.tr(),
              textAlign: TextAlign.center,
              style: texts.body.copyWith(
                color: colors.textSecondary,
                fontSize: kids ? 20 : 16,
                height: kids ? 34 / 20 : 26 / 16,
              ),
            ),
          ),
        ),
        SizedBox(height: kids ? AppSpacing.xl : 28),
        if (!kids) ...[
          Text(
            'notification_prompt_when'.tr(),
            style: texts.captionStrong.copyWith(
              color: colors.textPrimary,
              fontSize: 14,
              height: 22 / 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
        ],
        Semantics(
          container: true,
          label: 'notification_prompt_when'.tr(),
          child: Row(
            children: [
              for (final (i, choice) in PromptChoice.values.indexed) ...[
                if (i > 0) SizedBox(width: kids ? 10 : AppSpacing.sm),
                Expanded(
                  child: _ChoiceCard(
                    choice: choice,
                    time: switch (choice) {
                      PromptChoice.morning => state.morning,
                      PromptChoice.evening => state.evening,
                      PromptChoice.other => state.custom,
                    },
                    selected: state.choice == choice,
                    kids: kids,
                    onTap: state.asking
                        ? null
                        : () => choice == PromptChoice.other
                              ? _pickTime(state)
                              : cubit.choose(choice),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: state.canEnable ? cubit.enable : null,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primaryStrong,
            foregroundColor: colors.onPrimaryStrong,
            minimumSize: Size.fromHeight(kids ? 64 : 52),
            textStyle: texts.button.copyWith(fontSize: kids ? 20 : 16),
            shape: const StadiumBorder(),
          ),
          child: Text(
            kids
                ? 'notification_prompt_enable_kids'.tr()
                : 'notification_prompt_enable'.tr(),
          ),
        ),
        SizedBox(height: kids ? 6 : AppSpacing.xs),
        TextButton(
          onPressed: state.asking || state.finished ? null : cubit.skip,
          style: TextButton.styleFrom(
            foregroundColor: colors.primary.text,
            minimumSize: Size.fromHeight(kids ? 56 : 44),
            textStyle: texts.captionStrong.copyWith(fontSize: kids ? 18 : 15),
            shape: const StadiumBorder(),
          ),
          child: Text('notification_prompt_skip'.tr()),
        ),
        if (!kids) ...[
          const SizedBox(height: 2),
          Text(
            'notification_prompt_later_note'.tr(),
            textAlign: TextAlign.center,
            style: texts.caption.copyWith(color: colors.textSecondary),
          ),
        ],
        SizedBox(height: AppSpacing.md * _k),
      ],
    );
  }
}

/// The guide in its circle with a bell on the circle's corner.
class _Hero extends StatelessWidget {
  const _Hero({required this.kids});

  final bool kids;

  static const _circle = 200.0;
  static const _guide = 130.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final badge = kids ? 52.0 : 46.0;
    final inset = kids ? 2.0 : 4.0;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _circle,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Align(
              // The guide sits 2 under the middle (design: top 37 of 200).
              alignment: AlignmentDirectional(0, .04),
              child: Mascot(
                expression: MascotExpression.happy,
                size: _guide,
                sparkles: false,
                shadow: false,
              ),
            ),
            PositionedDirectional(
              top: inset,
              end: inset,
              child: Container(
                width: badge,
                height: badge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.reward.fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.background, width: 3),
                ),
                child: AppIconView(
                  AppIcon.bell,
                  size: kids ? 28 : 24,
                  stroke: 2.2,
                  // Ink on amber, dark in both themes (design).
                  color: dark ? colors.background : colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.time,
    required this.selected,
    required this.kids,
    required this.onTap,
  });

  final PromptChoice choice;
  final ReminderTime? time;
  final bool selected;
  final bool kids;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final label = switch (choice) {
      PromptChoice.morning => 'notification_prompt_morning'.tr(),
      PromptChoice.evening => 'notification_prompt_evening'.tr(),
      PromptChoice.other => 'notification_prompt_other'.tr(),
    };
    final time = this.time;
    // The set choices show the hour alone, as their label says when; the
    // learner's own carries its period (design).
    final clock = switch (time) {
      null => kids ? '…' : 'notification_prompt_pick'.tr(),
      _ when choice == PromptChoice.other && !kids => formatClock(
        time.hour,
        time.minute,
      ),
      _ => '${hour12(time.hour)}:${time.minute.toString().padLeft(2, '0')}',
    };
    final ink = selected ? colors.primary.text : colors.textPrimary;
    final soft = selected ? colors.primary.text : colors.textSecondary;
    final icon = switch (choice) {
      PromptChoice.morning => AppIcon.sun,
      PromptChoice.evening => AppIcon.moon,
      PromptChoice.other => AppIcon.clock,
    };
    // Andika for a child's Latin digits only (design 08).
    final timeStyle = kids
        ? (selected ? texts.kidsWord : texts.kidsCard).copyWith(
            fontSize: 18,
            height: 22 / 18,
            color: soft,
          )
        : (selected ? texts.captionStrong : texts.caption).copyWith(
            height: 18 / 13,
            color: soft,
          );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$label $clock',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: kids ? 120 : 80,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.primary.surface : colors.surface,
            borderRadius: BorderRadius.circular(kids ? 20 : 16),
            border: Border.all(
              color: selected ? colors.primary.fill : colors.border,
              width: switch ((selected, kids)) {
                (true, true) => 2.5,
                (true, false) => 2,
                (false, true) => 2,
                (false, false) => 1.5,
              },
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconView(icon, size: kids ? 34 : 22, color: soft),
                    SizedBox(height: kids ? AppSpacing.xs : 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texts.captionStrong.copyWith(
                        color: ink,
                        fontSize: kids ? 17 : 13,
                        height: kids ? 26 / 17 : 20 / 13,
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(clock, maxLines: 1, style: timeStyle),
                    ),
                  ],
                ),
              ),
              if (selected)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: Container(
                    width: kids ? 24 : 18,
                    height: kids ? 24 : 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryStrong,
                      shape: BoxShape.circle,
                    ),
                    child: AppIconView(
                      AppIcon.check,
                      size: kids ? 15 : 12,
                      stroke: 3.2,
                      color: colors.onPrimaryStrong,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
