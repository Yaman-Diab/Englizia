import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// The top slot's strip: offline with the lessons kept (header §8.1), or a
/// refresh that failed (§8.2). The page hides "failed" after
/// `AppMotion.homeFailedHold` or a retry that works.
///
/// It takes the whole slot, the design's margins included: 4 above the 40
/// strip and 8 under it ([slotHeight], the header's `nt`). It spans the width
/// it is given; the slot spans the header's padding less the design's −4.
class ConnectionStrip extends StatelessWidget {
  const ConnectionStrip.offline({super.key}) : onRetry = null;

  const ConnectionStrip.failed({required VoidCallback this.onRetry, super.key});

  /// Null for the offline strip.
  final VoidCallback? onRetry;

  /// The slot at text scale 1: 4 + 40 + 8.
  static const slotHeight = 52.0;

  static const _strip = 40.0;
  static const _above = 4.0;
  static const _below = 8.0;

  /// The row is a 48 target tall, so the 40 strip sits 4 inside it.
  static const _inset = (AppSizes.minTapTarget - _strip) / 2;
  static const _icon = 18.0;
  static const _gap = 10.0;
  static const _padding = 14.0;

  /// «إعادة» comes close to the end: padding-inline-end 2.
  static const _retryEnd = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final retry = onRetry;
    final failed = retry != null;
    final tone = failed ? colors.error : colors.info;
    // ASSUMPTION(design): D39, the design's offline line; S §6.1 words it
    // differently (logged for the owner).
    final message = failed ? 'home_refresh_failed'.tr() : 'home_offline'.tr();
    final strip = Padding(
      padding: const EdgeInsetsDirectional.only(
        top: _above - _inset,
        bottom: _below - _inset,
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: _inset,
            bottom: _inset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tone.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: _padding,
              end: failed ? _retryEnd : _padding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTapTarget,
              ),
              child: Row(
                children: [
                  AppIconView(
                    failed ? AppIcon.alertTriangle : AppIcon.wifiOff,
                    size: _icon,
                    color: tone.fill,
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: Padding(
                      // A wrapped line keeps the strip's own inner margin.
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: _inset + AppSpacing.sm,
                      ),
                      child: Text(
                        message,
                        style: context.texts.caption.copyWith(color: tone.text),
                      ),
                    ),
                  ),
                  if (retry != null) ...[
                    const SizedBox(width: _gap),
                    _RetryButton(onPressed: retry),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: failed ? _Alert(message: message, child: strip) : strip,
    );
  }
}

/// «إعادة»: 40 drawn, a 48 target (header §16.13).
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _height = 40.0;
  static const _padding = 14.0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: context.colors.primary.text,
      minimumSize: const Size(AppSizes.minTapTarget, _height),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: _padding),
      shape: const StadiumBorder(),
      textStyle: context.texts.captionStrong,
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
    child: Text('home_refresh_retry'.tr()),
  );
}

/// Says [message] at once, over what the reader is reading (role=alert).
class _Alert extends StatefulWidget {
  const _Alert({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  State<_Alert> createState() => _AlertState();
}

class _AlertState extends State<_Alert> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          widget.message,
          Directionality.of(context),
          assertiveness: Assertiveness.assertive,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
