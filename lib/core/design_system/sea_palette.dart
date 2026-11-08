import 'package:flutter/material.dart';

/// Which sea a band or island is drawn in: each track has its own.
enum SeaTone { general, emar, kids }

/// The island of a sea: its sand, its edge and its grass.
@immutable
final class IslandPalette {
  const IslandPalette({
    required this.sand,
    required this.sandEdge,
    required this.grass,
    required this.grassDeep,
  });

  final Color sand;
  final Color sandEdge;
  final Color grass;
  final Color grassDeep;
}

/// The sea and its islands, shared with home's world (designs "Me v2",
/// "Home Archipelago"). The gradient lives only in the sea's band.
@immutable
final class SeaPalette {
  const SeaPalette({
    required this.haze,
    required this.general,
    required this.deep,
    required this.emar,
    required this.kids,
    required this.wave,
    required this.fog,
    required this.shallow,
    required this.bridge,
    required this.bridgeTodo,
    required this.island,
    required this.emarIsland,
    required this.kidsIsland,
  });

  /// SEA_HAZE, at the sky's top.
  final Color haze;

  /// SEA_A2, the general track's sea, and SEA_B1, its deep end.
  final Color general;
  final Color deep;

  /// SEA_EMAAR and SEA_KIDS.
  final Color emar;
  final Color kids;
  final Color wave;
  final Color fog;
  final Color shallow;

  /// BRIDGE between islands reached, and BRIDGE_TODO towards the rest.
  final Color bridge;
  final Color bridgeTodo;
  final IslandPalette island;
  final IslandPalette emarIsland;
  final IslandPalette kidsIsland;

  static SeaPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  Color sea(SeaTone tone) => switch (tone) {
    SeaTone.general => general,
    SeaTone.emar => emar,
    SeaTone.kids => kids,
  };

  /// The bottom of the band: the general sea deepens, the others stay.
  Color depth(SeaTone tone) => switch (tone) {
    SeaTone.general => deep,
    SeaTone.emar => emar,
    SeaTone.kids => kids,
  };

  IslandPalette islandOf(SeaTone tone) => switch (tone) {
    SeaTone.general => island,
    SeaTone.emar => emarIsland,
    SeaTone.kids => kidsIsland,
  };

  static const light = SeaPalette(
    haze: Color(0xFFEFF4FD),
    general: Color(0xFFE6EEFD),
    deep: Color(0xFFD3E4FE),
    emar: Color(0xFFDDEEF5),
    kids: Color(0xFFCBE0FE),
    wave: Color(0xBFFFFFFF),
    fog: Color(0xFFFFFFFF),
    shallow: Color(0xFFF6F9FF),
    bridge: Color(0xFFFFFFFF),
    bridgeTodo: Color(0x807F8CA0),
    island: IslandPalette(
      sand: Color(0xFFFEF3C7),
      sandEdge: Color(0xFFF8DD9A),
      grass: Color(0xFFA5CEAF),
      grassDeep: Color(0xFF75B286),
    ),
    emarIsland: IslandPalette(
      sand: Color(0xFFFBF3D2),
      sandEdge: Color(0xFFF8DD9A),
      grass: Color(0xFF8DBEB5),
      grassDeep: Color(0xFF65AD9A),
    ),
    kidsIsland: IslandPalette(
      sand: Color(0xFFF9DE9D),
      sandEdge: Color(0xFFF6CC7A),
      grass: Color(0xFF82B991),
      grassDeep: Color(0xFF519F6A),
    ),
  );

  static const dark = SeaPalette(
    haze: Color(0xFF101B37),
    general: Color(0xFF172554),
    deep: Color(0xFF1B2F6E),
    emar: Color(0xFF12303F),
    kids: Color(0xFF1C3479),
    wave: Color(0x4D60A5FA),
    fog: Color(0xFF37435A),
    shallow: Color(0xFF1C3479),
    bridge: Color(0xFF4775BD),
    bridgeTodo: Color(0x995F6E8A),
    island: IslandPalette(
      sand: Color(0xFF7E5E16),
      sandEdge: Color(0xFF9F771A),
      grass: Color(0xFF2C6849),
      grassDeep: Color(0xFF1B452F),
    ),
    emarIsland: IslandPalette(
      sand: Color(0xFF66522A),
      sandEdge: Color(0xFF9F771A),
      grass: Color(0xFF236D67),
      grassDeep: Color(0xFF1A5048),
    ),
    kidsIsland: IslandPalette(
      sand: Color(0xFF6B5013),
      sandEdge: Color(0xFF957019),
      grass: Color(0xFF38825B),
      grassDeep: Color(0xFF23573C),
    ),
  );
}
