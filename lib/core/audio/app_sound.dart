/// Every short sound the app may play. Feedback sounds follow the phone's
/// sound mode (requirements v3.0 §7.2); kids mode will use its own set (§13).
/// Planned files: `assets/sounds/<name>.mp3`, named after the value.
enum AppSound {
  /// A correct answer.
  correct,

  /// A wrong answer (in kids mode, the gentle "try again").
  incorrect,

  /// A lesson finished.
  lessonComplete,

  /// The daily goal reached.
  goalReached,

  /// An achievement or a streak milestone.
  achievement,

  /// An in-app notification banner.
  notification,

  /// The guide's spoken welcome in kids mode: «مرحبًا! أنا بلبل. هيا نتعلّم
  /// الإنجليزية معًا. Hello!», recorded once, without the child's name.
  guideWelcome,

  /// The word "Hello!", spoken alone.
  hello,
}
