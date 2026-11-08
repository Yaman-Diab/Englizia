import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/features/home/domain/entities/home.dart';
import 'package:englizia/features/home/presentation/home/widgets/home_texts.dart';
import 'package:englizia/features/home/presentation/home/widgets/map/island_banner.dart';
import 'package:englizia/features/home/presentation/home/widgets/sheets/home_sheet.dart';
import 'package:englizia/features/lessons/presentation/complete/widgets/kind_icon.dart';
import 'package:flutter/material.dart';

/// What the locked unit's preview was left with.
enum LockedSheetAction {
  /// «اذهب إلى الوحدة n»: back to the unit being learned.
  goToCurrent,

  /// «اعرض محتوى الوحدة»: the unit's own screen, locked.
  openUnit,
}

/// A locked unit's preview (frame 13): what it teaches, its
/// first lessons, and the unit to finish first. Null when dismissed.
Future<LockedSheetAction?> showLockedUnitSheet(
  BuildContext context, {
  required HomeUnit unit,
  required HomeUnit current,
}) => showHomeSheet<LockedSheetAction>(
  context,
  builder: (_) => _LockedUnitSheet(unit: unit, current: current),
);

class _LockedUnitSheet extends StatelessWidget {
  const _LockedUnitSheet({required this.unit, required this.current});

  final HomeUnit unit;
  final HomeUnit current;

  /// ASSUMPTION(design): the list stops at five, leaving the unit's review
  /// out, as the design draws it.
  static const _listed = 5;

  /// The link's 44 box grows to a 48 target; its text stays where the
  /// design puts it (margin −10 above, −6 below, in a 14 gap).
  static const _linkTarget = 48.0;
  static const _aboveLink = HomeSheet.gap - 10 - 2;
  static const _belowLink = HomeSheet.gap - 6 - 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final preview = unit.preview;
    final before = unit.lockedBy?.number ?? unit.number - 1;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'home_preview_semantics'.tr(
        namedArgs: {'number': '${unit.number}', 'name': unit.title},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 12,
            children: [
              _Medal(url: unit.coverUrl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'home_preview'.tr(),
                      style: texts
                          .sized(texts.caption, size: 13, line: 20)
                          .copyWith(color: colors.textSecondary),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        unitTitle(unit),
                        style: texts.sized(
                          texts.title,
                          size: 20,
                          line: 28,
                          running: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: HomeSheet.gap),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  'home_preview_goal'.tr(args: [preview.goal]),
                  style: texts.sized(texts.bodyStrong, size: 15, line: 24),
                ),
                Text(
                  'home_preview_meta'.tr(
                    namedArgs: {
                      'lessons': 'home_lessons'.plural(preview.lessons.length),
                      'minutes': minutesText(preview.roundedMinutes),
                    },
                  ),
                  style: texts
                      .sized(texts.caption, size: 13, line: 20)
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
            if (preview.lessons.isNotEmpty) ...[
              const SizedBox(height: HomeSheet.gap),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  for (final lesson in preview.lessons.take(_listed))
                    _LessonRow(lesson: lesson),
                ],
              ),
            ],
          ],
          const SizedBox(height: _aboveLink),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(LockedSheetAction.openUnit),
              style: TextButton.styleFrom(
                foregroundColor: colors.primary.text,
                minimumSize: const Size(_linkTarget, _linkTarget),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: texts.sized(
                  texts.button,
                  size: 14,
                  line: 20,
                  running: false,
                ),
              ),
              child: Text('home_preview_open'.tr()),
            ),
          ),
          const SizedBox(height: _belowLink),
          Semantics(
            container: true,
            liveRegion: true,
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: colors.info.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                spacing: 10,
                children: [
                  AppIconView(AppIcon.lock, size: 14, color: colors.info.fill),
                  Expanded(
                    child: Text(
                      'unit_locked'.tr(args: ['$before']),
                      style: texts
                          .sized(texts.body, size: 14, line: 20)
                          .copyWith(color: colors.info.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HomeSheet.gap),
          HomeSheetButton(
            label: 'unit_go_to'.tr(args: ['${current.number}']),
            onPressed: () =>
                Navigator.of(context).pop(LockedSheetAction.goToCurrent),
          ),
        ],
      ),
    );
  }
}

/// One of the unit's lessons: its kind in a ring, its name, a lock.
class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson});

  final HomePreviewLesson lesson;

  static const _ring = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = colors.textSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        spacing: 10,
        children: [
          Container(
            width: _ring,
            height: _ring,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.scheme.outline, width: 1.5),
            ),
            child: AppIconView(
              lessonKindIcon(lesson.kind),
              size: 16,
              color: muted,
            ),
          ),
          Expanded(
            child: Text(
              lesson.title,
              style: context.texts
                  .sized(context.texts.body, size: 14, line: 22)
                  .copyWith(color: muted),
            ),
          ),
          AppIconView(AppIcon.lock, size: 14, color: muted),
        ],
      ),
    );
  }
}

/// The unit's cover in a 56 circle, faded to show it isn't open yet ("the
/// medal is pale", saturation .3).
class _Medal extends StatelessWidget {
  const _Medal({required this.url});

  final String? url;

  static const _size = 56.0;
  static const _saturation = .3;

  @override
  Widget build(BuildContext context) =>
      UnitMedal(url: url, size: _size, saturation: _saturation);
}
