import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:englizia/core/design_system/app_spacing.dart';
import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/icons/app_icon.dart';
import 'package:englizia/core/design_system/mascot/mascot.dart';
import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/core/design_system/widgets/app_button.dart';
import 'package:englizia/core/design_system/widgets/notice_card.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_cubit.dart';
import 'package:englizia/features/launch/presentation/splash/cubit/splash_state.dart';
import 'package:englizia/features/launch/presentation/splash/widgets/loading_dots.dart';
import 'package:englizia/features/launch/presentation/splash/widgets/store_link_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The splash (student doc §4.1, design Splash Form): it takes over from the
/// system's splash with the same circle at the same place, plays its intro
/// while the app loads, and stays only for a first open without a
/// connection or a version too old to run (App Update). Leaving it is the
/// router's job, once [SplashCubit] lets the app on.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: SplashIntro.settled,
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final cubit = context.read<SplashCubit>();
    if (AppMotion.reduceMotion(context)) {
      _intro.value = 1;
    } else {
      cubit.introStarted();
      unawaited(
        _intro.forward().whenComplete(() {
          if (mounted) cubit.introShown();
        }),
      );
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return BlocBuilder<SplashCubit, SplashState>(
      builder: (context, state) => Scaffold(
        body: Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppSpacing.xl,
            end: AppSpacing.xl,
            bottom: insets.bottom + AppSpacing.xl,
          ),
          child: CustomMultiChildLayout(
            delegate: _SplashLayout(top: insets.top, bottom: insets.bottom),
            children: [
              LayoutId(
                id: _Part.hero,
                child: _Hero(state: state, intro: _intro),
              ),
              LayoutId(
                id: _Part.actions,
                child: _Actions(state: state),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Part { hero, actions }

/// The circle at the middle of the screen, where the system's splash drew
/// it; lifted only as far as the actions below need.
class _SplashLayout extends MultiChildLayoutDelegate {
  _SplashLayout({required this.top, required this.bottom});

  /// The status bar's and the gesture bar's heights.
  final double top;
  final double bottom;

  @override
  void performLayout(Size size) {
    final full = BoxConstraints(
      minWidth: size.width,
      maxWidth: size.width,
      maxHeight: size.height,
    );
    final actions = layoutChild(_Part.actions, full);
    final actionsTop = size.height - actions.height;
    positionChild(_Part.actions, Offset(0, actionsTop));

    final hero = layoutChild(_Part.hero, full);
    // The middle of the whole screen, as the system draws its splash.
    final middle = (size.height + bottom + AppSpacing.xl) / 2;
    final centered = middle - _Hero.stage / 2;
    final fits = actionsTop - AppSpacing.xl - hero.height;
    positionChild(
      _Part.hero,
      Offset(0, math.max(top, math.min(centered, fits))),
    );
  }

  @override
  bool shouldRelayout(_SplashLayout oldDelegate) =>
      top != oldDelegate.top || bottom != oldDelegate.bottom;
}

/// The stage, the guide and what is under them: the name, or the update's
/// title and text.
class _Hero extends StatelessWidget {
  const _Hero({required this.state, required this.intro});

  final SplashState state;
  final Animation<double> intro;

  /// Design sizes: the circle, the guide in it, the ripple's growth.
  static const stage = 200.0;
  static const _guide = 140.0;
  static const _from = .8;
  static const _rippleGrowth = .22;
  static const _rippleOpacity = .5;
  static const _rippleWidth = 2.0;

  /// Where the guide stands in the circle (design: 28 from its top).
  static const _guideRise = 2.0;

  static const _textMaxWidth = 290.0;

  /// [intro]'s share of the whole between [start] and [length].
  Animation<double> _part(Duration start, Duration length, Curve curve) {
    final total = SplashIntro.settled.inMicroseconds;
    return CurvedAnimation(
      parent: intro,
      curve: Interval(
        start.inMicroseconds / total,
        math.min(1, (start + length).inMicroseconds / total),
        curve: curve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final update = state.mode == SplashMode.update;
    final stageIn = _part(Duration.zero, SplashIntro.stage, AppMotion.out);
    final guideIn = _part(Duration.zero, SplashIntro.guide, AppMotion.out);
    final ripple = _part(
      SplashIntro.rippleDelay,
      SplashIntro.ripple,
      AppMotion.out,
    );
    final name = _part(
      SplashIntro.nameDelay,
      SplashIntro.name,
      AppMotion.smoothOut,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: stage,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: ripple,
                builder: (context, child) => Opacity(
                  opacity: ripple.value == 0
                      ? 0
                      : _rippleOpacity * (1 - ripple.value),
                  child: Transform.scale(
                    scale: 1 + _rippleGrowth * ripple.value,
                    child: child,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primary.fill,
                      width: _rippleWidth,
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              ScaleTransition(
                scale: Tween(begin: _from, end: 1.0).animate(stageIn),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.surface,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              AnimatedBuilder(
                animation: guideIn,
                builder: (context, child) =>
                    _GuideHop(t: guideIn.value, child: child!),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: _guideRise * 2,
                  ),
                  child: Mascot(
                    expression: switch (state.mode) {
                      SplashMode.offline => MascotExpression.understand,
                      SplashMode.update => MascotExpression.happy,
                      _ => MascotExpression.welcome,
                    },
                    size: _guide,
                    sparkles: false,
                    shadow: false,
                    waving: state.mode == SplashMode.loading,
                    waveOnce: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (update)
          Entrance(
            key: const ValueKey(SplashMode.update),
            motion: EntranceMotion.up,
            delay: Duration.zero,
            duration: SplashIntro.content,
            child: Semantics(
              liveRegion: true,
              container: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _textMaxWidth),
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'update_required_title'.tr(),
                        textAlign: TextAlign.center,
                        style: context.texts.title,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'update_required_body'.tr(),
                      textAlign: TextAlign.center,
                      style: context.texts.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          AnimatedBuilder(
            animation: name,
            builder: (context, child) => Opacity(
              opacity: name.value,
              child: Transform.translate(
                offset: Offset(0, AppMotion.distanceSmall * (1 - name.value)),
                child: child,
              ),
            ),
            child: Text(
              'app_wordmark'.tr(),
              textDirection: TextDirection.ltr,
              style: context.texts.display.copyWith(color: colors.primary.text),
            ),
          ),
      ],
    );
  }
}

/// The guide's hop into place (design keyframes): it grows from the
/// system splash's size, crouches, springs up and lands.
class _GuideHop extends StatelessWidget {
  const _GuideHop({required this.t, required this.child});

  final double t;
  final Widget child;

  /// (time, rise, width, height) of each key pose.
  static const _keys = [
    (0.0, 0.0, .8, .8),
    (.22, -6.0, .84, .76),
    (.58, 18.0, 1.02, 1.04),
    (.84, -2.0, 1.03, .96),
    (1.0, 0.0, 1.0, 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    var i = 0;
    while (i < _keys.length - 2 && t > _keys[i + 1].$1) {
      i++;
    }
    final (t0, rise0, w0, h0) = _keys[i];
    final (t1, rise1, w1, h1) = _keys[i + 1];
    final k = ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
    double at(double a, double b) => a + (b - a) * k;
    return Transform.translate(
      offset: Offset(0, -at(rise0, rise1)),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(at(w0, w1), at(h0, h1), 1),
        child: child,
      ),
    );
  }
}

/// Under the hero: «جاري التحميل…» when slow, the first open's notice and
/// «إعادة المحاولة», or «تحديث الآن» with the store's link when it didn't open.
class _Actions extends StatelessWidget {
  const _Actions({required this.state});

  final SplashState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SplashCubit>();
    return switch (state.mode) {
      SplashMode.loading ||
      SplashMode.done => state.slow ? const _Slow() : const SizedBox.shrink(),
      SplashMode.offline => _arriving(
        SplashMode.offline,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NoticeCard(icon: AppIcon.wifiOff, title: 'splash_offline'.tr()),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'common_retry'.tr(),
              size: AppButtonSize.large,
              isLoading: state.retrying,
              onPressed: cubit.retry,
            ),
          ],
        ),
      ),
      SplashMode.update => _arriving(
        SplashMode.update,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.storeFailed) ...[
              StoreLinkField(link: state.storePage),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: 'update_required_action'.tr(),
              size: AppButtonSize.large,
              onPressed: cubit.openStore,
            ),
          ],
        ),
      ),
    };
  }

  Widget _arriving(SplashMode mode, Widget child) => Entrance(
    key: ValueKey(mode),
    motion: EntranceMotion.up,
    delay: SplashIntro.actionsDelay,
    duration: SplashIntro.content,
    child: child,
  );
}

/// «جاري التحميل…» with three hopping dots.
class _Slow extends StatelessWidget {
  const _Slow();

  static const _height = 56.0;

  @override
  Widget build(BuildContext context) => Entrance(
    motion: EntranceMotion.up,
    delay: Duration.zero,
    duration: SplashIntro.content,
    distance: 0,
    child: Semantics(
      liveRegion: true,
      child: SizedBox(
        height: _height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingDots(),
            const SizedBox(width: AppSpacing.md),
            Text(
              'splash_loading'.tr(),
              style: context.texts.caption.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
