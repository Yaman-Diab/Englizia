import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/kids/kid_parts.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:englizia/core/design_system/widgets/app_state_view.dart';
import 'package:englizia/core/design_system/widgets/failure_snack_bar.dart';
import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/l10n/failure_l10n.dart';
import 'package:englizia/core/state/load_status.dart';
import 'package:englizia/features/me/domain/entities/profile.dart';
import 'package:englizia/features/me/presentation/me/cubit/me_cubit.dart';
import 'package:englizia/features/me/presentation/me/widgets/me_sections.dart';
import 'package:englizia/features/me/presentation/me/widgets/me_sheets.dart';
import 'package:englizia/features/me/presentation/me/widgets/sea_art.dart';
import 'package:englizia/features/tracks/domain/entities/learning_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What «أنا» leads to outside itself.
final class MeActions {
  const MeActions({
    required this.onSettings,
    required this.onPrivacy,
    required this.onWhatsApp,
    required this.onPractice,
    required this.onCreateAccount,
    required this.onSignOut,
    required this.onVerifyEmail,
    required this.onRetest,
    required this.onJoin,
  });

  final VoidCallback onSettings;
  final VoidCallback onPrivacy;
  final ValueChanged<String> onWhatsApp;
  final VoidCallback onPractice;
  final VoidCallback onCreateAccount;
  final Future<void> Function() onSignOut;

  /// Opens «أكّد بريدك»; done when it closes.
  final Future<void> Function() onVerifyEmail;
  final VoidCallback onRetest;
  final ValueChanged<LearningTrack> onJoin;
}

/// The «أنا» tab (S §19.1, §13.5; design "Me v2"); kids get their own.
class MePage extends StatelessWidget {
  const MePage({required this.actions, super.key});

  final MeActions actions;

  static bool isKids(MeState state) =>
      state.profile?.active?.audience == TrackAudience.child;

  @override
  Widget build(BuildContext context) => BlocConsumer<MeCubit, MeState>(
    listenWhen: (before, now) => before.switches != now.switches,
    listener: (context, state) => showNoticeSnackBar(
      context,
      icon: AppIcon.checkCircle,
      text: 'me_switched'.tr(args: [state.switched ?? '']),
      tone: context.colors.success,
      duration: AppMotion.meSwitchHold,
    ),
    builder: (context, state) {
      final profile = state.profile;
      if (profile == null) {
        return state.load == LoadStatus.failure
            ? AppStateView.error(
                message: state.failure?.localizedMessage ?? '',
                onRetry: context.read<MeCubit>().refresh,
              )
            : const AppStateView.loading();
      }
      return isKids(state)
          ? _KidMe(state: state, actions: actions)
          : _Me(state: state, actions: actions);
    },
  );
}

void _failed(BuildContext context, Failure? failure) {
  if (failure != null && context.mounted) {
    showFailureSnackBar(context, failure);
  }
}

class _Me extends StatelessWidget {
  const _Me({required this.state, required this.actions});

  final MeState state;
  final MeActions actions;

  Future<void> _rename(BuildContext context, Profile profile) async {
    final cubit = context.read<MeCubit>();
    final name = await showNameSheet(context, profile.name);
    if (name == null || !context.mounted) return;
    final failure = await cubit.rename(name);
    if (context.mounted) _failed(context, failure);
  }

  Future<void> _switch(BuildContext context) async {
    final cubit = context.read<MeCubit>();
    final track = await showTracksSheet(context, onJoin: actions.onJoin);
    if (track == null || !context.mounted) return;
    final failure = await cubit.switchTrack(track);
    if (context.mounted) _failed(context, failure);
  }

  Future<void> _grade(BuildContext context) async {
    final cubit = context.read<MeCubit>();
    final level = await showGradeSheet(context);
    if (level == null || !context.mounted) return;
    final failure = await cubit.changeLevel(level);
    if (context.mounted) _failed(context, failure);
  }

  Future<void> _verify(BuildContext context) async {
    await actions.onVerifyEmail();
    if (context.mounted) await context.read<MeCubit>().refresh();
  }

