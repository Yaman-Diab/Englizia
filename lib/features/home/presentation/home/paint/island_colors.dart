import 'package:englizia/core/design_system/app_theme_context.dart';
import 'package:englizia/core/design_system/color_mix.dart';
import 'package:englizia/core/design_system/sea_palette.dart';
import 'package:flutter/widgets.dart';

/// An island fill at saturation [sat]: [full] mixed in oklab with
/// its layer's grey, which is [outline] at [greyPercent]% over [greyBase]
/// (the surface 55% over the reward surface). 1 is [full], 0 the grey; the
/// share is a whole percent, as the design writes it.
Color islandColor(
  Color full,
  Color greyBase,
  int greyPercent,
  double sat, {
  required Color outline,
}) {
  if (sat >= 1) return full;
  final grey = mixOklab(outline, greyBase, greyPercent / 100);
  if (sat <= 0) return grey;
  return mixOklab(full, grey, (sat * 100).round() / 100);
}

/// The grey an island fades to sits on this: the surface 55% over the
/// reward surface (oklab).
Color islandGreyBase({required Color surface, required Color rewardSurface}) =>
    mixOklab(surface, rewardSurface, .55);

/// An island's fills at saturation [sat]: a blend of its full palette and a
/// grey one, never a filter. Not named after colours: the architecture
/// test's raw-colour scan would read its static access as a palette's.
@immutable
final class IslandShades {
  const IslandShades({
    required this.sand,
    required this.sandEdge,
    required this.grass,
    required this.grassDeep,
    required this.shallow,
  });

  /// [tone]'s island at [sat]: sand 14%, its edge 26%, grass 40% and the
  /// tufts' deep grass 60% grey at 0; the shallows never fade.
  static IslandShades of(BuildContext context, SeaTone tone, double sat) {
    final sea = SeaPalette.of(context);
    final island = sea.islandOf(tone);
    final colors = context.colors;
    final outline = context.scheme.outline;
    final base = islandGreyBase(
      surface: colors.surface,
      rewardSurface: colors.reward.surface,
    );
    Color shade(Color full, int grey) =>
        islandColor(full, base, grey, sat, outline: outline);
    return IslandShades(
      sand: shade(island.sand, 14),
      sandEdge: shade(island.sandEdge, 26),
      grass: shade(island.grass, 40),
      grassDeep: shade(island.grassDeep, 60),
      shallow: sea.shallow,
    );
  }

  final Color sand;
  final Color sandEdge;
  final Color grass;
  final Color grassDeep;
  final Color shallow;

  @override
  bool operator ==(Object other) =>
      other is IslandShades &&
      other.sand == sand &&
      other.sandEdge == sandEdge &&
      other.grass == grass &&
      other.grassDeep == grassDeep &&
      other.shallow == shallow;

  @override
  int get hashCode => Object.hash(sand, sandEdge, grass, grassDeep, shallow);
}
