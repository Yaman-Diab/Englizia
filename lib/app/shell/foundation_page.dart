import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/app/shell/launch_preview.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/account/presentation/account/cubit/account_cubit.dart';
import 'package:englizia/features/account/presentation/account/widgets/account_card.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_banner.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_host.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_row.dart';
import 'package:englizia/features/home/data/datasources/home_mock_scenarios.dart';
import 'package:englizia/features/home/data/datasources/home_remote_data_source.dart';
import 'package:englizia/features/lessons/domain/entities/exercise.dart';
import 'package:englizia/features/lessons/domain/entities/lesson_result.dart';
import 'package:englizia/features/lessons/domain/repositories/lesson_repository.dart';
import 'package:englizia/features/me/domain/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route `extra` of home from the dev page: starts it afresh, so a scenario
/// shows from its first load.
final class HomeRestart {
  HomeRestart();
}

/// The dev page (`/dev`, reached from home's top bar by a long press in mock
/// mode): theme, language and direction on a device, the email's row and the
/// account card, and in mock mode the scenarios of home and the other mocks.
class FoundationPage extends StatelessWidget {
  const FoundationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final themeMode = context.select((SettingsCubit c) => c.state.themeMode);

    return Scaffold(
      appBar: AppBar(title: Text('app_name'.tr())),
      body: BlocProvider(
        create: (_) => sl<VerifyEmailCubit>()..load(),
        child: VerifyEmailHost(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.screenGutter),
            children: [
              // Home shows it after the first lesson; here, as soon as it
              // applies.
              const VerifyEmailBanner(),
              Text('foundation_title'.tr(), style: texts.title),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'foundation_body'.tr(),
                style: texts.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('settings_language'.tr(), style: texts.bodyStrong),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<Locale>(
                segments: [
                  ButtonSegment(
                    value: AppLocales.arabic,
                    label: Text('settings_language_ar'.tr()),
                  ),
                  ButtonSegment(
                    value: AppLocales.english,
                    label: Text('settings_language_en'.tr()),
                  ),
                ],
                selected: {context.locale},
                onSelectionChanged: (s) => context.setLocale(s.first),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('settings_theme'.tr(), style: texts.bodyStrong),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('settings_theme_system'.tr()),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('settings_theme_light'.tr()),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('settings_theme_dark'.tr()),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    context.read<SettingsCubit>().setThemeMode(s.first),
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ToneChip(
                    tone: colors.success,
                    icon: Icons.check_circle_outline,
                    label: 'preview_correct'.tr(),
                  ),
                  _ToneChip(
                    tone: colors.error,
                    icon: Icons.cancel_outlined,
                    label: 'preview_incorrect'.tr(),
                  ),
                  _ToneChip(
                    tone: colors.reward,
                    icon: Icons.star_outline,
                    label: 'preview_xp'.tr(namedArgs: {'count': '10'}),
                  ),
                  _ToneChip(
                    tone: colors.ai,
                    icon: Icons.auto_awesome_outlined,
                    label: 'preview_ai'.tr(),
                  ),
                  _ToneChip(
                    tone: colors.info,
                    icon: Icons.volume_up_outlined,
                    label: 'preview_listen'.tr(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              if (AppConfig.isMock) ...[
                Text('foundation_home_title'.tr(), style: texts.bodyStrong),
                const SizedBox(height: AppSpacing.sm),
                for (final (scenario, label) in [
                  (HomeMockScenario.general, 'foundation_home_general'.tr()),
                  (HomeMockScenario.firstDay, 'foundation_home_first_day'.tr()),
                  (HomeMockScenario.partial, 'foundation_home_partial'.tr()),
                  (HomeMockScenario.goalReached, 'foundation_home_goal'.tr()),
                  (HomeMockScenario.atRisk, 'foundation_home_risk'.tr()),
                  (HomeMockScenario.welcomeBack, 'foundation_home_back'.tr()),
                  (HomeMockScenario.freezeUsed, 'foundation_home_freeze'.tr()),
                  (HomeMockScenario.streakBroken, 'foundation_home_broke'.tr()),
                  (HomeMockScenario.levelCheck, 'foundation_home_check'.tr()),
                  (
                    HomeMockScenario.placementDeferred,
                    'foundation_home_test'.tr(),
                  ),
                  (
                    HomeMockScenario.lastLesson,
                    'foundation_home_last_lesson'.tr(),
                  ),
                  (HomeMockScenario.lastUnit, 'foundation_home_last_unit'.tr()),
                  (
                    HomeMockScenario.levelComplete,
                    'foundation_home_level_done'.tr(),
                  ),
                  (HomeMockScenario.newRow, 'foundation_home_new_row'.tr()),
                  (
                    HomeMockScenario.lessons4,
                    'foundation_home_lessons'.tr(args: ['4']),
                  ),
                  (
                    HomeMockScenario.lessons8,
                    'foundation_home_lessons'.tr(args: ['8']),
                  ),
                  (
                    HomeMockScenario.lessons10,
                    'foundation_home_lessons'.tr(args: ['10']),
                  ),
                  (HomeMockScenario.offline, 'foundation_home_offline'.tr()),
                  (
                    HomeMockScenario.offlineEmpty,
                    'foundation_home_offline_empty'.tr(),
                  ),
                  (
                    HomeMockScenario.refreshFails,
                    'foundation_home_refresh_fails'.tr(),
                  ),
                  (HomeMockScenario.slow, 'foundation_home_slow'.tr()),
                  (HomeMockScenario.v01, 'foundation_home_v01'.tr()),
                ]) ...[
                  OutlinedButton(
                    onPressed: () => unawaited(_tryHome(context, scenario)),
                    child: Text(label),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                OutlinedButton(
                  onPressed: () async {
                    await sl<ProfileRepository>().switchTrack(_emar);
                    await sl<SettingsStorageService>().removeHome();
                    if (context.mounted) _home(context);
                  },
                  child: Text('foundation_home_emar'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () async {
                    await sl<SettingsStorageService>().setHomeOpeningDay(null);
                    if (context.mounted) _home(context);
                  },
                  child: Text('foundation_home_opening'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                // The mock recommends a newer version: home offers it again.
                OutlinedButton(
                  onPressed: () async {
                    await sl<SettingsStorageService>().setUpdateReminderDay('');
                    if (context.mounted) _home(context);
                  },
                  child: Text('foundation_update_reminder'.tr()),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('foundation_splash_title'.tr(), style: texts.bodyStrong),
                const SizedBox(height: AppSpacing.sm),
                for (final (preview, label) in [
                  (LaunchPreview.slow, 'foundation_splash_slow'.tr()),
                  (LaunchPreview.offline, 'foundation_splash_offline'.tr()),
                  (LaunchPreview.update, 'foundation_splash_update'.tr()),
                  (
                    LaunchPreview.storeFails,
                    'foundation_splash_store_fails'.tr(),
                  ),
                ]) ...[
                  OutlinedButton(
                    onPressed: () => previewLaunch(context, preview),
                    child: Text(label),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () =>
                      context.push(AppRoutes.exercisesOf('les_mock')),
                  child: Text('foundation_try_exercises'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Without answering a whole lesson: a new scenario on each press.
                OutlinedButton(
                  onPressed: () async {
                    final lesson = await sl<LessonRepository>().getLesson(
                      'les_mock',
                    );
                    if (lesson is! Ok<Lesson> || !context.mounted) return;
                    await context.push(
                      AppRoutes.completeOf('les_mock'),
                      extra: LessonSummary(
                        lessonId: 'les_mock',
                        lessonVersion: lesson.value.version,
                        rightFirstTime: 5,
                        counted: 6,
                        pending: 0,
                        seconds: 420,
                        outline: lesson.value.outline,
                      ),
                    );
                  },
                  child: Text('foundation_try_complete'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.grammarOf('les_gv')),
                  child: Text('foundation_try_grammar'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () =>
                      context.push(AppRoutes.grammarOf('les_book')),
                  child: Text('foundation_try_rule'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.textOf('les_it')),
                  child: Text('foundation_try_text'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () =>
                      context.push(AppRoutes.textOf('les_it_broken')),
                  child: Text('foundation_try_text_broken'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.videoOf('les_iv')),
                  child: Text('foundation_try_video'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () =>
                      context.push(AppRoutes.vocabularyOf('les_voc')),
                  child: Text('foundation_try_vocabulary'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.kidsOf('les_kid')),
                  child: Text('foundation_try_kids'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () =>
                      context.push(AppRoutes.kidsOf('les_kid_media')),
                  child: Text('foundation_try_kid_media'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.kidsWords),
                  child: Text('foundation_try_kid_words'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final (unitId, label) in [
                  ('unit_gen_a2_03', 'foundation_try_unit'.tr()),
                  ('unit_emar_07_03', 'foundation_try_unit_emar'.tr()),
                  ('unit_kids_s2_02', 'foundation_try_unit_kids'.tr()),
                  ('unit_gen_a2_04', 'foundation_try_unit_locked'.tr()),
                ]) ...[
                  OutlinedButton(
                    onPressed: () => context.push(AppRoutes.unitOf(unitId)),
                    child: Text(label),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.practice),
                  child: Text('foundation_try_practice'.tr()),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const VerifyEmailRow(),
              BlocProvider(
                create: (_) => sl<AccountCubit>(),
                child: AccountCard(
                  onCreateAccount: () => context.push(AppRoutes.signUp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The mock's enrollment of the Emar curriculum.
  static const _emar = 'enr_emar';

  static void _home(BuildContext context) =>
      context.go(AppRoutes.home, extra: HomeRestart());

  /// Home as [scenario]'s frame, from its first load, its one-time notices
  /// unseen again; nothing kept shows first, but offline shows what was.
  static Future<void> _tryHome(
    BuildContext context,
    HomeMockScenario scenario,
  ) async {
    final settings = sl<SettingsStorageService>();
    sl<HomeMockControls>().scenario = scenario;
    sl<LessonRepository>().forgetCompletions();
    await settings.setHomeSeenEvents(const []);
    if (scenario != HomeMockScenario.offline) await settings.removeHome();
    if (context.mounted) _home(context);
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({
    required this.tone,
    required this.icon,
    required this.label,
  });

  final ToneColors tone;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconSm, color: tone.fill),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: context.texts.captionStrong.copyWith(color: tone.text),
            ),
          ],
        ),
      ),
    );
  }
}