  Future<void> _signOut(BuildContext context) async {
    final leave = await showSignOutSheet(context, guest: state.guest);
    if (leave == null || !context.mounted) return;
    if (leave) {
      await actions.onSignOut();
    } else {
      actions.onCreateAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = state.profile!;
    final track = profile.active;
    final week = profile.week;
    final bank = profile.wordBank;
    final placement = profile.placement;
    final whatsapp = profile.whatsapp;
    final account = profile.accountNumber;
    final colors = context.colors;
    return Semantics(
      label: 'me_title'.tr(),
      explicitChildNodes: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MeHeader(
              profile: profile,
              guest: state.guest,
              drift: state.firstView,
              onSettings: actions.onSettings,
            ),
            MeIdentity(
              profile: profile,
              guest: state.guest,
              onEditName: () => _rename(context, profile),
              onVerify: () => _verify(context),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.xl - AppSpacing.xs,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.xl,
                children: [
                  if (state.guest)
                    GuestCard(onCreateAccount: actions.onCreateAccount),
                  if (track != null)
                    AnimatedSwitcher(
                      duration: AppMotion.resolve(context, AppMotion.medium),
                      child: TrackCard(
                        key: ValueKey('${track.enrollmentId}${track.levelId}'),
                        track: track,
                        onSwitch: () => _switch(context),
                        onGrade: () => _grade(context),
                      ),
                    ),
                  MeAchievements(
                    profile: profile,
                    count: state.firstView,
                    onStreak: () => showStreakSheet(context, profile),
                  ),
                  if (week != null) WeekCard(week: week, grow: state.firstView),
                  if (bank != null)
                    WordBankRow(tally: bank, onPressed: actions.onPractice),
                  if (placement != null)
                    TestsCard(
                      result: placement,
                      now: DateTime.now(),
                      draw: state.firstView,
                      onRetest: actions.onRetest,
                    ),
                  DecoratedBox(
                    decoration: meCard(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(meCardRadius),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MeMenuRow(
                              icon: Icons.settings_outlined,
                              label: 'me_settings'.tr(),
                              tone: null,
                              onPressed: actions.onSettings,
                            ),
                            if (whatsapp != null) ...[
                              Divider(
                                height: 1,
                                color: context.scheme.outlineVariant,
                              ),
                              MeMenuRow(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'me_whatsapp'.tr(),
                                tone: colors.info,
                                onPressed: () => actions.onWhatsApp(whatsapp),
                                below: account == null
                                    ? null
                                    : AccountNumberLine(number: account),
                              ),
                            ],
                            Divider(
                              height: 1,
                              color: context.scheme.outlineVariant,
                            ),
                            MeMenuRow(
                              icon: Icons.verified_user_outlined,
                              label: 'me_privacy'.tr(),
                              tone: colors.primary,
                              onPressed: actions.onPrivacy,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => _signOut(context),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        minimumSize: const Size(0, AppSizes.minTapTarget),
                      ),
                      child: Text('me_sign_out'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A child's «أنا» (S §13.5): the guide on the shore, the name, the stars
/// and the words; the rest waits behind the parent's number.
class _KidMe extends StatefulWidget {
  const _KidMe({required this.state, required this.actions});

  final MeState state;
  final MeActions actions;

  @override
  State<_KidMe> createState() => _KidMeState();
}

class _KidMeState extends State<_KidMe> {
  var _asking = false;

  static const _band = 184.0;
  static const _guide = 120.0;
  static const _card = 200.0;

  Future<void> _gate() async {
    final cubit = context.read<MeCubit>();
    setState(() => _asking = true);
    final answer = await showParentGate(context, widget.state.gate);
    if (!mounted) return;
    setState(() => _asking = false);
    // A wrong number, or none, closes it quietly with another question next.
    cubit.tryGate(answer ?? '');
  }

  Future<void> _signOut() async {
    final leave = await showSignOutSheet(context, guest: widget.state.guest);
    if (leave == null || !mounted) return;
    if (leave) {
      await widget.actions.onSignOut();
    } else {
      widget.actions.onCreateAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final state = widget.state;
    final profile = state.profile!;
    final whatsapp = profile.whatsapp;
    final stars = profile.stars ?? 0;
    final words = profile.wordsSaved ?? 0;
    Widget tally(Widget mark, String text, String semantics, Color color) =>
        Expanded(
          child: Semantics(
            label: semantics,
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minHeight: _card),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.lg,
              ),
              decoration: meCard(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mark,
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: texts.title.copyWith(
                      color: color,
                      fontSize: 26,
                      height: 36 / 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 236,
                child: Stack(
                  children: [
                    SeaBand(
                      tone: SeaTone.kids,
                      height: _band,
                      coverUrl: profile.active?.unitCoverUrl,
                      drift: state.firstView,
                    ),
                    PositionedDirectional(
                      top: 112,
                      start: 0,
                      end: 0,
                      child: Center(
                        child: ExcludeSemantics(
                          child: Mascot(
                            expression: _asking
                                ? MascotExpression.cover
                                : MascotExpression.welcome,
                            waving: !_asking,
                            size: _guide,
                            sparkles: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                header: true,
                child: Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: texts.display.copyWith(fontSize: 28, height: 40 / 28),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.xl - AppSpacing.xs,
                  0,
                ),
                child: Row(
                  children: [
                    tally(
                      const KidStar(size: 64),
                      'me_kid_stars'.plural(stars),
                      'me_kid_stars'.plural(stars),
                      colors.reward.text,
                    ),
                    const SizedBox(width: 14),
                    tally(
                      Icon(
                        Icons.style_outlined,
                        size: 64,
                        color: colors.primary.fill,
                      ),
                      'kid_words_count'.plural(words),
                      'kid_words_count'.plural(words),
                      colors.textPrimary,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.xl - AppSpacing.xs,
                  0,
                  AppSpacing.xl - AppSpacing.xs,
                  AppSpacing.xl - AppSpacing.xs,
                ),
                child: state.parentOpen
                    ? _ParentPanel(
                        whatsapp: whatsapp,
                        actions: widget.actions,
                        onSignOut: _signOut,
                        onLock: context.read<MeCubit>().lockParent,
                      )
                    : Center(
                        child: OutlinedButton.icon(
                          onPressed: _gate,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppSizes.kidsMinTapTarget,
                            ),
                            foregroundColor: colors.textSecondary,
                          ),
                          icon: const Icon(Icons.lock_outline_rounded),
                          label: Text('me_parent'.tr()),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParentPanel extends StatelessWidget {
  const _ParentPanel({
    required this.whatsapp,
    required this.actions,
    required this.onSignOut,
    required this.onLock,
  });

  final String? whatsapp;
  final MeActions actions;
  final VoidCallback onSignOut;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final whatsapp = this.whatsapp;
    final divider = Divider(height: 1, color: context.scheme.outlineVariant);
    return DecoratedBox(
      decoration: meCard(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(meCardRadius),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.xs + 2,
                    0,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_open_rounded,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'me_parent'.tr(),
                          style: context.texts.captionStrong.copyWith(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onLock,
                        icon: const Icon(Icons.lock_outline_rounded, size: 18),
                        label: Text('me_lock'.tr()),
                      ),
                    ],
                  ),
                ),
              ),
              divider,
              MeMenuRow(
                icon: Icons.settings_outlined,
                label: 'me_settings'.tr(),
                tone: null,
                onPressed: actions.onSettings,
              ),
              if (whatsapp != null) ...[
                divider,
                MeMenuRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'me_whatsapp'.tr(),
                  tone: colors.info,
                  onPressed: () => actions.onWhatsApp(whatsapp),
                ),
              ],
              divider,
              MeMenuRow(
                icon: Icons.verified_user_outlined,
                label: 'me_privacy'.tr(),
                tone: colors.primary,
                onPressed: actions.onPrivacy,
              ),
              divider,
              MeMenuRow(
                icon: Icons.logout_rounded,
                label: 'me_sign_out'.tr(),
                tone: null,
                onPressed: onSignOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
