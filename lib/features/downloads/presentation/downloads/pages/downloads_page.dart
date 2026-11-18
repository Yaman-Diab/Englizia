import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/features/downloads/domain/entities/lesson_download.dart';
import 'package:englizia/features/downloads/presentation/downloads/cubit/downloads_cubit.dart';
import 'package:englizia/features/downloads/presentation/downloads/widgets/download_parts.dart';
import 'package:englizia/features/me/presentation/settings/widgets/settings_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// «التنزيلات»: the room the kept lessons take against what the panel
/// allows, Wi-Fi only or not, and each lesson with a way to remove it.
// ASSUMPTION(design): no design yet; the settings' own groups and rows
// (docs/STATUS.md D-119).
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late final _cubit = context.read<DownloadsCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.loadUsage();
  }

  Future<void> _remove(LessonDownload lesson) async {
    if (!lesson.active && !await confirmRemoveDownload(context)) return;
    await _cubit.remove(lesson.lessonId);
  }

  Future<void> _removeAll() async {
    if (await confirmRemoveDownload(context, all: true)) {
      await _cubit.removeAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'common_back'.tr(),
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text('downloads_title'.tr()),
      ),
      body: BlocConsumer<DownloadsCubit, DownloadsState>(
        // A lesson finished or removed changes the room taken.
        listenWhen: (before, after) =>
            before.keptOf(before.lessons.keys) !=
            after.keptOf(after.lessons.keys),
        listener: (_, _) => _cubit.loadUsage(),
        builder: (context, state) {
          final lessons = state.lessons.values.toList();
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.xl,
            ),
            children: [
              if (state.usage case final usage?) _Usage(usage: usage),
              SettingsGroup(
                title: 'downloads_options'.tr(),
                rows: [
                  SettingsSwitchRow(
                    label: 'downloads_wifi_only'.tr(),
                    subtitle: 'downloads_wifi_only_hint'.tr(),
                    on: state.wifiOnly,
                    onChanged: (on) => _cubit.setWifiOnly(on: on),
                  ),
                ],
              ),
              if (lessons.isEmpty)
                const _Empty()
              else
                SettingsGroup(
                  title: 'downloads_lessons_title'.tr(),
                  rows: [
                    for (final lesson in lessons)
                      SettingsRow(
                        label: lesson.title,
                        subtitle: [
                          if (lesson.unitTitle.isNotEmpty) lesson.unitTitle,
                          downloadStatusText(lesson),
                          if (lesson.bytes > 0) downloadSize(lesson.bytes),
                        ].join('downloads_separator'.tr()),
                        chevron: false,
                        onPressed: () => _remove(lesson),
                      ),
                    SettingsRow(
                      label: 'downloads_remove_all'.tr(),
                      chevron: false,
                      danger: true,
                      onPressed: _removeAll,
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'downloads_note'.tr(),
                textAlign: TextAlign.center,
                style: context.texts.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The room taken, as a bar and in words.
class _Usage extends StatelessWidget {
  const _Usage({required this.usage});

  final DownloadUsage usage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final used = 'downloads_used'.tr(
      namedArgs: {
        'used': downloadSize(usage.usedBytes),
        'max': downloadSize(usage.maxBytes),
      },
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Semantics(
        container: true,
        label: used,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: usage.share,
                  minHeight: 8,
                  color: colors.primary.fill,
                  backgroundColor: colors.border,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(used, style: texts.bodyStrong),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'downloads_lessons_of'.tr(
                  namedArgs: {
                    'count': '${usage.lessons}',
                    'max': '${usage.maxLessons}',
                  },
                ),
                style: texts.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          AppIconView(AppIcon.download, size: 32, color: colors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'downloads_empty_title'.tr(),
            textAlign: TextAlign.center,
            style: context.texts.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'downloads_empty_body'.tr(),
            textAlign: TextAlign.center,
            style: context.texts.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
