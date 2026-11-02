/// The five stations' waits in days: a concept is mastered by a right answer at
/// each, about 55 days in all (S §11.1).
const stationDays = [1, 3, 7, 14, 30];

const stationCount = 5;

enum OutcomeKind {
  /// A station passed: the next one waits.
  step,

  /// The fifth passed.
  mastered,

  /// Wrong: from the first two the cycle starts again tomorrow; later on it
  /// goes back two stations, and what came before is kept.
  again,
}

/// What an answer at a station did.
final class ConceptOutcome {
  const ConceptOutcome({
    required this.kind,
    required this.from,
    required this.to,
  });

  final OutcomeKind kind;

  /// Stations passed before the answer, and after.
  final int from;
  final int to;

  /// Days until the concept comes back; none once mastered.
  int? get wait => to >= stationCount ? null : stationDays[to];

  /// Wrong at the first or second station.
  bool get startsOver => kind == OutcomeKind.again && from < 2;
}

ConceptOutcome outcomeOf(int passed, {required bool correct}) {
  if (correct) {
    final to = (passed + 1).clamp(0, stationCount);
    return ConceptOutcome(
      kind: to >= stationCount ? OutcomeKind.mastered : OutcomeKind.step,
      from: passed,
      to: to,
    );
  }
  return ConceptOutcome(
    kind: OutcomeKind.again,
    from: passed,
    to: passed < 2 ? 0 : passed - 2,
  );
}
