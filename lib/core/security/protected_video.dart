import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/di/service_locator.dart';
import 'package:englizia/core/security/screen_protection.dart';
import 'package:flutter/material.dart';

/// A lesson's video, kept from being captured (ADR 18): while it shows, the
/// screen can't be shot or recorded on Android; on iOS, where a screenshot
/// can't be stopped, it gives way to a cover while the screen is recorded or
/// mirrored, and [onCaptured] pauses it, as a recording takes the sound too.
/// It comes back by itself once the recording stops; the learner plays on.
class ProtectedVideo extends StatefulWidget {
  const ProtectedVideo({
    required this.child,
    this.onCaptured,
    this.protection,
    super.key,
  });

  /// The video with whatever controls it, all hidden together.
  final Widget child;
  final VoidCallback? onCaptured;

  /// The app's, unless a test gives its own.
  final ScreenProtection? protection;

  @override
  State<ProtectedVideo> createState() => _ProtectedVideoState();
}

class _ProtectedVideoState extends State<ProtectedVideo> {
  late final ScreenProtection _protection =
      widget.protection ??
      (sl.isRegistered<ScreenProtection>()
          ? sl<ScreenProtection>()
          : const NoScreenProtection());
  VoidCallback? _release;
  var _captured = false;
  StreamSubscription<bool>? _changes;

  @override
  void initState() {
    super.initState();
    _release = _protection.protect();
    _captured = _protection.captured;
    if (_captured) _pauseAfterBuild();
    _changes = _protection.capturedChanges.listen((captured) {
      if (!mounted || captured == _captured) return;
      setState(() => _captured = captured);
      if (captured) widget.onCaptured?.call();
    });
  }

  void _pauseAfterBuild() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) widget.onCaptured?.call();
  });

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _release?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _captured ? const _CaptureCover() : widget.child;
}

/// In the video's place while the screen is recorded: what happened, and
/// that it comes back, in words and an icon, never by colour alone.
class _CaptureCover extends StatelessWidget {
  const _CaptureCover();

  @override
  Widget build(BuildContext context) {
    final reader = context.colors.reader;
    final texts = context.texts;
    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        color: reader.videoBackground,
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.videocam_off_rounded,
                    size: AppSizes.iconLg,
                    color: reader.onVideo,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'video_capture_title'.tr(),
                  textAlign: TextAlign.center,
                  style: texts.bodyStrong.copyWith(color: reader.onVideo),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'video_capture_body'.tr(),
                  textAlign: TextAlign.center,
                  style: texts.caption.copyWith(color: reader.onVideo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
