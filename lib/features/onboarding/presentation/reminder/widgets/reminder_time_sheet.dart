import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/material.dart';

/// "Choose a reminder time": hour and minute wheels and the AM/PM switch,
/// from [initial]. Returns the saved time, or null when dismissed.
Future<ReminderTime?> showReminderTimeSheet(
  BuildContext context, {
  required ReminderTime initial,
}) => showModalBottomSheet<ReminderTime>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ReminderTimeSheet(initial: initial),
);

class ReminderTimeSheet extends StatefulWidget {
  const ReminderTimeSheet({required this.initial, super.key});

  final ReminderTime initial;

  @override
  State<ReminderTimeSheet> createState() => _ReminderTimeSheetState();
}

class _ReminderTimeSheetState extends State<ReminderTimeSheet> {
  late int _hour = hour12(widget.initial.hour);
  late int _minute = widget.initial.minute;
  late bool _pm = widget.initial.hour >= 12;

  static const _wheelsHeight = 220.0;
  static const _wheelsGap = 20.0;

  ReminderTime get _time =>
      ReminderTime((_hour % 12) + (_pm ? 12 : 0), _minute);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'onboarding_reminder_sheet_title'.tr(),
            style: context.texts.title,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: _wheelsHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The band the chosen values rest in.
                Container(
                  height: _Wheel.itemExtent,
                  decoration: BoxDecoration(
                    color: colors.primary.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hours then minutes, left to right in both languages.
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Wheel(
                            label: 'onboarding_reminder_hour'.tr(),
                            count: 12,
                            initial: _hour - 1,
                            text: (i) => '${i + 1}',
                            onChanged: (i) => setState(() => _hour = i + 1),
                          ),
                          ExcludeSemantics(
                            child: Text(':', style: context.texts.title),
                          ),
                          _Wheel(
                            label: 'onboarding_reminder_minute'.tr(),
                            count: 60,
                            initial: _minute,
                            text: (i) => i.toString().padLeft(2, '0'),
                            onChanged: (i) => setState(() => _minute = i),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: _wheelsGap),
                    _PeriodSwitch(
                      pm: _pm,
                      onChanged: (pm) => setState(() => _pm = pm),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
          AppButton(
            label: 'common_save'.tr(),
            size: AppButtonSize.large,
            onPressed: () => Navigator.of(context).pop(_time),
          ),
        ],
      ),
    );
  }
}

/// One scrolling column of values, flat like the designs: the chosen value
/// sits in the band, the others fade with distance. Tapping a value moves
/// to it; screen readers adjust it up and down.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.label,
    required this.count,
    required this.initial,
    required this.text,
    required this.onChanged,
  });

  final String label;
  final int count;
  final int initial;
  final String Function(int index) text;
  final ValueChanged<int> onChanged;

  static const itemExtent = 44.0;
  static const width = 64.0;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.initial,
  );
  late int _selected = widget.initial;

  /// Opacity by distance from the band: the designs' 1, .55, .22, then .1.
  static const _fade = [1.0, .55, .22];
  static const _farOpacity = .1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _moveTo(int index) => _controller.animateToItem(
    index,
    duration: AppMotion.resolve(context, AppMotion.fast),
    curve: AppMotion.smoothOut,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.texts.title;
    return Semantics(
      label: widget.label,
      value: widget.text(_selected),
      increasedValue: _selected + 1 < widget.count
          ? widget.text(_selected + 1)
          : null,
      decreasedValue: _selected > 0 ? widget.text(_selected - 1) : null,
      onIncrease: _selected + 1 < widget.count
          ? () => _moveTo(_selected + 1)
          : null,
      onDecrease: _selected > 0 ? () => _moveTo(_selected - 1) : null,
      child: ExcludeSemantics(
        child: SizedBox(
          width: _Wheel.width,
          child: ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: _Wheel.itemExtent,
            physics: const FixedExtentScrollPhysics(),
            // Nearly flat: the designs' column, not a drum.
            diameterRatio: 8,
            overAndUnderCenterOpacity: 1,
            onSelectedItemChanged: (index) {
              setState(() => _selected = index);
              widget.onChanged(index);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.count,
              builder: (context, index) {
                final distance = (index - _selected).abs();
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _moveTo(index),
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: distance < _fade.length
                          ? _fade[distance]
                          : _farOpacity,
                      duration: AppMotion.resolve(context, AppMotion.quick),
                      child: Text(
                        widget.text(index),
                        style: style.copyWith(
                          color: distance == 0
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// AM above PM, as a radio pair.
class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.pm, required this.onChanged});

  final bool pm;
  final ValueChanged<bool> onChanged;

  static const _width = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget option(bool value, String label) {
      final selected = value == pm;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? colors.primaryStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm + AppSpacing.xxs),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm + AppSpacing.xxs),
            onTap: () => onChanged(value),
            child: SizedBox(
              width: _width,
              height: AppSizes.minTapTarget,
              child: Center(
                child: Text(
                  label,
                  style: context.texts.bodyStrong.copyWith(
                    color: selected
                        ? colors.onPrimaryStrong
                        : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'onboarding_reminder_period'.tr(),
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md + AppSpacing.xxs),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(false, clockPeriod(0)),
              const SizedBox(height: AppSpacing.xs),
              option(true, clockPeriod(12)),
            ],
          ),
        ),
      ),
    );
  }
}
