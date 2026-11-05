import 'package:englizia/core/design_system/motion/app_motion.dart';
import 'package:englizia/core/design_system/motion/entrance_choreography.dart';
import 'package:englizia/features/home/presentation/home/motion/motion_timeline.dart';
import 'package:englizia/features/home/presentation/home/scene/home_scene.dart';

/// M1, the day's opening (design "Home Archipelago", motion §3): the map
/// fades in, each island rises in turn from the top (with its stones and
/// labels, D21), the trail into today's stone draws, the ring fills and its
/// guide hops in, then the bubble pops and the review box rises.
final class OpeningMotion implements MotionTimeline {
  const OpeningMotion({required this.islands, required this.segment});

  /// Islands on the map, top to bottom.
  final int islands;

  /// The trail's segment into the current stone (its index, the lessons
  /// done before it).
  final int segment;

  @override
  Duration get length => HomeEntrance.settled(islands);

  @override
  Duration get busyUntil => Duration.zero;

  @override
  List<TimedCue> get cues => const [];

  @override
  MotionFrame frameAt(Duration t) {
    final ms = msOf(t);
    return (
      map: MapOverrides(
        mapOpacity: phase(
          ms,
          HomeEntrance.map,
          AppMotion.homeMapFade,
          AppMotion.out,
        ),
        isleRise: [
          for (var j = 0; j < islands; j++)
            phase(ms, HomeEntrance.isle(j), AppMotion.homeIsleRise),
        ],
        segments: {
          segment: phase(
            ms,
            HomeEntrance.trail,
            AppMotion.homeTrailDraw,
            AppMotion.inOut,
          ),
        },
        bubbleIn: phase(ms, HomeEntrance.bubble, AppMotion.homeBubblePop),
        boxIn: phase(ms, HomeEntrance.box, AppMotion.homeBoxIn),
      ),
      header: HeaderOverrides(
        ringArcIn: phase(ms, HomeEntrance.ring, AppMotion.homeRingFill),
        ringGuideIn: phase(ms, HomeEntrance.guide, AppMotion.homeGuideIn),
      ),
      guide: null,
      expression: null,
    );
  }
}
