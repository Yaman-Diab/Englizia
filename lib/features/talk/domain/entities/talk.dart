import 'package:equatable/equatable.dart';

/// A conversation with the AI, or one written ahead of time (S §8.6).
enum TalkKind { ai, written }

/// How the learner said a turn: spoken or typed shows under their bubble; a
/// written conversation's reply chosen from cards shows nothing.
enum SaidVia { mic, keyboard, choice }

/// A line in English with its Arabic, and its voice when there is one.
final class TalkLine extends Equatable {
  const TalkLine({required this.english, this.arabic = '', this.audioUrl});

  final String english;
  final String arabic;
  final String? audioUrl;

  @override
  List<Object?> get props => [english, arabic, audioUrl];
}

/// The person the learner talks to.
final class TalkCharacter extends Equatable {
  const TalkCharacter({
    required this.name,
    this.description = '',
    this.avatarUrl,
  });

  final String name;

  /// Arabic, for the learner only: never sent to the AI (S §16.3).
  final String description;
  final String? avatarUrl;

  @override
  List<Object?> get props => [name, description, avatarUrl];
}

/// A scenario as «تحدّث» lists it.
final class ScenarioCard extends Equatable {
  const ScenarioCard({
    required this.id,
    required this.title,
    required this.character,
    required this.taskCount,
    required this.kind,
    this.bestDone,
    this.unlockUnit,
  });

  final String id;
  final String title;
  final TalkCharacter character;
  final int taskCount;
  final TalkKind kind;

  /// The most tasks done in one go; null when never tried («جديد»).
  final int? bestDone;

  /// The unit that opens it, while the learner hasn't reached it.
  final int? unlockUnit;

  bool get locked => unlockUnit != null;

  @override
  List<Object?> get props => [
    id,
    title,
    character,
    taskCount,
    kind,
    bestDone,
    unlockUnit,
  ];
}

final class TalkUnit extends Equatable {
  const TalkUnit({required this.title, required this.scenarios});

  final String title;
  final List<ScenarioCard> scenarios;

  @override
  List<Object?> get props => [title, scenarios];
}

/// «تحدّث»: the scenarios by unit, and the AI conversations left today.
final class TalkHome extends Equatable {
  const TalkHome({
    required this.units,
    required this.quotaLeft,
    required this.quotaTotal,
  });

  final List<TalkUnit> units;
  final int quotaLeft;
  final int quotaTotal;

  @override
  List<Object?> get props => [units, quotaLeft, quotaTotal];
}

final class TalkTask extends Equatable {
  const TalkTask({required this.id, required this.text});

  final String id;

  /// Arabic, for the learner only.
  final String text;

  @override
  List<Object?> get props => [id, text];
}

/// What a conversation starts from: the intro, the tasks, and the character's
/// fixed opening line, so every conversation starts the same way at once.
final class Scenario extends Equatable {
  const Scenario({
    required this.id,
    required this.title,
    required this.kind,
    required this.character,
    required this.intro,
    required this.role,
    required this.tasks,
    required this.maxTurns,
    required this.opening,
    required this.suggestions,
    this.script = const [],
  });

  final String id;
  final String title;
  final TalkKind kind;
  final TalkCharacter character;
  final TalkLine intro;

  /// «دورك»: who the learner is in it.
  final String role;
  final List<TalkTask> tasks;
  final int maxTurns;
  final TalkLine opening;

  /// «جرّب أن تقول» for the first turn.
  final List<TalkLine> suggestions;

  /// A written conversation's turns, in order; empty for an AI one.
  final List<ScriptTurn> script;

  @override
  List<Object?> get props => [
    id,
    title,
    kind,
    character,
    intro,
    role,
    tasks,
    maxTurns,
    opening,
    suggestions,
    script,
  ];
}

/// A turn of a written conversation, with the character's recorded answer.
sealed class ScriptTurn extends Equatable {
  const ScriptTurn();
}

/// «ردّد»: a sentence to say after hearing it. Any attempt counts (S §8.6).
final class RepeatTurn extends ScriptTurn {
  const RepeatTurn({required this.sentence, required this.reply, this.taskId});

  final TalkLine sentence;
  final TalkLine reply;

  /// The task it does, if any.
  final String? taskId;

  @override
  List<Object?> get props => [sentence, reply, taskId];
}

/// «اختر ردك»: two or three replies, and the character answers each its way.
final class ChooseTurn extends ScriptTurn {
  const ChooseTurn(this.options);

  final List<ScriptOption> options;

  @override
  List<Object?> get props => [options];
}

final class ScriptOption extends Equatable {
  const ScriptOption({required this.said, required this.reply, this.taskId});

  final TalkLine said;
  final TalkLine reply;

  /// The task this reply does; a reply that doesn't fit the scene does none.
  final String? taskId;

  @override
  List<Object?> get props => [said, reply, taskId];
}

/// A better way to say one of the learner's lines: [before], the corrected
/// [fix] and [after] make the whole sentence.
final class BetterSaying extends Equatable {
  const BetterSaying({
    required this.turn,
    required this.said,
    required this.before,
    required this.fix,
    required this.after,
    required this.concept,
    this.audioUrl,
  });

  /// Which of the learner's lines, from 0.
  final int turn;
  final String said;
  final String before;
  final String fix;
  final String after;

  /// The concept's Arabic name; it went to the concepts to strengthen.
  final String concept;
  final String? audioUrl;

  String get sentence => '$before$fix$after';

  @override
  List<Object?> get props => [
    turn,
    said,
    before,
    fix,
    after,
    concept,
    audioUrl,
  ];
}

/// Where an AI conversation's notes stand.
enum NotesStatus { ready, pending, failed }

final class TalkNotes extends Equatable {
  const TalkNotes({required this.status, this.notes = const []});

  final NotesStatus status;

  /// Up to three (S §8.6); none means it was all clear.
  final List<BetterSaying> notes;

  @override
  List<Object?> get props => [status, notes];
}

/// The character's answer to a turn, and where the conversation stands.
final class TalkReply extends Equatable {
  const TalkReply({
    required this.line,
    required this.tasksDone,
    required this.suggestions,
    required this.turnsLeft,
  });

  final TalkLine line;

  /// Every task done so far, by id.
  final Set<String> tasksDone;
  final List<TalkLine> suggestions;
  final int turnsLeft;

  @override
  List<Object?> get props => [line, tasksDone, suggestions, turnsLeft];
}
