import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/action_sheet.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/downloads/domain/entities/lesson_download.dart';
import 'package:englizia/features/downloads/presentation/downloads/cubit/downloads_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ASSUMPTION(design): downloads have no design yet. Everything in this file
// is built from the design system's own parts (docs/STATUS.md D-119).

const _megabyte = 1024 * 1024;

/// «12 م.ب»: one decimal under ten, none above.
String downloadSize(int bytes) {
  if (bytes < _megabyte) return 'downloads_size_small'.tr();
  final megabytes = bytes / _megabyte;
  return 'downloads_size'.tr(
    namedArgs: {
      'size': megabytes < 10
          ? megabytes.toStringAsFixed(1)
          : megabytes.round().toString(),
    },
  );
}

String downloadProblemText(DownloadProblem problem) => switch (problem) {
  DownloadProblem.network => 'downloads_problem_network'.tr(),
  DownloadProblem.waitingForWifi => 'downloads_problem_wifi'.tr(),
  DownloadProblem.overLimit => 'downloads_problem_over_limit'.tr(),
  DownloadProblem.tooManyLessons => 'downloads_problem_too_many'.tr(),
  DownloadProblem.noRoom => 'downloads_problem_no_room'.tr(),
  DownloadProblem.refused => 'downloads_problem_refused'.tr(),
  DownloadProblem.unsupported => 'downloads_problem_unsupported'.tr(),
};

/// Where a download stands, in words: the list's second line, and what a
/// screen reader says.
String downloadStatusText(LessonDownload download, {DateTime? now}) {
  if (download.problem case final problem?) return downloadProblemText(problem);
  return switch (download.status) {
    DownloadStatus.queued => 'downloads_status_queued'.tr(),
    DownloadStatus.downloading => 'downloads_status_downloading'.tr(
      namedArgs: {'percent': '${((download.progress ?? 0) * 100).round()}'},
    ),
    DownloadStatus.done when download.expiredAt(now ?? DateTime.now()) =>
      'downloads_status_expired'.tr(),
    DownloadStatus.done => 'downloads_status_done'.tr(),
    DownloadStatus.failed => 'downloads_problem_network'.tr(),
  };
}

/// Asks before removing a download; true when it is to go.
Future<bool> confirmRemoveDownload(BuildContext context, {bool all = false}) =>
    showActionSheet(
      context,
      icon: AppIcon.download,
      title: all
          ? 'downloads_remove_all_title'.tr()
          : 'downloads_remove_title'.tr(),
      body: 'downloads_remove_body'.tr(),
      primaryLabel: 'downloads_keep'.tr(),
      secondaryLabel: 'downloads_remove'.tr(),
      destructiveSecondary: true,
    ).then((action) => action == SheetAction.secondary);

/// A lesson's download, at the end of its row: one mark per state, each with
/// its own shape so none is told by color alone. Pressing it does what the
/// state calls for: download, stop, remove (after asking) or try again.
class LessonDownloadButton extends StatelessWidget {
  const LessonDownloadButton({required this.request, super.key});

  final DownloadRequest request;

  static const _size = 48.0;
  static const _ring = 28.0;
  static const _icon = 22.0;

