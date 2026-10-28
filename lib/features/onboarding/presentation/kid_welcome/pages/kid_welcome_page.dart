import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/pulse.dart';
import 'package:englizia/core/design_system/motion/swap.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/features/onboarding/presentation/kid_welcome/cubit/kid_welcome_cubit.dart';
import 'package:englizia/features/onboarding/presentation/kid_welcome/widgets/hello_word.dart';
import 'package:englizia/features/onboarding/presentation/kid_welcome/widgets/sparkle.dart';
import 'package:englizia/features/onboarding/presentation/widgets/onboarding_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The kids' welcome (requirements v3.0 §4.5, design "Kid Welcome"): first
/// the parent hands the phone over and turns the sound up, then the guide
/// greets the child by name (in text; the voice is recorded once without
/// it) and says "Hello!", and "let's play" opens the first lesson. A silent
/// phone shows «ارفع الصوت» with a note on the side button; the design's
/// arrow to the button is left out, since the button's place differs from
/// phone to phone. Back from the child's part returns to the parent's.
class KidWelcomePage extends StatefulWidget {
  const KidWelcomePage({
    required this.childName,
    required this.onPlay,
    super.key,
  });

  /// May be empty: the texts then greet without a name.
  final String childName;

  /// Opens the first lesson.
  final VoidCallback onPlay;

  @override
  State<KidWelcomePage> createState() => _KidWelcomePageState();
}

class _KidWelcomePageState extends State<KidWelcomePage> {
  /// A tap on the guide makes it wave; on the guide or the word, the word
  /// lights up. Both for [AppMotion.highlightHold].
  bool _tapWave = false;
  bool _tapHello = false;
  Timer? _tapTimer;

  /// Bumped twice when "let's play" appears: two gentle beats.
  int _beat = 0;

  static const _guideCircle = 260.0;
  static const _guideSize = 220.0;
  static const _compactGuideCircle = 200.0;
  static const _compactGuideSize = 168.0;
  static const _handOverCircle = 152.0;
  static const _handOverGuide = 120.0;
  static const _compactHeight = 700.0;
  static const _replaySize = 56.0;
  static const _replayIconSize = 28.0;
  static const _wordArea = 120.0;
  static const _mutedMark = 72.0;
  static const _mutedIconSize = 36.0;
  static const _ctaGrowth = .045;

  String get _name => widget.childName;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _tap({required bool wave}) {
    context.read<KidWelcomeCubit>().sayHello();
    _tapTimer?.cancel();
    setState(() {
      _tapWave = wave;
      _tapHello = true;
    });
    _tapTimer = Timer(AppMotion.highlightHold, () {
      if (mounted) setState(() => _tapWave = _tapHello = false);
    });
  }

  Future<void> _beatTwice() async {
    for (var i = 0; i < 2; i++) {
      await Future<void>.delayed(AppMotion.slow);
      if (!mounted) return;
      setState(() => _beat++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KidWelcomeCubit, KidWelcomeState>(
      listenWhen: (before, now) =>
          now.phase == KidWelcomePhase.done &&
          before.phase != KidWelcomePhase.done,
      listener: (_, _) => _beatTwice(),
      builder: (context, state) {
        final cubit = context.read<KidWelcomeCubit>();
        final handOver = state.phase == KidWelcomePhase.handOver;
        return PopScope(
          canPop: handOver,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) cubit.handOver();
          },
          child: Scaffold(
            body: SafeArea(
              child: handOver
                  ? _handOverPart(context, cubit)
                  : _childPart(context, state, cubit),
            ),
          ),
        );
      },
    );
  }

