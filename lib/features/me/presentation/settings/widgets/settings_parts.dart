import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/theme_preview.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_video.dart';
import 'package:englizia/features/onboarding/presentation/goal/widgets/goal_preview.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/material.dart';

/// A group of settings under its caption: one surface with fine dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.title,
    required this.rows,
    this.above,
    super.key,
  });

  final String title;
  final List<Widget> rows;

  /// What sits between the caption and the rows: why a group is off.
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.texts.captionStrong.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          if (above case final above?) ...[
            above,
            const SizedBox(height: AppSpacing.sm + 2),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg - 1),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, row) in rows.indexed) ...[
                      if (index > 0) Divider(height: 1, color: colors.border),
                      row,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row that opens something, or does it: its label, what it is set to,
/// and a chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    this.value,
    this.valueDirection,
    this.subtitle,
    this.badge,
    this.leading,
    this.onPressed,
    this.chevron = true,
    this.danger = false,
    super.key,
  });

  final String label;
  final String? value;
  final TextDirection? valueDirection;
  final String? subtitle;

  /// Beside the value: «مؤكّد».
  final Widget? badge;

  /// Before the value: a sign-in's logo.
  final Widget? leading;
  final VoidCallback? onPressed;
  final bool chevron;

  /// An action that loses something, in the error color.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final value = this.value;
    final subtitle = this.subtitle;
    return InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: texts.body.copyWith(
                        fontSize: 15,
                        height: 24 / 15,
                        color: danger ? colors.error.text : colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (leading case final leading?) ...[
                const SizedBox(width: AppSpacing.sm),
                leading,
              ],
              if (value != null && value.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .45,
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: valueDirection,
                    style: texts.body.copyWith(
                      fontSize: 14,
                      height: 22 / 14,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
              if (badge case final badge?) ...[
                const SizedBox(width: AppSpacing.xs + 2),
                badge,
              ],
              if (chevron) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A switch: the whole row flips it. Off and faded when [enabled] is false.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.label,
    required this.on,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool on;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  static const _faded = .45;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final subtitle = this.subtitle;
    return Opacity(
      opacity: enabled ? 1 : _faded,
      child: MergeSemantics(
        child: InkWell(
          onTap: enabled ? () => onChanged(!on) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: texts.body.copyWith(
                            fontSize: 15,
                            height: 24 / 15,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: texts.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Switch(
                    value: on && enabled,
                    onChanged: enabled ? onChanged : null,
                    activeTrackColor: colors.primaryStrong,
                    activeThumbColor: colors.onPrimaryStrong,
                    inactiveTrackColor: colors.border,
                    inactiveThumbColor: colors.onPrimaryStrong,
                    trackOutlineColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «مؤكّد» beside a confirmed email.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.success;
    return Container(
      height: 22,
      padding: const EdgeInsetsDirectional.fromSTEB(6, 0, AppSpacing.sm, 0),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconView(AppIcon.check, size: 12, color: tone.text),
          const SizedBox(width: 3),
          Text(
            'me_verified'.tr(),
            style: context.texts.captionStrong.copyWith(
              color: tone.text,
              fontSize: 11,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone has notifications off: the app can't turn them on by itself.
class NotificationsBlocked extends StatelessWidget {
  const NotificationsBlocked({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            AppIconView(AppIcon.bellOff, size: 20, color: colors.info.fill),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                'settings_notifications_off'.tr(),
                style: context.texts.caption.copyWith(color: colors.info.text),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.primary.text,
              ),
              child: Text('settings_open_phone'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> _showSettingsSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext sheet) body,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  sheetAnimationStyle: sheetAnimation(context),
  builder: (sheet) => SingleChildScrollView(
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xl - AppSpacing.xs,
      0,
      AppSpacing.xl - AppSpacing.xs,
      AppSpacing.xl,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: sheet.texts.title)),
        const SizedBox(height: AppSpacing.lg),
        body(sheet),
      ],
    ),
  ),
);

/// One choice of a sheet: its title, what it means, and a radio's dot.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.selected,
    required this.onPressed,
    this.description,
    this.leading,
  });

  final String title;
  final String? description;
  final Widget? leading;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final description = this.description;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm + 2),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        child: Material(
          color: selected ? colors.primary.surface : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: selected ? colors.primaryStrong : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    if (leading case final leading?) ...[
                      leading,
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: texts.bodyStrong.copyWith(
                              fontSize: 15,
                              height: 24 / 15,
                            ),
                          ),
                          if (description != null)
                            Text(
                              description,
                              style: texts.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AnimatedContainer(
                      duration: AppMotion.resolve(context, AppMotion.quick),
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? colors.primaryStrong
                              : colors.border,
                          width: 2,
                        ),
                      ),
                      child: AnimatedScale(
                        scale: selected ? 1 : 0,
                        duration: AppMotion.resolve(context, AppMotion.quick),
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: colors.primaryStrong,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «الهدف اليومي»: the panel's goals as onboarding offered them. The minutes
/// chosen, or null.
Future<int?> showGoalSheet(
  BuildContext context, {
  required DailyGoalSettings goals,
  required int current,
}) {
  final language = context.locale.languageCode;
  return _showSettingsSheet<int>(
    context,
    title: 'settings_goal'.tr(),
    body: (sheet) => Column(
      children: [
        for (final option in goals.options)
          _Choice(
            title: 'onboarding_goal_per_day'.plural(option.minutes),
            description: switch (GoalPreview.lessonsLine(
              option.minutes,
              goals.lessonMinutes,
            )) {
              final lessons? => 'settings_goal_line'.tr(
                namedArgs: {
                  'label': option.label.of(language),
                  'lessons': lessons,
                },
              ),
              null => option.label.of(language),
            },
            selected: option.minutes == current,
            onPressed: () => Navigator.of(sheet).pop(option.minutes),
          ),
      ],
    ),
  );
}

/// «المظهر»: light, dark, or as the phone is, each with a little preview.
Future<ThemeMode?> showAppearanceSheet(
  BuildContext context,
  ThemeMode current,
) => _showSettingsSheet<ThemeMode>(
  context,
  title: 'settings_theme'.tr(),
  body: (sheet) => Row(
    children: [
      for (final (index, mode) in const [
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.system,
      ].indexed) ...[
        if (index > 0) const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: _Appearance(
            mode: mode,
            selected: mode == current,
            onPressed: () => Navigator.of(sheet).pop(mode),
          ),
        ),
      ],
    ],
  ),
);

String themeName(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'settings_theme_light'.tr(),
  ThemeMode.dark => 'settings_theme_dark'.tr(),
  ThemeMode.system => 'settings_follow_phone'.tr(),
};

class _Appearance extends StatelessWidget {
  const _Appearance({
    required this.mode,
    required this.selected,
    required this.onPressed,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: selected ? colors.primary.surface : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: selected ? colors.primaryStrong : colors.border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 12, 6, 10),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 60,
                    height: 96,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.border.withValues(alpha: .5),
                      ),
                    ),
                    child: ThemePreview(mode: mode),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  themeName(mode),
                  textAlign: TextAlign.center,
                  style: context.texts.bodyStrong.copyWith(
                    fontSize: 14,
                    height: 22 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «لغة الواجهة»: Arabic or English; the language learned stays English.
Future<Locale?> showLanguageSheet(BuildContext context, Locale current) =>
    _showSettingsSheet<Locale>(
      context,
      title: 'settings_app_language'.tr(),
      body: (sheet) {
        Widget mark(String text) => Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sheet.colors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(text, style: sheet.texts.bodyStrong),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Choice(
              leading: mark('settings_lang_ar_mark'.tr()),
              title: 'settings_language_ar'.tr(),
              description: 'settings_lang_ar_hint'.tr(),
              selected: current.languageCode == 'ar',
              onPressed: () => Navigator.of(sheet).pop(const Locale('ar')),
            ),
            _Choice(
              leading: mark('settings_lang_en_mark'.tr()),
              title: 'settings_language_en'.tr(),
              description: 'settings_lang_en_hint'.tr(),
              selected: current.languageCode == 'en',
              onPressed: () => Navigator.of(sheet).pop(const Locale('en')),
            ),
            Text(
              'settings_learn_stays'.tr(),
              style: sheet.texts.caption.copyWith(
                color: sheet.colors.textSecondary,
              ),
            ),
          ],
        );
      },
    );

String qualityName(VideoQuality quality) => switch (quality) {
  VideoQuality.auto => 'settings_quality_auto'.tr(),
  VideoQuality.low => 'settings_quality_low'.tr(),
  VideoQuality.medium => 'settings_quality_medium'.tr(),
  VideoQuality.high => 'settings_quality_high'.tr(),
};

/// «جودة الفيديو», kept on this phone.
Future<VideoQuality?> showQualitySheet(
  BuildContext context,
  VideoQuality current,
) => _showSettingsSheet<VideoQuality>(
  context,
  title: 'settings_video_quality'.tr(),
  body: (sheet) => Column(
    children: [
      for (final quality in VideoQuality.values)
        _Choice(
          title: qualityName(quality),
          description: quality == VideoQuality.low
              ? 'settings_video_hint'.tr()
              : null,
          selected: quality == current,
          onPressed: () => Navigator.of(sheet).pop(quality),
        ),
    ],
  ),
);
