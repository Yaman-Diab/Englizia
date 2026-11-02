import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/press_scale.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/app_spinner.dart';
import 'package:englizia/features/lessons/presentation/exercise/cubit/mic_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The microphone and everything around it: the button, its time or caption,
/// "we didn't hear you", and the card that replaces it when the phone says no.
/// Shared, as shadowing and conversation use the same one (S §7.5).
class MicBlock extends StatelessWidget {
  const MicBlock({
    required this.state,
    required this.levels,
    required this.onTap,
    required this.onOpenSettings,
    required this.onSkip,
    this.locked = false,
    this.onType,
    this.caption,
    this.skipLabel,
    super.key,
  });

  final MicState state;
  final Stream<double> levels;
  final VoidCallback onTap;
  final VoidCallback onOpenSettings;

  /// «تخطَّ أسئلة الكلام», and «لا أستطيع التحدث الآن».
  final VoidCallback onSkip;

  /// The answer is in, so there is nothing to press.
  final bool locked;

  /// Writing the answer instead, where the question allows it.
  final VoidCallback? onType;

  /// Under the button while waiting, instead of «اضغط وتكلّم».
  final String? caption;

  /// The denied card's way out, instead of «تخطَّ أسئلة الكلام».
  final String? skipLabel;

  @override
  Widget build(BuildContext context) {
    if (state.phase == MicPhase.denied) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: AppSpacing.lg),
        child: _DeniedCard(
          onOpenSettings: onOpenSettings,
          onSkip: onSkip,
          skipLabel: skipLabel ?? 'lesson_mic_skip_speech'.tr(),
        ),
      );
    }
    final colors = context.colors;
    final listening = state.phase == MicPhase.listening;
    final canType =
        state.phase == MicPhase.idle || state.phase == MicPhase.notHeard;
    final mic = _MicButton(
      phase: state.phase,
      levels: levels,
      onTap: locked ? null : onTap,
    );
    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        if (onType case final onType?)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: _KeyboardButton.size + _keyboardGap),
              mic,
              const SizedBox(width: _keyboardGap),
              SizedBox.square(
                dimension: _KeyboardButton.size,
                child: canType ? _KeyboardButton(onTap: onType) : null,
              ),
            ],
          )
        else
          mic,
        const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
        if (listening)
          _RecordingTime(seconds: state.seconds)
        else
          Text(
            state.phase == MicPhase.thinking
                ? 'lesson_mic_thinking'.tr()
                : caption ?? 'lesson_mic_press'.tr(),
            style: context.texts.caption.copyWith(color: colors.textSecondary),
          ),
        if (state.phase == MicPhase.notHeard) ...[
          const SizedBox(height: AppSpacing.md),
          const _NotHeardNote(),
        ],
        const SizedBox(height: AppSpacing.xl),
        TextButton(
          onPressed: locked ? null : onSkip,
          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
          child: Text('lesson_mic_cant'.tr()),
        ),
      ],
    );
  }
}

const _keyboardGap = 28.0;

class _KeyboardButton extends StatelessWidget {
  const _KeyboardButton({required this.onTap});

  final VoidCallback onTap;

