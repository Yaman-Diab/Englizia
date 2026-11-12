import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/widgets/streak_flame.dart';
import 'package:englizia/core/notifications/push_message.dart';
import 'package:flutter/material.dart';

/// The banner's words: the notification's own, else the app's for its kind.
(String, String) bannerText(PushMessage message) => (
  message.title ??
      switch (message.kind) {
        PushKind.teacherReply => 'notification_teacher_title'.tr(),
        PushKind.dailyGoal => 'notification_goal_title'.tr(),
        PushKind.streak => 'notification_streak_title'.tr(),
      },
  message.body ??
      switch (message.kind) {
        PushKind.teacherReply => 'notification_teacher_body'.tr(),
        PushKind.dailyGoal => 'notification_goal_body'.tr(),
        PushKind.streak => 'notification_streak_body'.tr(),
      },
);

/// A notification that arrived while the app is open (design "Notification
/// Banner"): it drops in, stays four seconds (longer while held, for good
/// under a screen reader), and rises away. A drag up closes it; a tap
/// anywhere but its buttons opens what it is about. A newer one replaces it
/// in place ([serial]).
class NotificationBanner extends StatefulWidget {
  const NotificationBanner({
    required this.message,
    required this.serial,
    required this.onOpen,
    required this.onDismissed,
    this.onLater,
    super.key,
  });

  final PushMessage message;
  final int serial;

  /// A tap, or the goal's «تابع الدرس»: what it is about opens.
  final VoidCallback onOpen;

  /// Gone from the screen, however it went.
  final VoidCallback onDismissed;

