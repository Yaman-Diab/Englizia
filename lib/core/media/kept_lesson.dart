/// A downloaded lesson as the vault keeps it: the lesson as the server gave
/// it, with its version and the moment it stops opening offline. Written by
/// the downloads, read by the lessons.
abstract final class KeptLesson {
  static String nameOf(String lessonId) => 'lesson/$lessonId';

  static Map<String, Object?> wrap(
    Map<String, Object?> lesson, {
    required int version,
    required DateTime expiresAt,
  }) => {
    'version': version,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'lesson': lesson,
  };

  /// The lesson inside [document], or null once it has run out at [now]:
  /// the server has to be asked again first (ADR 22).
  static Map<String, Object?>? lessonOf(
    Map<String, Object?>? document,
    DateTime now,
  ) {
    final lesson = document?['lesson'];
    final expiresAt = DateTime.tryParse('${document?['expiresAt']}');
    if (lesson is! Map<String, Object?> || expiresAt == null) return null;
    return now.isBefore(expiresAt) ? lesson : null;
  }
}
