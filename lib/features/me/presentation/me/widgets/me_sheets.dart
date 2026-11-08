import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/dashed_border.dart';
import 'package:englizia/core/design_system/widgets/streak_flame.dart';
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/me/widgets/me_sections.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:englizia/features/tracks/domain/entities/track_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<T?> _showMeSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: sheetAnimation(context),
      builder: (sheet) => SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl - AppSpacing.xs,
          0,
          AppSpacing.xl - AppSpacing.xs,
          AppSpacing.lg + MediaQuery.viewInsetsOf(sheet).bottom,
        ),
        child: builder(sheet),
      ),
    );

/// A sheet's title with the way to close it.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.leading});

  final String title;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ?leading,
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: context.texts.title),
        ),
      ),
      IconButton(
        tooltip: 'common_close'.tr(),
        onPressed: () => Navigator.of(context).pop(),
        color: context.colors.textSecondary,
        icon: const Icon(Icons.close_rounded),
      ),
    ],
  );
}

/// «تسجّل الخروج؟»; a guest is told the progress will be lost. True to leave,
/// false to make an account first, null to stay.
Future<bool?> showSignOutSheet(
  BuildContext context, {
  required bool guest,
}) async {
  final choice = await showActionSheet(
    context,
    icon: guest ? AppIcon.phone : null,
    tone: guest ? SheetTone.warning : SheetTone.info,
    title: 'me_sign_out_title'.tr(),
    body: guest ? 'me_sign_out_guest'.tr() : 'me_sign_out_member'.tr(),
    primaryLabel: guest ? 'me_create_first'.tr() : 'common_cancel'.tr(),
    secondaryLabel: 'me_sign_out'.tr(),
    outlinedSecondary: true,
  );
  return switch (choice) {
    SheetAction.secondary => true,
    SheetAction.primary when guest => false,
    _ => null,
  };
}

/// The flame's sheet: how a day counts, the freezes, and this week.
Future<void> showStreakSheet(BuildContext context, Profile profile) =>
    _showMeSheet<void>(
      context,
      (_) => _StreakSheet(streak: profile.streak!, week: profile.week),
    );

class _StreakSheet extends StatelessWidget {
  const _StreakSheet({required this.streak, required this.week});

  final Streak streak;
  final StudyWeek? week;