  Future<void> _press(BuildContext context, LessonDownload? download) async {
    final cubit = context.read<DownloadsCubit>();
    switch (download?.status) {
      case null || DownloadStatus.failed:
        await cubit.download([request]);
      case DownloadStatus.queued || DownloadStatus.downloading:
        await cubit.remove(request.lessonId);
      case DownloadStatus.done:
        if (await confirmRemoveDownload(context)) {
          await cubit.remove(request.lessonId);
        }
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<DownloadsCubit, DownloadsState, (bool, LessonDownload?)>(
        selector: (state) => (state.available, state.lessons[request.lessonId]),
        builder: (context, selected) {
          final (available, download) = selected;
          if (!available) return const SizedBox.shrink();
          final colors = context.colors;
          final title = {'title': request.title};
          final (AppIcon icon, Color color, String label) = switch (download) {
            null => (
              AppIcon.download,
              colors.textSecondary,
              'downloads_action_download'.tr(namedArgs: title),
            ),
            LessonDownload(problem: DownloadProblem.waitingForWifi) => (
              AppIcon.wifiOff,
              colors.textSecondary,
              'downloads_action_cancel'.tr(namedArgs: title),
            ),
            LessonDownload(status: DownloadStatus.queued) => (
              AppIcon.clock,
              colors.textSecondary,
              'downloads_action_cancel'.tr(namedArgs: title),
            ),
            LessonDownload(status: DownloadStatus.downloading) => (
              AppIcon.cross,
              colors.primary.text,
              'downloads_action_cancel'.tr(namedArgs: title),
            ),
            LessonDownload(status: DownloadStatus.done) => (
              AppIcon.checkCircle,
              colors.success.fill,
              'downloads_action_remove'.tr(namedArgs: title),
            ),
            LessonDownload(status: DownloadStatus.failed) => (
              AppIcon.alertTriangle,
              colors.error.text,
              'downloads_action_retry'.tr(namedArgs: title),
            ),
          };
          final downloading = download?.status == DownloadStatus.downloading;
          return Semantics(
            button: true,
            label: label,
            value: download == null ? null : downloadStatusText(download),
            excludeSemantics: true,
            child: Tooltip(
              message: download?.problem == null
                  ? ''
                  : downloadProblemText(download!.problem!),
              child: InkResponse(
                radius: _size / 2,
                onTap: () => _press(context, download),
                child: SizedBox.square(
                  dimension: _size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (downloading)
                        SizedBox.square(
                          dimension: _ring,
                          child: CircularProgressIndicator(
                            value: download?.progress,
                            strokeWidth: 2.5,
                            color: colors.primary.fill,
                            backgroundColor: colors.border,
                          ),
                        ),
                      AppIconView(
                        icon,
                        size: downloading ? _icon - 8 : _icon,
                        color: color,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}

/// «نزّل الوحدة»: every lesson of a unit at once, after saying what it takes.
/// Once they are all on the phone it says so instead.
class UnitDownloadButton extends StatelessWidget {
  const UnitDownloadButton({required this.requests, super.key});

  /// The unit's lessons that can be downloaded.
  final List<DownloadRequest> requests;

  Future<void> _press(BuildContext context) async {
    final cubit = context.read<DownloadsCubit>();
    final result = await cubit.estimate(requests);
    if (!context.mounted) return;
    switch (result) {
      case Err(:final failure):
        showFailureSnackBar(context, failure);
      case Ok(value: DownloadEstimate(lessons: 0)):
        showNoticeSnackBar(
          context,
          icon: AppIcon.infoCircle,
          text: 'downloads_nothing'.tr(),
          tone: context.colors.info,
        );
      case Ok(value: DownloadEstimate(:final problem?)):
        showNoticeSnackBar(
          context,
          icon: AppIcon.alertTriangle,
          text: downloadProblemText(problem),
          tone: context.colors.error,
        );
      case Ok(:final value):
        final free = value.usage.freeBytes;
        final action = await showActionSheet(
          context,
          icon: AppIcon.download,
          title: 'downloads_confirm_title'.tr(),
          body: [
            'downloads_confirm_body'.tr(
              namedArgs: {
                'lessons': 'downloads_lessons'.plural(value.lessons),
                'size': downloadSize(value.bytes),
              },
            ),
            if (free != null)
              'downloads_confirm_free'.tr(
                namedArgs: {'free': downloadSize(free)},
              ),
            if (cubit.state.wifiOnly) 'downloads_confirm_wifi'.tr(),
          ].join('\n'),
          primaryLabel: 'downloads_confirm_start'.tr(),
          secondaryLabel: 'common_cancel'.tr(),
        );
        if (action == SheetAction.primary) await cubit.download(requests);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DownloadsCubit, DownloadsState>(
        buildWhen: (before, after) =>
            before.available != after.available ||
            before.asking != after.asking ||
            before.lessons != after.lessons,
        builder: (context, state) {
          if (!state.available || requests.isEmpty) {
            return const SizedBox.shrink();
          }
          final ids = [for (final request in requests) request.lessonId];
          final kept = state.keptOf(ids);
          if (kept == ids.length) {
            return _Kept(text: 'downloads_unit_done'.tr());
          }
          final active = state.anyActive(ids);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: 'downloads_unit_action'.tr(),
                variant: AppButtonVariant.secondary,
                isLoading: state.asking || active,
                onPressed: state.asking || active
                    ? null
                    : () => _press(context),
              ),
              if (kept > 0 || active) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'downloads_unit_progress'.tr(
                    namedArgs: {'done': '$kept', 'total': '${ids.length}'},
                  ),
                  textAlign: TextAlign.center,
                  style: context.texts.caption.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ],
          );
        },
      );
}

class _Kept extends StatelessWidget {
  const _Kept({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIconView(AppIcon.checkCircle, size: 20, color: colors.success.fill),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            style: context.texts.bodyStrong.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
