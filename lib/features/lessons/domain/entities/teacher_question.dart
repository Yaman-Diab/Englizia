import 'package:equatable/equatable.dart';

enum ReplierRole { teacher, admin }

final class TeacherReply extends Equatable {
  const TeacherReply({
    required this.name,
    required this.role,
    required this.text,
  });

  final String name;
  final ReplierRole role;
  final String text;

  @override
  List<Object?> get props => [name, role, text];
}

enum QuestionStatus { sent, sending, failed }

/// A question the learner asked, and the answer they got. Private: the learner
/// sees only their own, and no other learner sees it (ADR 14).
final class TeacherQuestion extends Equatable {
  const TeacherQuestion({
    required this.id,
    required this.text,
    required this.askedAt,
    this.videoPosition,
    this.reply,
    this.status = QuestionStatus.sent,
  });

  /// Made on the phone, so sending it twice keeps one question.
  final String id;
  final String text;
  final DateTime askedAt;

  /// Where the video was when it was written: «عند 2:14» (S §17).
  final Duration? videoPosition;
  final TeacherReply? reply;
  final QuestionStatus status;

  TeacherQuestion withStatus(QuestionStatus status) => TeacherQuestion(
    id: id,
    text: text,
    askedAt: askedAt,
    videoPosition: videoPosition,
    reply: reply,
    status: status,
  );

  @override
  List<Object?> get props => [id, text, askedAt, videoPosition, reply, status];
}
