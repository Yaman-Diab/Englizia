import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/app/router/app_routes.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/design_system/app_semantic_colors.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/l10n/app_locales.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/features/account/presentation/account/cubit/account_cubit.dart';
import 'package:englizia/features/account/presentation/account/widgets/account_card.dart';
import 'package:englizia/features/account/presentation/verify_email/cubit/verify_email_cubit.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_banner.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_host.dart';
import 'package:englizia/features/account/presentation/verify_email/widgets/verify_email_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Temporary home: lets you check theme, language and direction on a device,
/// and holds the account card until «أنا» exists. Replaced by the "Learn"
/// tab in v0.1.
class FoundationPage extends StatelessWidget {
  const FoundationPage({this.sendEmailLink = false, super.key});

  /// Opened by an expired link's «أرسل رابطًا جديدًا»: sends one at once.
  final bool sendEmailLink;

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
          sendLink: sendEmailLink,
          child: ListView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.screenGutter),
            children: [
              // Here until home has its place for it, under its top bar.
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
              // Until the unit screen opens lessons, a way to try the exercises.
              if (AppConfig.isMock) ...[
                OutlinedButton(
                  onPressed: () =>
                      context.push(AppRoutes.exercisesOf('les_mock')),
                  child: Text('foundation_try_exercises'.tr()),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              // Here until «أنا» has its account section.
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
