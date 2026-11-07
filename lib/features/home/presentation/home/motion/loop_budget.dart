import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Home's ambient loops, highest priority first.
enum HomeLoop {
  /// The flame's wobble while the streak is at risk: always counted.
  flame,

  /// The current stone breathing out to [AppMotion.homePulseScale].
  stonePulse,

  /// The guide's breath, in the ring or beside the stone.
  guideBreath,

  /// The review box floating.
  reviewBox,

  /// The waves drifting.
  waves,

  /// The fog on locked islands: each cloud costs a third.
  clouds,

  /// The flags of done islands: each one costs a third.
  flags,
}

/// At most [AppMotion.homeMaxLoops] ambient loops at once, by priority (M2):
/// the at-risk flame first, then what is on screen.
abstract final class LoopBudget {
  /// What a cloud or a flag costs.
  static const thirdCost = 0.34;

  /// The loops to run, of those [visible] (the flame: whether it wobbles at
  /// all). [counts] says how many clouds and flags are on screen (one when
  /// left out); a kind plays while the budget has room when it comes up.
  // ASSUMPTION(design): a kind plays whole or not at all, where the design
  // weighs each cloud and flag on its own; the cost is the same.
  static Set<HomeLoop> pick({
    required Map<HomeLoop, bool> visible,
    Map<HomeLoop, int> counts = const {},
  }) {
    var used = 0.0;
    final on = <HomeLoop>{};
    for (final loop in HomeLoop.values) {
      if (visible[loop] != true) continue;
      if (used >= AppMotion.homeMaxLoops) continue;
      on.add(loop);
      used += switch (loop) {
        HomeLoop.clouds || HomeLoop.flags => thirdCost * (counts[loop] ?? 1),
        _ => 1,
      };
    }
    return on;
  }
}

/// The ambient loops' clocks. Widgets draw them from these animations (each
/// one leg per [AppMotion] token, eased in and out); the waves and the fog
/// run their own and only read [isOn].
final class HomeLoops extends ChangeNotifier {
  HomeLoops({required TickerProvider vsync})
    : _flame = AnimationController(
        vsync: vsync,
        duration: AppMotion.homeFlame,
        value: .5,
      ),
      _pulse = AnimationController(vsync: vsync, duration: AppMotion.homePulse),
      _breath = AnimationController(
        vsync: vsync,
        duration: AppMotion.homeBreath,
      ),
      _box = AnimationController(
        vsync: vsync,
        duration: AppMotion.homeBoxFloat,
      ),
      _flag = AnimationController(vsync: vsync, duration: AppMotion.homeFlag);

  final AnimationController _flame;
  final AnimationController _pulse;
  final AnimationController _breath;
  final AnimationController _box;
  final AnimationController _flag;
  Set<HomeLoop> _on = const {};

  /// The flame's tilt, −1 to 1: times [AppMotion.homeFlameTilt] degrees about
  /// 50 % across and 80 % down the flame. 0 at rest.
  late final Animation<double> flame = _flame
      .drive(CurveTween(curve: AppMotion.inOut))
      .drive(Tween(begin: -1, end: 1));

  /// The current stone's pulse, 0 to 1: scale `1 + (homePulseScale − 1)·v`.
  late final Animation<double> pulse = _pulse.drive(
    CurveTween(curve: AppMotion.inOut),
  );

  /// The guide's breath, 0 → 1 → 0 each [AppMotion.homeBreath]: up
  /// [AppMotion.homeBreathLift] at 1.
  late final Animation<double> breath = _breath
      .drive(CurveTween(curve: AppMotion.inOut))
      .drive(
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
        ]),
      );

  /// The review box's float, 0 to 1: up [AppMotion.homeBoxFloatDistance] at 1.
  late final Animation<double> boxFloat = _box.drive(
    CurveTween(curve: AppMotion.inOut),
  );

  /// A flag's wave, 0 to 1: skewed [AppMotion.homeFlagSkew] degrees at 1,
  /// about its pole.
  late final Animation<double> flag = _flag.drive(
    CurveTween(curve: AppMotion.inOut),
  );

  /// The loops that run now.
  Set<HomeLoop> get on => _on;

  bool isOn(HomeLoop loop) => _on.contains(loop);

  /// Runs [loops] and pauses the others where they are.
  void run(Set<HomeLoop> loops) {
    if (setEquals(loops, _on)) return;
    _on = Set.unmodifiable(loops);
    _drive(_flame, HomeLoop.flame, reverse: true);
    _drive(_pulse, HomeLoop.stonePulse, reverse: true);
    _drive(_breath, HomeLoop.guideBreath, reverse: false);
    _drive(_box, HomeLoop.reviewBox, reverse: true);
    _drive(_flag, HomeLoop.flags, reverse: true);
    notifyListeners();
  }

  /// Nothing loops, and everything is back at rest (reduce motion).
  void rest() {
    run(const {});
    _flame.value = .5;
    for (final c in [_pulse, _breath, _box, _flag]) {
      c.value = 0;
    }
  }

  void _drive(
    AnimationController controller,
    HomeLoop loop, {
    required bool reverse,
  }) {
    if (!_on.contains(loop)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat(reverse: reverse);
    }
  }

  @override
  void dispose() {
    for (final c in [_flame, _pulse, _breath, _box, _flag]) {
      c.dispose();
    }
    super.dispose();
  }
}