  /// The goal's «لاحقًا».
  final VoidCallback? onLater;

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this);

  /// Where it sits while dragged; negative is up.
  double _drag = 0;

  /// How far the last press travelled, which a tap must not have.
  double _travelled = 0;
  double? _pressY;
  bool _leaving = false;
  bool _swapping = false;
  Timer? _hold;

  /// How far above the screen it starts and ends.
  static const _offscreen = 40.0;

  /// A drag down follows the finger this much, as it can't go further.
  static const _downResistance = .2;

  bool get _reduced => AppMotion.reduceMotion(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motion.value == 0 && !_motion.isAnimating && !_leaving) _enter();
  }

  @override
  void didUpdateWidget(NotificationBanner old) {
    super.didUpdateWidget(old);
    if (old.serial != widget.serial) {
      _leaving = false;
      _drag = 0;
      _swapping = true;
      _motion
        ..duration = _reduced ? AppMotion.bannerFade : AppMotion.bannerSwap
        ..value = 0;
      unawaited(
        _motion.animateTo(1, curve: AppMotion.out).whenComplete(() {
          if (mounted) setState(() => _swapping = false);
        }),
      );
      _arm();
    }
  }

  void _enter() {
    _motion.duration = _reduced ? AppMotion.bannerFade : AppMotion.bannerIn;
    unawaited(_motion.animateTo(1, curve: AppMotion.homeEmphasis));
    _arm();
  }

  void _arm() {
    _hold?.cancel();
    // A screen reader user closes it with its button.
    if (MediaQuery.accessibleNavigationOf(context)) return;
    _hold = Timer(AppMotion.bannerHold, _exit);
  }

  Future<void> _exit() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _hold?.cancel();
    _motion.duration = _reduced ? AppMotion.bannerFade : AppMotion.bannerOut;
    await _motion.animateBack(0, curve: AppMotion.bannerOutCurve);
    if (mounted) widget.onDismissed();
  }

  void _open() {
    if (_leaving) return;
    widget.onOpen();
    unawaited(_exit());
  }

  void _down(PointerDownEvent event) {
    if (_leaving) return;
    _pressY = event.position.dy;
    _travelled = 0;
    _hold?.cancel();
  }

  void _move(PointerMoveEvent event) {
    final from = _pressY;
    if (from == null) return;
    final d = event.position.dy - from;
    _travelled = d.abs();
    if (_reduced) return;
    setState(() => _drag = d < 0 ? d : d * _downResistance);
  }

  void _up(PointerUpEvent event) {
    if (_pressY == null) return;
    _pressY = null;
    if (_drag < -AppMotion.bannerDismissDrag) {
      unawaited(_exit());
      return;
    }
    setState(() => _drag = 0);
    _arm();
  }

  void _cancel(PointerCancelEvent event) {
    _pressY = null;
    setState(() => _drag = 0);
    _arm();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (title, body) = bannerText(widget.message);
    final card = _BannerCard(
      message: widget.message,
      title: title,
      body: body,
      onClose: () => unawaited(_exit()),
      onGo: _open,
      onLater: () {
        widget.onLater?.call();
        unawaited(_exit());
      },
    );
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) {
          final t = _motion.value;
          if (_reduced) return Opacity(opacity: t, child: child);
          if (_swapping) {
            return Opacity(
              opacity:
                  AppMotion.bannerSwapOpacity +
                  (1 - AppMotion.bannerSwapOpacity) * t,
              child: Transform.scale(
                scale: AppMotion.scaleSmall + (1 - AppMotion.scaleSmall) * t,
                child: child,
              ),
            );
          }
          // From its own height plus a margin above the screen.
          return FractionalTranslation(
            translation: Offset(0, t - 1),
            child: Transform.translate(
              offset: Offset(0, _drag - (1 - t) * _offscreen),
              child: child,
            ),
          );
        },
        // Only the dragged card's position changes while it is held.
        child: Semantics(
          container: true,
          liveRegion: true,
          button: true,
          label: 'notification_banner_label'.tr(
            namedArgs: {'title': title, 'body': body},
          ),
          onTap: _open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // A press that wandered further than a tap's slop dragged.
              if (_travelled < AppMotion.bannerTapSlop) _open();
            },
            child: card,
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.message,
    required this.title,
    required this.body,
    required this.onClose,
    required this.onGo,
    required this.onLater,
  });

  final PushMessage message;
  final String title;
  final String body;
  final VoidCallback onClose;
  final VoidCallback onGo;
  final VoidCallback onLater;

  static const _radius = 20.0;
  static const _tile = 40.0;
  static const _tileRadius = 12.0;
  static const _icon = 22.0;
  static const _close = 32.0;
  static const _closeIcon = 18.0;
  static const _buttonHeight = 44.0;
  static const _shadowFar = .24;
  static const _shadowNear = .10;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final texts = context.texts;
    final shadow = context.scheme.shadow;
    final goal = message.kind == PushKind.dailyGoal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: context.scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: shadow.withValues(alpha: _shadowFar),
            offset: const Offset(0, 12),
            blurRadius: 32,
          ),
          BoxShadow(
            color: shadow.withValues(alpha: _shadowNear),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _tile,
                height: _tile,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: message.kind == PushKind.streak
                      ? colors.reward.surface
                      : colors.primary.surface,
                  borderRadius: BorderRadius.circular(_tileRadius),
                ),
                child: switch (message.kind) {
                  PushKind.teacherReply => AppIconView(
                    AppIcon.message,
                    size: _icon,
                    color: colors.primary.fill,
                  ),
                  PushKind.dailyGoal => AppIconView(
                    AppIcon.target,
                    size: _icon,
                    color: colors.primary.fill,
                  ),
                  PushKind.streak => const StreakFlame(
                    size: _icon,
                    inner: false,
                  ),
                },
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'app_wordmark'.tr(),
                              style: texts.captionStrong.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                                height: 18 / 12,
                              ),
                            ),
                            TextSpan(text: ' · ${'notification_now'.tr()}'),
                          ],
                        ),
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                          height: 18 / 12,
                        ),
                      ),
                      Text(
                        title,
                        style: texts.captionStrong.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                          height: 24 / 14,
                        ),
                      ),
                      Text(
                        body,
                        style: texts.caption.copyWith(
                          color: colors.textSecondary,
                          height: 22 / 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // No tooltip: the banner sits above the navigator's overlay.
              Semantics(
                button: true,
                label: 'notification_close'.tr(),
                excludeSemantics: true,
                onTap: onClose,
                child: SizedBox.square(
                  dimension: _close,
                  child: IconButton(
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    // Seen at 32, touched at 44.
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    icon: AppIconView(
                      AppIcon.cross,
                      size: _closeIcon,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (goal) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _tile + AppSpacing.md,
              ),
              // Side by side; one over the other where the words don't fit.
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton(
                    onPressed: onGo,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primaryStrong,
                      foregroundColor: colors.onPrimaryStrong,
                      minimumSize: const Size(0, _buttonHeight),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.lg + 2,
                      ),
                      textStyle: texts.captionStrong.copyWith(fontSize: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('notification_goal_go'.tr()),
                  ),
                  TextButton(
                    onPressed: onLater,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary.text,
                      minimumSize: const Size(0, _buttonHeight),
                      textStyle: texts.captionStrong.copyWith(fontSize: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('notification_goal_later'.tr()),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
