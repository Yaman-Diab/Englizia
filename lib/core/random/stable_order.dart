import 'dart:math';

/// [items] shuffled, the same way every time for the same [key] (S §7.1: each
/// learner's own order, which doesn't change on returning to a question).
/// `String.hashCode` isn't promised to stay the same between runs, so this
/// hashes the key itself (FNV-1a).
List<T> stableOrder<T>(List<T> items, String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return [...items]..shuffle(Random(hash));
}
