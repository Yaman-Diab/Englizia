import 'package:flutter/semantics.dart';

/// The screen reader's order over home's stage (design "Home Archipelago",
/// header §14): the capsule, the strip under the top bar, the header group
/// with its status, the card, the flame (kids: the stars), the page search,
/// the guide and its words, the level header, the map, the back button.
/// Explicit, as the map lies under the headers and the default order would
/// read it first in Arabic. While a unit's celebration runs, its skip comes
/// before all.
abstract final class HomeReadOrder {
  static const skip = OrdinalSortKey(0);
  static const capsule = OrdinalSortKey(1);
  static const strip = OrdinalSortKey(2);
  static const header = OrdinalSortKey(3);
  static const card = OrdinalSortKey(4);
  static const flame = OrdinalSortKey(5);
  static const search = OrdinalSortKey(6);
  static const guide = OrdinalSortKey(7);
  static const say = OrdinalSortKey(8);
  static const level = OrdinalSortKey(9);
  static const map = OrdinalSortKey(10);
  static const back = OrdinalSortKey(11);
}
