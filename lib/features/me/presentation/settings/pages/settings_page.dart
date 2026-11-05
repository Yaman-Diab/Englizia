import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/clock_format.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/settings/settings_cubit.dart';
import 'package:englizia/core/settings/settings_state.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/me/widgets/me_sheets.dart';
import 'package:englizia/features/me/presentation/settings/cubit/preferences_cubit.dart';
import 'package:englizia/features/me/presentation/settings/widgets/settings_parts.dart';
import 'package:englizia/features/onboarding/presentation/reminder/widgets/reminder_time_sheet.dart';
import 'package:englizia/features/settings/domain/entities/effective_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the settings lead to outside themselves.
final class SettingsActions {
  const SettingsActions({
    required this.onBack,
    required this.onWhatsApp,
    required this.onPrivacy,
    required this.onTerms,
    required this.onSignOut,
    required this.onCreateAccount,
    required this.onVerifyEmail,
    required this.onPassword,
    required this.onDelete,
    required this.onMail,
    required this.version,
    required this.platform,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onWhatsApp;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final Future<void> Function() onSignOut;
  final VoidCallback onCreateAccount;
  final Future<void> Function() onVerifyEmail;

  /// True once the new password was saved.
  final Future<bool?> Function() onPassword;
  final VoidCallback onDelete;

  /// Opens a mail to write; false when the phone has nothing to write with.
  final Future<bool> Function(Uri mail) onMail;
  final String version;
  final String platform;
}

/// The settings (S §19.2, design "Settings"): each saved as it changes, with
/// no «حفظ». Notifications are all or none (owner, 2026-11-05).
class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.actions, super.key});

  final SettingsActions actions;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppLifecycleListener _lifecycle;

  SettingsActions get _actions => widget.actions;

  @override
  void initState() {
    super.initState();
    // Back from the phone's settings, notifications may be allowed now.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<PreferencesCubit>().recheck(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _failed(Failure? failure) {
    if (failure != null && mounted) showFailureSnackBar(context, failure);
  }

  Future<void> _rename(Profile profile) async {
    final cubit = context.read<MeCubit>();
    final name = await showNameSheet(context, profile.name);
    if (name == null) return;
    _failed(await cubit.rename(name));
  }

  Future<void> _goal(PreferencesState state) async {
    final goals = state.goals;
    final preferences = state.preferences;
    if (goals == null || preferences == null) return;
    final cubit = context.read<PreferencesCubit>();
    final minutes = await showGoalSheet(
      context,
      goals: goals,
      current: preferences.dailyGoalMinutes,
    );
    if (minutes != null) _failed(await cubit.setGoal(minutes));
  }

  Future<void> _reminder(PreferencesState state) async {
    final preferences = state.preferences;
    if (preferences == null) return;
    final cubit = context.read<PreferencesCubit>();
    final hour = preferences.reminderHour;
    final time = await showReminderTimeSheet(
      context,
      initial: hour != null
          ? ReminderTime(hour, preferences.reminderMinute)
          : state.defaultReminder ?? ReminderTime(DateTime.now().hour, 0),
    );
    if (time != null) _failed(await cubit.setReminder(time.hour, time.minute));
  }

  Future<void> _grade() async {
    final cubit = context.read<MeCubit>();
    final level = await showGradeSheet(context);
    if (level != null) _failed(await cubit.changeLevel(level));
  }

  Future<void> _language() async {
    final locale = await showLanguageSheet(context, context.locale);
    if (locale != null && mounted) await context.setLocale(locale);
  }

  Future<void> _appearance(ThemeMode current) async {
    final cubit = context.read<SettingsCubit>();
    final mode = await showAppearanceSheet(context, current);
    if (mode != null) await cubit.setThemeMode(mode);
  }

  Future<void> _quality(PreferencesState state) async {
    final cubit = context.read<PreferencesCubit>();
    final quality = await showQualitySheet(context, state.videoQuality);
    if (quality != null) await cubit.setVideoQuality(quality);
  }

  Future<void> _password() async {
    final saved = await _actions.onPassword();
    if (saved != true || !mounted) return;
    showNoticeSnackBar(
      context,
      icon: AppIcon.checkCircle,
      text: 'settings_password_saved'.tr(),
      tone: context.colors.success,
    );
  }

  Future<void> _signOut(bool guest) async {
    final leave = await showSignOutSheet(context, guest: guest);
    if (leave == null) return;
    if (leave) {
      await _actions.onSignOut();
    } else {
      _actions.onCreateAccount();
    }
  }

  void _about() {
    final email = 'about_email'.tr();
    showAboutSheet(
      context,
      version: _actions.version,
      onWrite: () async {
        final opened = await _actions.onMail(
          Uri(
            scheme: 'mailto',
            path: email,
            query: _query({
              'subject': 'about_mail_subject'.tr(),
              'body':
                  '\n\n${'about_mail_body'.tr(namedArgs: {'version': _actions.version, 'platform': _actions.platform})}',
            }),
          ),
        );
        if (!opened && mounted) {
          showNoticeSnackBar(
            context,
            icon: AppIcon.infoCircle,
            text: 'about_no_mail'.tr(),
            tone: context.colors.info,
          );
        }
      },
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: email));
        if (!mounted) return;
        showNoticeSnackBar(
          context,
          icon: AppIcon.checkCircle,
          text: 'about_copied'.tr(),
          tone: context.colors.success,
        );
      },
    );
  }

  /// Mail apps want spaces as `%20`, not the `+` of [Uri.queryParameters].
  static String _query(Map<String, String> parameters) => parameters.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'common_back'.tr(),
          onPressed: _actions.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text('settings_title'.tr()),
      ),
      body: BlocBuilder<MeCubit, MeState>(
        builder: (context, me) =>
            BlocBuilder<PreferencesCubit, PreferencesState>(
              builder: (context, state) =>
                  BlocBuilder<SettingsCubit, SettingsState>(
                    builder: (context, device) => ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.xl - AppSpacing.xs,
                        AppSpacing.sm,
                        AppSpacing.xl - AppSpacing.xs,
                        AppSpacing.xl,
                      ),
                      children: [
                        ..._account(me),
                        ..._learning(me, state),
                        ..._display(device),
                        ..._sound(device, state),
                        _support(me),
                        _leave(me),
                        const SizedBox(height: 28),
                        Text(
                          'settings_version'.tr(args: [_actions.version]),
                          textAlign: TextAlign.center,
                          style: context.texts.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
      ),
    );
  }

  List<Widget> _account(MeState me) {
    final profile = me.profile;
    if (profile == null) return const [];
    final email = profile.email;
    final rows = <Widget>[
      SettingsRow(
        label: 'settings_name'.tr(),
        value: profile.name,
        onPressed: () => _rename(profile),
      ),
      if (me.guest || email == null)
        SettingsRow(
          label: 'me_create_account'.tr(),
          onPressed: _actions.onCreateAccount,
        )
      else ...[
        SettingsRow(
          label: 'settings_email'.tr(),
          value: email,
          valueDirection: TextDirection.ltr,
          badge: profile.emailVerified ? const VerifiedBadge() : null,
          subtitle: profile.emailVerified ? null : 'me_unverified'.tr(),
          onPressed: profile.emailVerified ? null : _actions.onVerifyEmail,
          chevron: !profile.emailVerified,
        ),
        if (profile.signIn == SignInMethod.email)
          SettingsRow(
            label: 'settings_password'.tr(),
            value: 'settings_change'.tr(),
            onPressed: _password,
          ),
        SettingsRow(
          label: 'settings_sign_in'.tr(),
          value: switch (profile.signIn) {
            SignInMethod.email => 'settings_sign_in_email'.tr(),
            SignInMethod.google => 'settings_google'.tr(),
            SignInMethod.apple => 'settings_apple'.tr(),
          },
          valueDirection: profile.signIn == SignInMethod.email
              ? null
              : TextDirection.ltr,
          chevron: false,
        ),
      ],
    ];
    return [SettingsGroup(title: 'settings_account'.tr(), rows: rows)];
  }

  List<Widget> _learning(MeState me, PreferencesState state) {
    final preferences = state.preferences;
    final cubit = context.read<PreferencesCubit>();
    if (preferences == null) {
      return [
        if (state.failure != null)
          SettingsGroup(
            title: 'settings_learning'.tr(),
            rows: [
              SettingsRow(
                label: state.failure!.localizedMessage,
                value: 'common_retry'.tr(),
                onPressed: cubit.start,
              ),
            ],
          ),
      ];
    }
    final track = me.profile?.active;
    final hour = preferences.reminderHour;
    return [
      SettingsGroup(
        title: 'settings_learning'.tr(),
        rows: [
          SettingsRow(
            label: 'settings_goal'.tr(),
            value: 'settings_goal_value'.tr(
              args: ['${preferences.dailyGoalMinutes}'],
            ),
            onPressed: state.goals == null ? null : () => _goal(state),
          ),
          SettingsRow(
            label: 'settings_reminder'.tr(),
            value: hour == null
                ? 'settings_reminder_none'.tr()
                : formatClock(hour, preferences.reminderMinute),
            onPressed: () => _reminder(state),
          ),
          if (track != null && track.isSchool)
            SettingsRow(
              label: 'settings_grade'.tr(),
              value: track.levelName,
              onPressed: _grade,
            ),
        ],
      ),
      SettingsGroup(
        title: 'settings_notifications'.tr(),
        above: state.phoneBlocks
            ? NotificationsBlocked(onOpen: cubit.openPhoneSettings)
            : null,
        rows: [
          SettingsSwitchRow(
            label: 'settings_notifications_allow'.tr(),
            subtitle: 'settings_notifications_hint'.tr(),
            on: state.notificationsOn,
            enabled: !state.phoneBlocks,
            onChanged: (on) async =>
                _failed(await cubit.setNotifications(on: on)),
          ),
        ],
      ),
    ];
  }

  List<Widget> _display(SettingsState device) => [
    SettingsGroup(
      title: 'settings_display'.tr(),
      rows: [
        SettingsRow(
          label: 'settings_app_language'.tr(),
          value: context.locale.languageCode == 'en'
              ? 'settings_language_en'.tr()
              : 'settings_language_ar'.tr(),
          onPressed: _language,
        ),
        SettingsRow(
          label: 'settings_theme'.tr(),
          value: themeName(device.themeMode),
          onPressed: () => _appearance(device.themeMode),
        ),
      ],
    ),
  ];

  List<Widget> _sound(SettingsState device, PreferencesState state) {
    final settings = context.read<SettingsCubit>();
    return [
      SettingsGroup(
        title: 'settings_sound'.tr(),
        rows: [
          SettingsSwitchRow(
            label: 'settings_sound_effects'.tr(),
            on: device.soundEffects,
            onChanged: (on) => settings.setSoundEffects(on: on),
          ),
          SettingsSwitchRow(
            label: 'settings_vibration'.tr(),
            on: device.vibration,
            onChanged: (on) => settings.setVibration(on: on),
          ),
          SettingsRow(
            label: 'settings_video_quality'.tr(),
            subtitle: 'settings_video_hint'.tr(),
            value: qualityName(state.videoQuality),
            onPressed: () => _quality(state),
          ),
        ],
      ),
    ];
  }

  Widget _support(MeState me) {
    final whatsapp = me.profile?.whatsapp;
    return SettingsGroup(
      title: 'settings_support'.tr(),
      rows: [
        if (whatsapp != null)
          SettingsRow(
            label: 'settings_whatsapp'.tr(),
            onPressed: () => _actions.onWhatsApp(whatsapp),
          ),
        SettingsRow(
          label: 'settings_privacy'.tr(),
          onPressed: _actions.onPrivacy,
        ),
        SettingsRow(label: 'settings_terms'.tr(), onPressed: _actions.onTerms),
        SettingsRow(label: 'settings_about'.tr(), onPressed: _about),
      ],
    );
  }

  Widget _leave(MeState me) => SettingsGroup(
    title: 'settings_account'.tr(),
    rows: [
      SettingsRow(
        label: 'settings_sign_out'.tr(),
        chevron: false,
        onPressed: () => _signOut(me.guest),
      ),
      if (!me.guest)
        SettingsRow(
          label: 'settings_delete'.tr(),
          chevron: false,
          danger: true,
          onPressed: _actions.onDelete,
        ),
    ],
  );
}
