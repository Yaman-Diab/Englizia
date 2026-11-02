import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';

abstract interface class TalkRepository {
  /// «تحدّث» as last received, so the tab shows offline.
  TalkHome? get keptHome;

  Future<Result<TalkHome>> getHome();

  Future<Result<Scenario>> getScenario(String id);

  /// Starts a conversation, which counts against today's AI conversations.
  /// Returns its id.
  Future<Result<String>> start(String scenarioId);

  /// Sends the learner's [turn]-th line. Sending the same turn again after a
  /// failure is safe: it goes with the same id.
  Future<Result<TalkReply>> say(
    String conversationId, {
    required int turn,
    required String text,
    required SaidVia via,
  });

  /// The learner ended it, or it ended by itself, with the tasks done: a
  /// written conversation's are known only to the phone.
  Future<void> end(String conversationId, {required Set<String> tasksDone});

  /// An AI conversation's notes for the summary, which may still be coming.
  Future<Result<TalkNotes>> notes(String conversationId);
}