  Widget _handOverPart(BuildContext context, KidWelcomeCubit cubit) {
    final colors = context.colors;
    final texts = context.texts;
    final compact = MediaQuery.sizeOf(context).height < _compactHeight;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl,
              compact ? AppSpacing.xxl : AppSpacing.xxxl + AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              children: [
                const _Circle(
                  size: _handOverCircle,
                  child: Mascot(
                    expression: MascotExpression.handoff,
                    size: _handOverGuide,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    _name.isEmpty
                        ? 'kid_welcome_ready'.tr()
                        : 'kid_welcome_ready_named'.tr(
                            namedArgs: {'name': _name},
                          ),
                    textAlign: TextAlign.center,
                    style: texts.title.copyWith(color: colors.textPrimary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _name.isEmpty
                      ? 'kid_welcome_give'.tr()
                      : 'kid_welcome_give_named'.tr(namedArgs: {'name': _name}),
                  textAlign: TextAlign.center,
                  style: texts.body.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                OnboardingNotice(
                  icon: AppIcon.volume,
                  text: 'kid_welcome_sound_up'.tr(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: AppButton(
            label: 'kid_welcome_start'.tr(),
            size: AppButtonSize.large,
            onPressed: cubit.play,
          ),
        ),
      ],
    );
  }

  Widget _childPart(
    BuildContext context,
    KidWelcomeState state,
    KidWelcomeCubit cubit,
  ) {
    final colors = context.colors;
    final texts = context.texts;
    final compact = MediaQuery.sizeOf(context).height < _compactHeight;
    final muted = state.phase == KidWelcomePhase.muted;
    final done = state.phase == KidWelcomePhase.done;
    final waving = state.speaking || _tapWave;
    final expression = muted && !_tapWave
        ? MascotExpression.listen
        : waving
        ? MascotExpression.welcome
        : MascotExpression.happy;
    final greeting = muted
        ? 'kid_welcome_turn_up'.tr()
        : _name.isEmpty
        ? 'kid_welcome_hello'.tr()
        : 'kid_welcome_hello_named'.tr(namedArgs: {'name': _name});

    return Column(
      children: [
        SizedBox(
          height: _replaySize + AppSpacing.lg,
          child: Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
              child: SizedBox.square(
                dimension: _replaySize,
                child: IconButton.filled(
                  onPressed: muted ? null : cubit.replay,
                  tooltip: 'kid_welcome_replay'.tr(),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.info.fill,
                    disabledBackgroundColor: colors.info.surface,
                  ),
                  icon: AppIconView(
                    AppIcon.volume,
                    size: _replayIconSize,
                    color: colors.onPrimaryStrong,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: 'kid_welcome_guide'.tr(),
                  child: GestureDetector(
                    onTap: () => _tap(wave: true),
                    child: _Circle(
                      size: compact ? _compactGuideCircle : _guideCircle,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Mascot(
                            expression: expression,
                            waving: waving,
                            size: compact ? _compactGuideSize : _guideSize,
                          ),
                          // The happy guide brings its own sparkles.
                          if (expression == MascotExpression.welcome) ...const [
                            PositionedDirectional(
                              end: 30,
                              top: 66,
                              child: Sparkle(size: 22),
                            ),
                            PositionedDirectional(
                              start: 34,
                              top: 30,
                              child: Sparkle(size: 16),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  liveRegion: true,
                  child: Swap(
                    child: Text(
                      greeting,
                      key: ValueKey(greeting),
                      textAlign: TextAlign.center,
                      style: texts.kidsGreeting.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  height: _wordArea,
                  child: muted
                      ? Column(
                          children: [
                            Container(
                              width: _mutedMark,
                              height: _mutedMark,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.info.fill,
                                shape: BoxShape.circle,
                              ),
                              child: AppIconView(
                                AppIcon.volumeOff,
                                size: _mutedIconSize,
                                color: colors.onPrimaryStrong,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'kid_welcome_side_button'.tr(),
                              textAlign: TextAlign.center,
                              style: texts.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.topCenter,
                          child: HelloWord(
                            highlighted:
                                state.phase == KidWelcomePhase.hello ||
                                _tapHello,
                            onTap: () => _tap(wave: false),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          // Its place is kept from the start, so nothing moves when it
          // appears.
          child: AnimatedOpacity(
            opacity: done ? 1 : 0,
            duration: AppMotion.resolve(context, AppMotion.medium),
            curve: AppMotion.out,
            child: IgnorePointer(
              ignoring: !done,
              child: ExcludeSemantics(
                excluding: !done,
                child: Pulse(
                  trigger: _beat,
                  growth: _ctaGrowth,
                  child: AppButton(
                    label: 'kid_welcome_play'.tr(),
                    icon: Icons.play_arrow_rounded,
                    size: AppButtonSize.kids,
                    onPressed: done ? widget.onPlay : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The guide's soft round backdrop.
class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.colors.primary.surface,
      shape: BoxShape.circle,
    ),
    child: child,
  );
}