  static const size = AppSizes.minTapTarget;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: 'lesson_speak_type_instead'.tr(),
    color: context.colors.textSecondary,
    style: IconButton.styleFrom(
      padding: EdgeInsetsDirectional.zero,
      fixedSize: const Size.square(size),
      side: BorderSide(color: context.scheme.outline),
    ),
    icon: const Icon(Icons.keyboard_alt_outlined),
  );
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.phase,
    required this.levels,
    required this.onTap,
  });

  final MicPhase phase;
  final Stream<double> levels;
  final VoidCallback? onTap;

  static const _size = 88.0;
  static const _iconSize = 40.0;
  static const _halo = 8.0;
  static const _spinner = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final listening = phase == MicPhase.listening;
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (listening && !AppMotion.reduceMotion(context))
            _LevelRings(levels: levels, size: _size),
          PressScale(
            enabled: onTap != null,
            child: Semantics(
              button: true,
              selected: listening,
              label: listening
                  ? 'lesson_mic_stop'.tr()
                  : 'lesson_mic_press'.tr(),
              child: ExcludeSemantics(
                child: AnimatedContainer(
                  duration: AppMotion.resolve(context, AppMotion.fast),
                  curve: AppMotion.out,
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: colors.primaryStrong,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: listening
                            ? Colors.transparent
                            : colors.primary.surface,
                        spreadRadius: _halo,
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onTap,
                      child: Center(
                        child: phase == MicPhase.thinking
                            ? AppSpinner(
                                size: _spinner,
                                color: colors.onPrimaryStrong,
                              )
                            : Icon(
                                listening
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                size: _iconSize,
                                color: colors.onPrimaryStrong,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two rings that follow the real level of the voice: the inner one quick, the
/// outer one slower. They repaint alone, so a loud room doesn't rebuild a thing.
class _LevelRings extends StatefulWidget {
  const _LevelRings({required this.levels, required this.size});

  final Stream<double> levels;
  final double size;

  @override
  State<_LevelRings> createState() => _LevelRingsState();
}

class _LevelRingsState extends State<_LevelRings>
    with SingleTickerProviderStateMixin {
  static const _quick = .28;
  static const _slow = .1;

  final _inner = ValueNotifier<double>(0);
  final _outer = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final StreamSubscription<double> _subscription;
  double _target = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.levels.listen((level) => _target = level);
    _ticker = createTicker((_) {
      _inner.value += (_target - _inner.value) * _quick;
      _outer.value += (_target - _outer.value) * _slow;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_subscription.cancel());
    _inner.dispose();
    _outer.dispose();
    super.dispose();
  }

  Widget _ring(
    ValueNotifier<double> level,
    double growth,
    double from,
    double by,
  ) => ValueListenableBuilder<double>(
    valueListenable: level,
    builder: (context, value, _) => Transform.scale(
      scale: 1 + growth * value,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: context.colors.primary.fill.withValues(
            alpha: from + by * value,
          ),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [_ring(_outer, .62, .06, .14), _ring(_inner, .3, .14, .22)],
      ),
    ),
  );
}

class _RecordingTime extends StatelessWidget {
  const _RecordingTime({required this.seconds});

  final int seconds;

  static const _dot = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      label: 'lesson_mic_listening'.tr(),
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: colors.primaryStrong,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '0:${seconds.toString().padLeft(2, '0')}',
                style: context.texts.captionStrong.copyWith(
                  color: colors.primary.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotHeardNote extends StatelessWidget {
  const _NotHeardNote();

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: _iconSize,
              color: colors.info.fill,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'lesson_mic_not_heard'.tr(),
                style: context.texts.caption.copyWith(color: colors.info.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// In the microphone's place when the phone says no. Information, not an error.
class _DeniedCard extends StatelessWidget {
  const _DeniedCard({
    required this.onOpenSettings,
    required this.onSkip,
    required this.skipLabel,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onSkip;
  final String skipLabel;

  static const _circle = 56.0;
  static const _iconSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg + AppSpacing.xs,
          AppSpacing.lg + AppSpacing.xs,
          AppSpacing.lg + AppSpacing.xs,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.info.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Container(
              width: _circle,
              height: _circle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_off_rounded,
                size: _iconSize,
                color: colors.info.fill,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'lesson_mic_denied'.tr(),
              textAlign: TextAlign.center,
              style: context.texts.bodyStrong.copyWith(color: colors.info.text),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'lesson_mic_open_settings'.tr(),
              expand: false,
              onPressed: onOpenSettings,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(onPressed: onSkip, child: Text(skipLabel)),
          ],
        ),
      ),
    );
  }
}
