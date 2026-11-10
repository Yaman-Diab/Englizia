import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/count_up.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/motion/when_seen.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/streak_flame.dart';
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/core/settings/app_haptics.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/presentation/me/widgets/sea_art.dart';
import 'package:flutter/foundation.dart' show Unicode;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

const meCardRadius = 24.0;

/// «أنا»'s card: one soft shadow, a fine border.
BoxDecoration meCard(BuildContext context, {Color? color}) => BoxDecoration(
  color: color ?? context.colors.surface,
  borderRadius: BorderRadius.circular(meCardRadius),
  border: color == null
      ? Border.all(color: context.scheme.outlineVariant)
      : null,
  boxShadow: color == null
      ? [
          BoxShadow(
            color: context.scheme.shadow.withValues(alpha: .05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
      : null,
);

/// A number that counts up from zero on the day's first view only.
class MeNumber extends StatelessWidget {
  const MeNumber({
    required this.value,
    required this.style,
    required this.count,
    super.key,
  });

  final int value;
  final TextStyle style;
  final bool count;

  static final _format = NumberFormat.decimalPattern('en_US');

  /// «1,240», in Latin digits.
  static String format(int value) => _format.format(value);

  @override
  Widget build(BuildContext context) {
    final style = this.style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (!count) return Text(_format.format(value), style: style);
    // Zero until it is in sight, then it counts, as the design has it: a
    // number that counted while off-screen is a number nobody saw move.
    return WhenSeen(
      builder: (context, seen) => seen
          ? CountUp(
              value: value,
              builder: (context, shown) =>
                  Text(_format.format(shown), style: style),
            )
          : Text(_format.format(0), style: style),
    );
  }
}

/// The band, the gear, the picture with its level badge, and the guide.
class MeHeader extends StatelessWidget {
  const MeHeader({
    required this.profile,
    required this.guest,
    required this.drift,
    required this.onSettings,
    super.key,
  });

  final Profile profile;
  final bool guest;
  final bool drift;
  final VoidCallback onSettings;

  static const _band = 176.0;
  static const height = 232.0;
  static const _cut = 104.0;
  static const _ring = 98.0;
  static const _photo = 88.0;
  static const _badge = 28.0;
  static const _guide = 72.0;
  static const _gear = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final track = profile.active;
    final label = track?.levelLabel ?? '';
    final broken = profile.streak?.current == 0;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SeaBand(
            tone: seaOf(track),
            height: _band,
            coverUrl: track?.unitCoverUrl,
            drift: drift,
          ),
          PositionedDirectional(
            top: 34 - AppSpacing.xs,
            end: AppSpacing.md - 2,
            child: Tooltip(
              message: 'me_settings'.tr(),
              child: Semantics(
                button: true,
                label: 'me_settings'.tr(),
                excludeSemantics: true,
                child: PressScale(
                  child: Material(
                    color: colors.surface,
                    shape: const CircleBorder(),
                    elevation: 1,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onSettings,
                      child: SizedBox.square(
                        dimension: AppSizes.minTapTarget,
                        child: Center(
                          child: SizedBox.square(
                            dimension: _gear,
                            child: Icon(
                              Icons.settings_outlined,
                              size: AppSizes.iconMd - 2,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 124,
            start: AppSpacing.lg,
            child: SizedBox.square(
              dimension: _cut,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: _cut,
                      height: _cut,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: _ring,
                        height: _ring,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.primary.fill,
                            width: 2.5,
                          ),
                        ),
                        child: Container(
                          width: _photo,
                          height: _photo,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primary.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            profile.name.trim().characters.firstOrNull ?? '',
                            style: texts.display.copyWith(
                              color: colors.primary.text,
                              fontSize: 36,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (label.isNotEmpty)
                    PositionedDirectional(
                      bottom: 2,
                      end: -AppSpacing.xs,
                      child: Semantics(
                        label: track!.isSchool
                            ? track.levelName
                            : 'me_level_semantics'.tr(args: [label]),
                        excludeSemantics: true,
                        child: Container(
                          height: _badge,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 9,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primaryStrong,
                            borderRadius: BorderRadius.circular(_badge / 2),
                            border: Border.all(
                              color: colors.background,
                              width: 2.5,
                            ),
                          ),
                          child: Text(
                            label,
                            style: texts.captionStrong.copyWith(
                              color: colors.onPrimaryStrong,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!guest)
            PositionedDirectional(
              top: 156,
              start: 124,
              child: ExcludeSemantics(
                child: Mascot(
                  expression: broken
                      ? MascotExpression.encourage
                      : MascotExpression.welcome,
                  waving: !broken,
                  size: _guide,
                  sparkles: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The name with its pencil, the email and whether it is confirmed, or «ضيف»,
/// and since when.
class MeIdentity extends StatelessWidget {
  const MeIdentity({
    required this.profile,
    required this.guest,
    required this.onEditName,
    required this.onVerify,
    super.key,
  });

  final Profile profile;
  final bool guest;
  final VoidCallback onEditName;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final email = profile.email;
    final since = profile.learningSince;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl - AppSpacing.xs,
        AppSpacing.xs + 2,
        AppSpacing.xl - AppSpacing.xs,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text(profile.name, style: texts.title),
                ),
              ),
              IconButton(
                tooltip: 'me_edit_name'.tr(),
                onPressed: onEditName,
                color: colors.textSecondary,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: AppSizes.iconMd - 4,
                ),
              ),
            ],
          ),
          if (guest || email == null)
            Text(
              'me_guest'.tr(),
              style: texts.body.copyWith(color: colors.textSecondary),
            )
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs + 2,
              children: [
                Text(
                  email,
                  textDirection: TextDirection.ltr,
                  style: texts.body.copyWith(
                    color: colors.textSecondary,
                    fontSize: 14,
                    height: 22 / 14,
                  ),
                ),
                if (profile.emailVerified)
                  _Chip(
                    icon: AppIcon.check,
                    label: 'me_verified'.tr(),
                    tone: colors.success,
                  )
                else
                  Semantics(
                    button: true,
                    label: 'me_unverified_semantics'.tr(),
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: onVerify,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Center(
                          widthFactor: 1,
                          child: _Chip(
                            icon: AppIcon.infoCircle,
                            label: 'me_unverified'.tr(),
                            tone: colors.info,
                            trailing: true,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (since != null)
            Text(
              'me_since'.tr(
                args: [formatMonthYear(since, context.locale.languageCode)],
              ),
              style: texts.caption.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.tone,
    this.trailing = false,
  });

  final AppIcon icon;
  final String label;
  final ToneColors tone;

  /// It opens something: a chevron follows.
  final bool trailing;

  static const _height = 28.0;

  @override
  Widget build(BuildContext context) => Container(
    height: _height,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm),
    decoration: BoxDecoration(
      color: tone.surface,
      borderRadius: BorderRadius.circular(_height / 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconView(icon, size: 14, color: tone.text),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: context.texts.captionStrong.copyWith(
            color: tone.text,
            fontSize: 12,
            height: 16 / 12,
          ),
        ),
        if (trailing) ...[
          const SizedBox(width: AppSpacing.xxs),
          Icon(Icons.chevron_right_rounded, size: 16, color: tone.text),
        ],
      ],
    ),
  );
}

/// A guest's progress lives on this phone only: the guide asks for an account.
class GuestCard extends StatelessWidget {
  const GuestCard({required this.onCreateAccount, super.key});

  final VoidCallback onCreateAccount;

  static const _guide = 80.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: meCard(context, color: colors.info.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const ExcludeSemantics(
                child: Mascot(size: _guide, waving: true, sparkles: false),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconView(
                      AppIcon.phone,
                      size: AppSizes.iconMd - 4,
                      color: colors.info.fill,
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      'me_guest_note'.tr(),
                      style: context.texts.bodyStrong.copyWith(
                        color: colors.info.text,
                        fontSize: 17,
                        height: 27 / 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          AppButton(
            label: 'me_create_account'.tr(),
            onPressed: () {
              AppHaptics.selectionClick();
              onCreateAccount();
            },
          ),
        ],
      ),
    );
  }
}

/// The active track: its name and level, its units as islands, and the way
/// to another track, or another grade.
class TrackCard extends StatelessWidget {
  const TrackCard({
    required this.track,
    required this.onSwitch,
    required this.onGrade,
    super.key,
  });

  final ProfileTrack track;
  final VoidCallback onSwitch;
  final VoidCallback onGrade;

  static const _badge = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final tone = seaOf(track);
    final unit = 'me_track_unit'.tr(
      namedArgs: {'unit': '${track.unit}', 'units': '${track.units}'},
    );
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        18,
        18,
        18,
        AppSpacing.xs + 2,
      ),
      decoration: meCard(
        context,
        color: tone == SeaTone.emar
            ? SeaPalette.of(context).emar
            : colors.primary.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'me_current_track'.tr(),
            style: texts.caption.copyWith(color: colors.textSecondary),
          ),
          Semantics(header: true, child: Text(track.title, style: texts.title)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Container(
                height: _badge,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(_badge / 2),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    track.isSchool ? track.levelName : track.levelLabel,
                    style: texts.captionStrong.copyWith(height: 1),
                  ),
                ),
              ),
              if (!track.isSchool && track.levelName.isNotEmpty)
                Text(
                  track.levelName,
                  style: texts.body.copyWith(fontSize: 14, height: 22 / 14),
                ),
              if (track.isSchool)
                TextButton(
                  onPressed: onGrade,
                  child: Text('me_change_grade'.tr()),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Semantics(
            label: 'me_track_progress'.tr(),
            value: unit,
            child: ExcludeSemantics(
              child: Transform.translate(
                offset: Offset.zero,
                child: IslandChain(
                  tone: tone,
                  unit: track.unit,
                  units: track.units,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    unit,
                    style: texts.bodyStrong.copyWith(
                      fontSize: 14,
                      height: 22 / 14,
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onSwitch,
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                label: Text('me_switch_track'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «إنجازاتك» as a bento: the streak across the top with its points, lessons
/// done tall, words and days beside.
class MeAchievements extends StatelessWidget {
  const MeAchievements({
    required this.profile,
    required this.count,
    required this.onStreak,
    super.key,
  });

  final Profile profile;

  /// The day's first view: numbers count up, the flame beats.
  final bool count;
  final VoidCallback onStreak;

  static const _gap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final words = profile.wordsSaved;
    final streak = profile.streak;
    final lessons = _Tile(
      tall: words != null,
      icon: AppIcon.checkCircle,
      tone: colors.success,
      value: profile.lessonsDone,
      label: 'me_lessons_done'.tr(),
      semantics: 'me_lessons_semantics'.plural(profile.lessonsDone),
      count: count,
    );
    final days = _Tile(
      icon: AppIcon.calendar,
      tone: colors.primary,
      value: profile.learningDays,
      label: 'me_learning_days'.tr(),
      semantics: 'me_days_semantics'.plural(profile.learningDays),
      count: count,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('me_achievements'.tr(), style: context.texts.bodyStrong),
        ),
        const SizedBox(height: AppSpacing.md),
        if (streak != null) ...[
          _StreakCard(
            streak: streak,
            points: profile.points,
            count: count,
            onPressed: onStreak,
          ),
          const SizedBox(height: _gap),
        ],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: lessons),
              const SizedBox(width: _gap),
              Expanded(
                child: words == null
                    ? days
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Tile(
                            icon: AppIcon.bookmark,
                            tone: colors.reward,
                            value: words,
                            label: 'me_words_saved'.tr(),
                            semantics: 'me_words_semantics'.plural(words),
                            count: count,
                          ),
                          const SizedBox(height: _gap),
                          days,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.semantics,
    required this.count,
    this.tall = false,
  });

  final AppIcon icon;
  final ToneColors tone;
  final int value;
  final String label;
  final String semantics;
  final bool count;

  /// Two rows high, with the number at its biggest.
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;
    final mark = Container(
      width: tall ? 44 : 40,
      height: tall ? 44 : 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone.surface, shape: BoxShape.circle),
      child: AppIconView(icon, size: AppSizes.iconMd - 2, color: tone.fill),
    );
    final number = MeNumber(
      value: value,
      count: count,
      style: tall
          ? texts.display.copyWith(fontSize: 40, height: 46 / 40)
          : texts.title.copyWith(fontSize: 28, height: 36 / 28),
    );
    final caption = Text(
      label,
      style: texts.caption.copyWith(color: context.colors.textSecondary),
    );
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: tall ? 104 : 96),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
          vertical: tall ? AppSpacing.lg : AppSpacing.md + 2,
        ),
        decoration: meCard(context),
        child: tall
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  mark,
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [number, caption],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Expanded(child: number),
                      mark,
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  caption,
                ],
              ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.streak,
    required this.points,
    required this.count,
    required this.onPressed,
  });

  final Streak streak;
  final Points? points;
  final bool count;
  final VoidCallback onPressed;

  static const _flame = 56.0;
  static const _capsule = 30.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final broken = streak.current == 0;
    final reduce = AppMotion.reduceMotion(context);
    final tint = broken ? colors.textPrimary : colors.streak.text;
    Widget flame = broken
        ? AppIconView(AppIcon.flame, size: _flame - 12, color: colors.border)
        : const StreakFlame(size: _flame - 8);
    if (count && !broken && !reduce) {
      final still = flame;
      flame = WhenSeen(
        builder: (context, seen) => seen
            ? still
                  .animate(delay: AppMotion.fast)
                  .scaleXY(end: 1.14, duration: AppMotion.meFlameBeat * .25)
                  .then()
                  .scaleXY(end: 1 / 1.14, duration: AppMotion.meFlameBeat * .25)
                  .then()
                  .scaleXY(end: 1.08, duration: AppMotion.meFlameBeat * .25)
                  .then()
                  .scaleXY(end: 1 / 1.08, duration: AppMotion.meFlameBeat * .25)
            : still,
      );
    }
    Widget capsule = Container(
      height: _capsule,
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.sm, 0, 10, 0),
      decoration: BoxDecoration(
        color: colors.info.surface,
        borderRadius: BorderRadius.circular(_capsule / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.ac_unit_rounded, size: 16, color: colors.info.text),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(
            'me_freeze'.tr(
              namedArgs: {
                'have': '${streak.freezes}',
                'max': '${streak.maxFreezes}',
              },
            ),
            style: texts.captionStrong.copyWith(
              color: colors.info.text,
              height: 1,
            ),
          ),
        ],
      ),
    );
    if (count && !reduce) {
      final still = capsule;
      capsule = WhenSeen(
        builder: (context, seen) => seen
            ? still
                  .animate(delay: AppMotion.meShineDelay)
                  .shimmer(
                    duration: AppMotion.meShine,
                    color: colors.surface.withValues(alpha: .75),
                  )
            : still,
      );
    }
    final points = this.points;
    return Semantics(
      button: true,
      label: [
        'me_streak_semantics'.tr(
          namedArgs: {
            'days': 'me_streak_count'.plural(streak.current),
            'longest': '${streak.longest}',
            'have': '${streak.freezes}',
            'max': '${streak.maxFreezes}',
          },
        ),
        if (points != null)
          'me_points_semantics'.tr(
            namedArgs: {
              'total': MeNumber.format(points.total),
              'week': MeNumber.format(points.week),
            },
          ),
      ].join('me_list_separator'.tr()),
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(meCardRadius),
            side: BorderSide(color: context.scheme.outlineVariant),
          ),
          child: InkWell(
            onTap: () {
              AppHaptics.selectionClick();
              onPressed();
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.md + 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox.square(
                        dimension: _flame,
                        child: Center(child: flame),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: AppSpacing.sm,
                              children: [
                                MeNumber(
                                  value: streak.current,
                                  count: count,
                                  style: texts.display.copyWith(
                                    color: tint,
                                    fontSize: 40,
                                    height: 46 / 40,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: Text(
                                    'me_streak_label'.plural(streak.current),
                                    style: texts.bodyStrong.copyWith(
                                      color: tint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'me_streak_longest'.tr(
                                args: ['${streak.longest}'],
                              ),
                              style: texts.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm + 2),
                            capsule,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (points != null) ...[
                  Divider(
                    height: 1,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                    color: context.scheme.outlineVariant,
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md + 2,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          const KidStar(size: 26),
                          const SizedBox(width: AppSpacing.md + 2),
                          Expanded(
                            child: _Points(
                              value: points.total,
                              label: 'me_xp_total'.tr(),
                              count: count,
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            color: context.scheme.outlineVariant,
                          ),
                          const SizedBox(width: AppSpacing.md + 2),
                          Expanded(
                            child: _Points(
                              value: points.week,
                              label: 'me_xp_week'.tr(),
                              count: count,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({
    required this.value,
    required this.label,
    required this.count,
  });

  final int value;
  final String label;
  final bool count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.texts.bodyStrong.copyWith(
      color: colors.reward.text,
      fontSize: 20,
      height: 28 / 20,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: [
            MeNumber(value: value, count: count, style: style),
            const SizedBox(width: AppSpacing.xs),
            Text('me_xp'.tr(), style: style),
          ],
        ),
        Text(
          label,
          style: context.texts.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// A weekday as the app's keys name it.
String weekdayName(DateTime day) => switch (day.weekday) {
  DateTime.monday => 'me_day_mon'.tr(),
  DateTime.tuesday => 'me_day_tue'.tr(),
  DateTime.wednesday => 'me_day_wed'.tr(),
  DateTime.thursday => 'me_day_thu'.tr(),
  DateTime.friday => 'me_day_fri'.tr(),
  DateTime.saturday => 'me_day_sat'.tr(),
  _ => 'me_day_sun'.tr(),
};

String _weekdayShort(DateTime day) => switch (day.weekday) {
  DateTime.monday => 'me_short_mon'.tr(),
  DateTime.tuesday => 'me_short_tue'.tr(),
  DateTime.wednesday => 'me_short_wed'.tr(),
  DateTime.thursday => 'me_short_thu'.tr(),
  DateTime.friday => 'me_short_fri'.tr(),
  DateTime.saturday => 'me_short_sat'.tr(),
  _ => 'me_short_sun'.tr(),
};

/// «هذا الأسبوع»: a bar a day against the goal's line, a frozen day striped,
/// days to come dotted, today marked; read as one sentence.
class WeekCard extends StatelessWidget {
  const WeekCard({required this.week, required this.grow, super.key});

  final StudyWeek week;

  /// The bars grow one after another: the day's first view.
  final bool grow;

  static const _chart = 150.0;
  static const _bar = 28.0;
  static const _goalAt = 50.0;
  static const _top = 100.0;

  String _sentence() {
    final days = [
      for (final (index, day) in week.days.indexed)
        if (!day.future)
          () {
            final name = index == week.today
                ? 'me_week_today'.tr(args: [weekdayName(day.date)])
                : weekdayName(day.date);
            final state = day.frozen
                ? 'me_day_frozen'.tr()
                : (day.minutes ?? 0) > 0
                ? 'unit_minutes'.plural(day.minutes!)
                : 'me_day_none'.tr();
            return 'me_week_day'.tr(namedArgs: {'day': name, 'state': state});
          }(),
    ];
    return 'me_week_semantics'.tr(
      namedArgs: {
        'goal': 'unit_minutes'.plural(week.goalMinutes),
        'days': days.join('me_list_separator'.tr()),
        'summary': 'me_week_goal_days'.plural(week.goalDays),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.texts;
    final perMinute = _goalAt / week.goalMinutes;
    final reduce = AppMotion.reduceMotion(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('me_this_week'.tr(), style: texts.bodyStrong),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 14),
          decoration: meCard(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: _sentence(),
                excludeSemantics: true,
                child: SizedBox(
                  height: _chart,
                  // The whole chart grows together, once it is in sight.
                  child: WhenSeen(
                    builder: (context, seen) => Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (index, day) in week.days.indexed) ...[
                              if (index > 0)
                                const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: _DayColumn(
                                  day: day,
                                  today: index == week.today,
                                  goal: week.goalMinutes,
                                  height: math.min(
                                    _top,
                                    (day.minutes ?? 0) * perMinute,
                                  ),
                                  delay: AppMotion.stagger * index,
                                  grow: grow && !reduce && seen,
                                  label: _weekdayShort(day.date),
                                ),
                              ),
                            ],
                          ],
                        ),
                        PositionedDirectional(
                          start: 0,
                          end: 0,
                          bottom: 87,
                          child: _GoalLine(
                            label: 'me_goal_line'.tr(
                              args: ['${week.goalMinutes}'],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'me_week_goal_days'.plural(week.goalDays),
                style: texts.bodyStrong.copyWith(fontSize: 14, height: 22 / 14),
              ),
              const SizedBox(height: AppSpacing.sm),
              ExcludeSemantics(
                child: Wrap(
                  spacing: 14,
                  runSpacing: AppSpacing.xs + 2,
                  children: [
                    _Legend(label: 'me_legend_goal'.tr(), kind: _Key.goal),
                    _Legend(label: 'me_legend_frozen'.tr(), kind: _Key.frozen),
                    _Legend(label: 'me_legend_none'.tr(), kind: _Key.none),
                    _Legend(label: 'me_legend_future'.tr(), kind: _Key.future),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: const Size(double.infinity, 1.5),
            painter: _DashPainter(colors.textSecondary),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 3,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: Text(
                label,
                style: context.texts.captionStrong.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                  height: 16 / 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 4, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.today,
    required this.goal,
    required this.height,
    required this.delay,
    required this.grow,
    required this.label,
  });

  final StudyDay day;
  final bool today;
  final int goal;
  final double height;
  final Duration delay;
  final bool grow;
  final String label;

  static const _bar = WeekCard._bar;
  static const _frozen = 50.0;
  static const _future = 24.0;
  static const _empty = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final minutes = day.minutes ?? 0;
    final met = minutes >= goal;
    Widget bar;
    if (day.frozen) {
      bar = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.ac_unit_rounded, size: 14, color: colors.info.fill),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: _bar,
            height: _frozen,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.info.surface,
              border: Border.all(color: colors.info.fill, width: 1.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.sm),
                bottom: Radius.circular(AppSpacing.xs),
              ),
            ),
            child: CustomPaint(painter: _StripePainter(colors.info.fill)),
          ),
        ],
      );
    } else if (day.future) {
      bar = CustomPaint(
        painter: _DottedBox(colors.border),
        child: const SizedBox(width: _bar, height: _future),
      );
    } else {
      bar = Container(
        width: _bar,
        height: minutes == 0 ? _empty : height,
        decoration: BoxDecoration(
          color: minutes == 0
              ? colors.border
              : met
              ? colors.primary.fill
              : colors.primary.surface,
          border: minutes > 0 && !met
              ? Border.all(color: colors.primary.fill, width: 1.5)
              : null,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sm),
            bottom: Radius.circular(AppSpacing.xs),
          ),
        ),
      );
    }
    if (grow && !day.future) {
      bar = bar
          .animate(delay: delay)
          .scaleY(
            begin: 0,
            end: 1,
            alignment: Alignment.bottomCenter,
            duration: AppMotion.meBarGrow,
            curve: AppMotion.smoothOut,
          );
    }
    return Container(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: today ? context.scheme.surfaceContainerHigh : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          bar,
          const SizedBox(height: AppSpacing.xs + 4),
          Text(
            label,
            style: (today ? context.texts.captionStrong : context.texts.caption)
                .copyWith(
                  color: today ? colors.textPrimary : colors.textSecondary,
                ),
          ),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: today ? colors.textPrimary : null,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .35)
      ..strokeWidth = 1.5;
    for (var x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color;
}

class _DottedBox extends CustomPainter {
  _DottedBox(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          topLeft: const Radius.circular(AppRadius.sm),
          topRight: const Radius.circular(AppRadius.sm),
          bottomLeft: const Radius.circular(AppSpacing.xs),
          bottomRight: const Radius.circular(AppSpacing.xs),
        ),
      );
    final paint = Paint()..color = color;
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 4) {
        final point = metric.getTangentForOffset(at)?.position;
        if (point != null) canvas.drawCircle(point, .9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedBox old) => old.color != color;
}

enum _Key { goal, frozen, none, future }

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.kind});

  final String label;
  final _Key kind;

  static const _size = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final square = switch (kind) {
      _Key.goal => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: colors.primary.fill,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      _Key.frozen => Container(
        width: _size,
        height: _size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.info.surface,
          border: Border.all(color: colors.info.fill, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: CustomPaint(painter: _StripePainter(colors.info.fill)),
      ),
      _Key.none => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      _Key.future => CustomPaint(
        painter: _DottedBox(colors.border),
        child: const SizedBox.square(dimension: _size),
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        square,
        const SizedBox(width: AppSpacing.xs + 2),
        Text(
          label,
          style: context.texts.caption.copyWith(
            color: colors.textSecondary,
            fontSize: 12,
            height: 18 / 12,
          ),
        ),
      ],
    );
  }
}

/// «بنك الكلمات»: how many words, and how many are due; it opens «تدرّب».
class WordBankRow extends StatelessWidget {
  const WordBankRow({required this.tally, required this.onPressed, super.key});

  final WordBankTally tally;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return PressScale(
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(meCardRadius),
          side: BorderSide(color: context.scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () {
            AppHaptics.selectionClick();
            onPressed();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary.surface,
                      shape: BoxShape.circle,
                    ),
                    child: AppIconView(
                      AppIcon.lessonVocabulary,
                      size: AppSizes.iconMd - 2,
                      color: colors.primary.fill,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('me_word_bank'.tr(), style: texts.bodyStrong),
                        Text(
                          'me_word_bank_line'.tr(
                            namedArgs: {
                              'words': 'me_bank_words'.plural(tally.words),
                              'due': 'me_bank_due'.plural(tally.due),
                            },
                          ),
                          style: texts.body.copyWith(
                            color: colors.textSecondary,
                            fontSize: 14,
                            height: 22 / 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
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

/// «نتائج الاختبارات»: the level placed at, when, and how long before it can
/// be taken again, or the way to take it again.
class TestsCard extends StatelessWidget {
  const TestsCard({
    required this.result,
    required this.now,
    required this.draw,
    required this.onRetest,
    super.key,
  });

  final PlacementResult result;
  final DateTime now;

  /// The wait's ring draws itself: the day's first view.
  final bool draw;
  final VoidCallback onRetest;

  static const _medal = 68.0;
  static const _ring = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final left = result.daysLeft(now);
    final share = result.waitDays <= 0
        ? 0.0
        : (left / result.waitDays).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('me_tests'.tr(), style: texts.bodyStrong),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: meCard(context),
          child: Row(
            children: [
              Semantics(
                label: 'me_level_semantics'.tr(args: [result.level]),
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: _medal,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.primary.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.primary.fill,
                            width: 3,
                          ),
                        ),
                        child: Text(
                          result.level,
                          textDirection: TextDirection.ltr,
                          style: texts.title.copyWith(
                            color: colors.primary.text,
                            fontSize: 24,
                            height: 1,
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: -AppSpacing.xs,
                        end: -AppSpacing.xs,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primaryStrong,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 2.5,
                            ),
                          ),
                          child: AppIconView(
                            AppIcon.steps,
                            size: 14,
                            color: colors.onPrimaryStrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('me_placement'.tr(), style: texts.bodyStrong),
                    Text(
                      formatDay(result.takenAt, context.locale.languageCode),
                      style: texts.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (left > 0)
                Semantics(
                  label: 'me_retest_semantics'.tr(
                    namedArgs: {
                      'left': 'me_days'.plural(left),
                      'wait': 'me_days'.plural(result.waitDays),
                    },
                  ),
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 84,
                    child: Column(
                      children: [
                        SizedBox.square(
                          dimension: _ring,
                          // The key matters: a builder already in the tree
                          // only animates when its end changes, so the ring
                          // is built afresh the moment it is in sight.
                          child: WhenSeen(
                            builder: (context, seen) =>
                                TweenAnimationBuilder<double>(
                                  key: ValueKey(seen),
                                  tween: Tween(
                                    begin: draw && seen ? 0 : share,
                                    end: share,
                                  ),
                                  duration: AppMotion.resolve(
                                    context,
                                    AppMotion.countUp,
                                  ),
                                  curve: AppMotion.smoothOut,
                                  builder: (context, value, child) =>
                                      CustomPaint(
                                        painter: _WaitRing(
                                          share: value,
                                          track: colors.info.surface,
                                          fill: colors.info.fill,
                                        ),
                                        child: child,
                                      ),
                                  child: Center(
                                    child: Text(
                                      '$left',
                                      style: texts.bodyStrong,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'me_retest_in'.plural(left),
                          textAlign: TextAlign.center,
                          style: texts.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                            height: 18 / 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                OutlinedButton(
                  onPressed: onRetest,
                  child: Text('me_retest'.tr()),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaitRing extends CustomPainter {
  _WaitRing({required this.share, required this.track, required this.fill});

  final double share;
  final Color track;
  final Color fill;

  static const _width = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(rect, 0, math.pi * 2, false, paint..color = track)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * share,
        false,
        paint..color = fill,
      );
  }

  @override
  bool shouldRepaint(_WaitRing old) =>
      old.share != share || old.track != track || old.fill != fill;
}

/// One row of «أنا»'s menu: a light circle with its icon, the label, a chevron.
class MeMenuRow extends StatelessWidget {
  const MeMenuRow({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onPressed,
    this.below,
    super.key,
  });

  final IconData icon;
  final String label;

  /// The circle's tint, or the neutral one.
  final ToneColors? tone;
  final VoidCallback onPressed;

  /// What sits under the row: the account number.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = this.tone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          tone?.surface ?? context.scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: tone?.fill ?? colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(label, style: context.texts.body)),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        ?below,
      ],
    );
  }
}

/// «رقم حسابك» under the WhatsApp row, with a copy that says it copied.
class AccountNumberLine extends StatefulWidget {
  const AccountNumberLine({required this.number, super.key});

  final String number;

  @override
  State<AccountNumberLine> createState() => _AccountNumberLineState();
}

class _AccountNumberLineState extends State<AccountNumberLine> {
  var _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.number));
    if (!mounted) return;
    setState(() => _copied = true);
    if (!mounted) return;
    await SemanticsService.sendAnnouncement(
      View.of(context),
      'me_copied_semantics'.tr(),
      Directionality.of(context),
    );
    await Future<void>.delayed(AppMotion.copiedHold);
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        64,
        0,
        AppSpacing.xs + 2,
        6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'me_account_number'.tr(args: ['']),
                children: [
                  TextSpan(
                    text: '${Unicode.LRI}${widget.number}${Unicode.PDI}',
                    style: texts.bodyStrong.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              style: texts.body.copyWith(
                color: colors.textSecondary,
                fontSize: 14,
                height: 22 / 14,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: _copied
                ? 'me_copied_semantics'.tr()
                : 'me_copy_semantics'.tr(args: [widget.number]),
            excludeSemantics: true,
            child: TextButton.icon(
              onPressed: _copy,
              style: TextButton.styleFrom(
                foregroundColor: _copied ? colors.success.text : null,
              ),
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
              ),
              label: Text(_copied ? 'me_copied'.tr() : 'me_copy'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
