/// Every short sound the app may play, by meaning. Which file each one plays,
/// and how loud, is in `soundCatalog` (`sound_catalog.dart`); a sound with no
/// entry there stays silent. Feedback sounds follow the phone's sound mode
/// (requirements v3.0 §7.2), and kids mode plays its own file where one exists
/// (§13).
enum AppSound {
  /// A correct answer, a pair matched, a station passed in the mistakes bank.
  correct,

  /// A wrong answer (in kids mode, a gentle «try again»).
  incorrect,

  /// A piece picked to order or match, a lesson opened from the map.
  tap,

  /// A lesson finished.
  lessonComplete,

  /// A unit finished, the placement test's result, a concept mastered, the
  /// streak's challenge reached.
  achievement,

  /// Back on the map after a unit, the next island coming out of its fog.
  /// Heard right after [achievement], so it must not sound like it.
  islandUnlock,

  /// The daily goal reached, the streak one day longer.
  goalReached,

  /// The microphone starts listening; it ends before it records.
  micOn,

  /// The microphone stops.
  micOff,

  /// A word saved with its star.
  saveWord,

  /// A freeze kept the streak, on the card the next open shows.
  freeze,

  /// The app's notifications, on the phone's own notification.
  notification,

  /// One step of the points counting up on a lesson's end.
  xpTick,

  /// A card turned in the word bank's review.
  cardFlip,

  /// Kids: a star flying to the progress bar.
  kidsStar,

  /// Kids: the guide chirping as he celebrates.
  bulbul,

  /// The guide's spoken welcome in kids mode: «مرحبًا! أنا بلبل. هيا نتعلّم
  /// الإنجليزية معًا. Hello!», recorded once, without the child's name. A
  /// voice, not an effect: no file yet.
  guideWelcome,

  /// The word "Hello!", spoken alone. A voice: no file yet.
  hello,

  /// The sentence that tries the sound before the placement test: «Hello!
  /// Can you hear this sentence clearly?», bundled, as it must play offline.
  /// A voice: no file yet.
  placementTrial,
}
