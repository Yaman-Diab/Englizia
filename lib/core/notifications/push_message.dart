import 'package:equatable/equatable.dart';

/// What a notification is about (S §20). Its data names it as `type`.
enum PushKind {
  /// A teacher answered one of the learner's questions.
  teacherReply,

  /// The daily goal's reminder, at the learner's time.
  dailyGoal,

  /// The streak will break today without a lesson.
  streak,
}

/// A notification from the server, as the app reads it. Its words are the
/// server's (the panel edits them, S §20): never a question's or a reply's
/// text.
final class PushMessage extends Equatable {
  const PushMessage({
    required this.kind,
    this.title,
    this.body,
    this.questionId,
    this.lessonId,
  });

  final PushKind kind;

  /// The notification's own title and text, when it has them; the app has
  /// its own per kind otherwise.
  final String? title;
  final String? body;

  /// A teacher's reply: the question, and the lesson it was asked in.
  final String? questionId;
  final String? lessonId;

  // ASSUMPTION(api): the data's `type` values and `questionId`/`lessonId`
  // (docs/api/notifications.md).
  static const _kinds = {
    'teacher_reply': PushKind.teacherReply,
    'daily_goal': PushKind.dailyGoal,
    'streak': PushKind.streak,
  };

  /// Reads a notification's data, or null for a kind this app doesn't know.
  static PushMessage? fromData(
    Map<String, Object?> data, {
    String? title,
    String? body,
  }) {
    final kind = _kinds[data['type']];
    if (kind == null) return null;
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value : null;
    return PushMessage(
      kind: kind,
      title: text(title),
      body: text(body),
      questionId: text(data['questionId']),
      lessonId: text(data['lessonId']),
    );
  }

  @override
  List<Object?> get props => [kind, title, body, questionId, lessonId];
}