  static String _time(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (hour == null || minute == null) return hhmm;
    return formatClock(hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final week = this.week;
    final broken = streak.current == 0;
    final next = streak.nextFreezeWeekday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 48,
              child: Center(
                child: broken
                    ? AppIconView(AppIcon.flame, size: 40, color: colors.border)
                    : const StreakFlame(size: 44),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'me_streak_count'.plural(streak.current),
                      style: texts.title.copyWith(
                        color: broken ? colors.textPrimary : colors.streak.text,
                      ),
                    ),
                  ),
                  Text(
                    'me_streak_longest'.tr(
                      args: ['me_days'.plural(streak.longest)],
                    ),
                    style: texts.caption.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'common_close'.tr(),
              onPressed: () => Navigator.of(context).pop(),
              color: colors.textSecondary,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        if (week != null) ...[
          const SizedBox(height: 18),
          Text(
            'me_streak_rule'.tr(
              namedArgs: {
                'goal': 'unit_minutes'.plural(week.goalMinutes),
                'start': _time(week.dayStart),
              },
            ),
            style: texts.body,
          ),
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: colors.info.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.ac_unit_rounded,
                    size: 20,
                    color: colors.info.fill,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'me_freeze_title'.tr(),
                      style: texts.bodyStrong.copyWith(color: colors.info.text),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      'me_freeze_count'.tr(
                        namedArgs: {
                          'have': '${streak.freezes}',
                          'max': '${streak.maxFreezes}',
                        },
                      ),
                      style: texts.captionStrong.copyWith(
                        color: colors.info.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                label: 'me_freeze_semantics'.tr(
                  namedArgs: {
                    'have': '${streak.freezes}',
                    'max': '${streak.maxFreezes}',
                  },
                ),
                excludeSemantics: true,
                child: Row(
                  children: [
                    for (var slot = 0; slot < streak.maxFreezes; slot++) ...[
                      if (slot > 0) const SizedBox(width: AppSpacing.xs + 2),
                      Expanded(
                        child: Container(
                          height: AppSpacing.sm,
                          decoration: BoxDecoration(
                            color: slot < streak.freezes
                                ? colors.info.fill
                                : null,
                            border: slot < streak.freezes
                                ? null
                                : Border.all(
                                    color: colors.info.fill,
                                    width: 1.5,
                                  ),
                            borderRadius: BorderRadius.circular(AppSpacing.xs),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'me_freeze_rule'.tr(args: ['${streak.maxFreezes}']),
                style: texts.body.copyWith(fontSize: 14, height: 24 / 14),
              ),
              if (next != null && streak.freezes < streak.maxFreezes) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'me_freeze_next'.tr(
                    args: [weekdayName(DateTime(2024, 1, next))],
                  ),
                  style: texts.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (week != null) ...[
          const SizedBox(height: 18),
          Text('me_this_week'.tr(), style: texts.bodyStrong),
          const SizedBox(height: AppSpacing.sm + 2),
          for (final (index, day) in week.days.indexed)
            if (!day.future)
              _HistoryRow(
                day: day,
                today: index == week.today,
                goal: week.goalMinutes,
              ),
        ],
        const SizedBox(height: 18),
        AppButton(
          label: 'me_got_it'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.day,
    required this.today,
    required this.goal,
  });

  final StudyDay day;
  final bool today;
  final int goal;

  static const _mark = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final minutes = day.minutes ?? 0;
    final met = !day.frozen && minutes >= goal;
    final name = weekdayName(day.date);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: _mark,
            height: _mark,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: day.frozen
                  ? colors.info.surface
                  : met
                  ? colors.primary.surface
                  : null,
              border: day.frozen || met
                  ? null
                  : Border.all(color: colors.border, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: day.frozen
                ? Icon(Icons.ac_unit_rounded, size: 14, color: colors.info.fill)
                : met
                ? AppIconView(
                    AppIcon.check,
                    size: 14,
                    color: colors.primary.text,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              today ? 'me_history_today'.tr(args: [name]) : name,
              style: texts.body.copyWith(fontSize: 14, height: 22 / 14),
            ),
          ),
          Text(
            day.frozen
                ? 'me_history_frozen'.tr()
                : met
                ? 'unit_minutes'.plural(minutes)
                : minutes > 0
                ? 'me_history_part'.tr(
                    namedArgs: {
                      'done': '$minutes',
                      'goal': 'unit_minutes'.plural(goal),
                    },
                  )
                : 'me_day_none'.tr(),
            style: texts.body.copyWith(
              color: colors.textSecondary,
              fontSize: 14,
              height: 22 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// The track a track's tile is drawn for: its sea and its sign.
class _TrackTile extends StatelessWidget {
  const _TrackTile({required this.audience});

  final TrackAudience? audience;

  static const _size = 48.0;

  @override
  Widget build(BuildContext context) {
    final sea = SeaPalette.of(context);
    final colors = context.colors;
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: switch (audience) {
          TrackAudience.schoolStudent => sea.emar,
          TrackAudience.child => sea.kids,
          _ => sea.general,
        },
        borderRadius: BorderRadius.circular(14),
      ),
      child: switch (audience) {
        TrackAudience.child => const KidStar(size: 26),
        TrackAudience.schoolStudent => AppIconView(
          AppIcon.book,
          size: 26,
          color: colors.primaryStrong,
        ),
        _ => Icon(Icons.public_rounded, size: 26, color: colors.primaryStrong),
      },
    );
  }
}

/// The level and unit, as a track's row says them.
String trackLine(ProfileTrack track) => 'me_track_line'.tr(
  namedArgs: {
    'level': track.isSchool
        ? track.levelName
        : 'me_level_semantics'.tr(args: [track.levelLabel]),
    'unit': 'me_track_unit'.tr(
      namedArgs: {'unit': '${track.unit}', 'units': '${track.units}'},
    ),
  },
);

/// «مساراتك» and «أضف مسارًا». The track chosen, or null.
Future<ProfileTrack?> showTracksSheet(
  BuildContext context, {
  required ValueChanged<LearningTrack> onJoin,
}) {
  final cubit = context.read<MeCubit>();
  return _showMeSheet<ProfileTrack>(
    context,
    (_) => BlocProvider.value(
      value: cubit,
      child: _TracksSheet(onJoin: onJoin),
    ),
  );
}

class _TracksSheet extends StatefulWidget {
  const _TracksSheet({required this.onJoin});

  final ValueChanged<LearningTrack> onJoin;

  @override
  State<_TracksSheet> createState() => _TracksSheetState();
}

class _TracksSheetState extends State<_TracksSheet> {
  var _adding = false;

  void _add() {
    setState(() => _adding = true);
    context.read<MeCubit>().loadPublished();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.resolve(context, AppMotion.fast),
    child: BlocBuilder<MeCubit, MeState>(
      key: ValueKey(_adding),
      builder: (context, state) =>
          _adding ? _adder(context, state) : _list(context, state),
    ),
  );

  Widget _list(BuildContext context, MeState state) {
    final colors = context.colors;
    final texts = context.texts;
    final tracks = state.profile?.tracks ?? const <ProfileTrack>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(title: 'me_tracks'.tr()),
        const SizedBox(height: AppSpacing.md),
        for (final track in tracks) ...[
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: track.active,
            child: Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: track.active ? colors.primaryStrong : colors.border,
                  width: track.active ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(track),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      12,
                      10,
                      14,
                      10,
                    ),
                    child: Row(
                      children: [
                        _TrackTile(audience: track.audience),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(track.title, style: texts.bodyStrong),
                              Text(
                                trackLine(track),
                                style: texts.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  minHeight: 4,
                                  value: track.units == 0
                                      ? 0
                                      : (track.unit - 1) / track.units,
                                  color: colors.primary.fill,
                                  backgroundColor: colors.primary.surface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (track.active) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.primaryStrong,
                              shape: BoxShape.circle,
                            ),
                            child: AppIconView(
                              AppIcon.check,
                              size: 16,
                              color: colors.onPrimaryStrong,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
        ],
        DashedBorder(
          color: colors.border,
          radius: 18,
          width: 1.5,
          child: InkWell(
            onTap: _add,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  SizedBox.square(
                    dimension: 48,
                    child: Icon(Icons.add_rounded, color: colors.primary.text),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'me_add_track'.tr(),
                    style: texts.bodyStrong.copyWith(
                      color: colors.primary.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'me_tracks_note'.tr(),
          style: texts.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _adder(BuildContext context, MeState state) {
    final colors = context.colors;
    final texts = context.texts;
    final joined = {
      for (final t in state.profile?.tracks ?? const <ProfileTrack>[])
        t.trackId,
    };
    final published = state.published;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          title: 'me_add_track'.tr(),
          leading: IconButton(
            tooltip: 'common_back'.tr(),
            onPressed: () => setState(() => _adding = false),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (published == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (final track in published) ...[
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.scheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TrackTile(audience: track.audience),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title.of(context.locale.languageCode),
                          style: texts.bodyStrong,
                        ),
                        Text(
                          track.description.of(context.locale.languageCode),
                          style: texts.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs + 2),
                        Container(
                          height: 24,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: colors.background,
                            border: Border.all(
                              color: context.scheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              switch (track.entryMethod) {
                                TrackEntryMethod.placementTest =>
                                  'me_entry_placement'.tr(),
                                TrackEntryMethod.gradeSelection =>
                                  'me_entry_grade'.tr(),
                                TrackEntryMethod.directStart =>
                                  'me_entry_direct'.tr(),
                              },
                              style: texts.captionStrong.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (joined.contains(track.id))
                    Semantics(
                      label: 'me_joined'.tr(),
                      excludeSemantics: true,
                      child: SizedBox.square(
                        dimension: 36,
                        child: AppIconView(
                          AppIcon.checkCircle,
                          size: 24,
                          color: colors.success.fill,
                        ),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onJoin(track);
                      },
                      child: Text('me_join'.tr()),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
          ],
      ],
    );
  }
}

/// «تعديل الاسم»: one field; «حفظ» once it has changed. The new name, or null.
Future<String?> showNameSheet(BuildContext context, String name) =>
    _showMeSheet<String>(context, (_) => _NameSheet(name: name));

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.name});

  final String name;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _field = TextEditingController(
    text: widget.name,
  )..selection = TextSelection(baseOffset: 0, extentOffset: widget.name.length);

  static const _maxLength = 30;

  bool get _changed {
    final name = _field.text.trim();
    return name.isNotEmpty && name != widget.name;
  }

  void _save() {
    if (_changed) Navigator.of(context).pop(_field.text.trim());
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Heading(title: 'me_edit_name'.tr()),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _field,
        autofocus: true,
        maxLength: _maxLength,
        autofillHints: const [AutofillHints.name],
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'me_name_label'.tr(),
          counterText: '',
        ),
      ),
      const SizedBox(height: AppSpacing.lg + 4),
      AppButton(label: 'common_save'.tr(), onPressed: _changed ? _save : null),
    ],
  );
}

/// «تغيير الصف»: the track's grades, the current one checked, kids mode said.
Future<TrackLevel?> showGradeSheet(BuildContext context) {
  final cubit = context.read<MeCubit>()..loadLevels();
  return _showMeSheet<TrackLevel>(
    context,
    (_) => BlocProvider.value(value: cubit, child: const _GradeSheet()),
  );
}

class _GradeSheet extends StatelessWidget {
  const _GradeSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final language = context.locale.languageCode;
    return BlocBuilder<MeCubit, MeState>(
      builder: (context, state) {
        final levels = state.levels;
        final current = state.profile?.active?.levelId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(title: 'me_change_grade'.tr()),
            const SizedBox(height: AppSpacing.md),
            if (levels == null || levels.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.1,
                children: [
                  for (final level in levels)
                    _GradeCell(
                      level: level,
                      current: level.id == current,
                      language: language,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'me_grades_note'.tr(),
              style: texts.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        );
      },
    );
  }
}

class _GradeCell extends StatelessWidget {
  const _GradeCell({
    required this.level,
    required this.current,
    required this.language,
  });

  final TrackLevel level;
  final bool current;
  final String language;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final name = level.name.of(language);
    final parts = [
      name,
      if (current) 'me_grade_current'.tr(),
      if (level.kidsMode) 'me_grade_kids'.tr(),
    ];
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: current,
      label: parts.join('me_list_separator'.tr()),
      excludeSemantics: true,
      child: Material(
        color: current ? colors.primary.surface : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: current ? colors.primaryStrong : colors.border,
            width: current ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(level),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${level.schoolGrade ?? level.order}',
                        style: texts.title.copyWith(
                          fontSize: 20,
                          height: 26 / 20,
                          color: current ? colors.primary.text : null,
                        ),
                      ),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                          height: 18 / 13,
                        ),
                      ),
                      if (level.kidsMode)
                        Container(
                          margin: const EdgeInsetsDirectional.only(
                            top: AppSpacing.xs,
                          ),
                          height: 20,
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 7,
                          ),
                          decoration: BoxDecoration(
                            color: context.scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              'me_kids_mode'.tr(),
                              style: texts.captionStrong.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (current)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryStrong,
                      shape: BoxShape.circle,
                    ),
                    child: AppIconView(
                      AppIcon.check,
                      size: 12,
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

/// A two-digit number in words: «سبعة وأربعون», "forty-seven".
String numberInWords(int number) {
  final ones = switch (number % 10) {
    1 => 'me_ones_1'.tr(),
    2 => 'me_ones_2'.tr(),
    3 => 'me_ones_3'.tr(),
    4 => 'me_ones_4'.tr(),
    5 => 'me_ones_5'.tr(),
    6 => 'me_ones_6'.tr(),
    7 => 'me_ones_7'.tr(),
    8 => 'me_ones_8'.tr(),
    _ => 'me_ones_9'.tr(),
  };
  final tens = switch (number ~/ 10) {
    2 => 'me_tens_2'.tr(),
    3 => 'me_tens_3'.tr(),
    4 => 'me_tens_4'.tr(),
    5 => 'me_tens_5'.tr(),
    6 => 'me_tens_6'.tr(),
    7 => 'me_tens_7'.tr(),
    8 => 'me_tens_8'.tr(),
    _ => 'me_tens_9'.tr(),
  };
  return 'me_number_words'.tr(namedArgs: {'ones': ones, 'tens': tens});
}

/// «لوليّ الأمر فقط»: the number in words to type. What was typed, or null.
Future<String?> showParentGate(BuildContext context, int number) =>
    _showMeSheet<String>(context, (_) => _GateSheet(number: number));

class _GateSheet extends StatefulWidget {
  const _GateSheet({required this.number});

  final int number;

  @override
  State<_GateSheet> createState() => _GateSheetState();
}

class _GateSheetState extends State<_GateSheet> {
  final _field = TextEditingController();

  void _go() {
    if (_field.text.isNotEmpty) Navigator.of(context).pop(_field.text);
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    return Column(
      children: [
        AppIconView(AppIcon.lock, size: 32, color: colors.textSecondary),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          header: true,
          child: Text('me_parent_only'.tr(), style: texts.title),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Text(
          'me_gate_question'.tr(args: [numberInWords(widget.number)]),
          textAlign: TextAlign.center,
          style: texts.body,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 168,
          child: TextField(
            controller: _field,
            autofocus: true,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            maxLength: 3,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _go(),
            inputFormatters: [
              TextInputFormatter.withFunction(
                (_, value) => value.copyWith(
                  text: MeCubit.normalDigits(value.text),
                  selection: TextSelection.collapsed(
                    offset: MeCubit.normalDigits(value.text).length,
                  ),
                ),
              ),
            ],
            style: texts.display.copyWith(fontSize: 34, letterSpacing: 3.4),
            decoration: const InputDecoration(
              hintText: '00',
              counterText: '',
              semanticCounterText: '',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg + 4),
        AppButton(
          label: 'common_continue'.tr(),
          onPressed: _field.text.isEmpty ? null : _go,
        ),
      ],
    );
  }
}
