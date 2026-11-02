import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/talk/domain/entities/talk.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/talk.md).

String _required(String? value) =>
    value ?? (throw const FormatException('Talk: a field is missing'));

TalkKind _kind(String? value) =>
    value == 'written' ? TalkKind.written : TalkKind.ai;

TalkLine _line(Map<String, Object?> json) => TalkLine(
  english: _required(json.readString('en')),
  arabic: json.readString('ar') ?? '',
  audioUrl: json.readString('audioUrl'),
);

TalkCharacter _character(Map<String, Object?> json) => TalkCharacter(
  name: _required(json.readString('name')),
  description: json.readString('descriptionAr') ?? '',
  avatarUrl: json.readString('avatarUrl'),
);

List<TalkLine> _suggestions(List<Object?>? json) => [
  for (final line in json ?? const <Object?>[]) _line(asJsonMap(line)),
];

/// `GET /api/v1/app/talk`, and the copy kept on the phone, which is the same
/// JSON.
final class TalkHomeModel {
  const TalkHomeModel(this.json);

  final Map<String, Object?> json;

  /// A scenario that can't be read is left out, and the rest show.
  TalkHome toEntity() {
    final quota = json.readMap('quota');
    return TalkHome(
      units: [
        for (final unit in json.readList('units') ?? const <Object?>[])
          _unit(asJsonMap(unit)),
      ],
      quotaLeft: quota?.readInt('left') ?? 0,
      quotaTotal: quota?.readInt('total') ?? 0,
    );
  }

  static TalkUnit _unit(Map<String, Object?> json) => TalkUnit(
    title: json.readString('title') ?? '',
    scenarios: [
      for (final card in json.readList('scenarios') ?? const <Object?>[])
        ?_card(asJsonMap(card)),
    ],
  );

  static ScenarioCard? _card(Map<String, Object?> json) {
    try {
      return ScenarioCard(
        id: _required(json.readString('id')),
        title: _required(json.readString('title')),
        character: _character(json.readMap('character') ?? const {}),
        taskCount: json.readInt('tasks') ?? 0,
        kind: _kind(json.readString('kind')),
        bestDone: json.readInt('bestDone'),
        unlockUnit: json.readInt('unlockUnit'),
      );
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'A scenario is unreadable');
      return null;
    }
  }
}

/// `GET /api/v1/app/talk/scenarios/{id}`.
final class ScenarioModel {
  const ScenarioModel(this.json);

  final Map<String, Object?> json;

  /// The panel allows 4 to 20 turns, 10 by default (S §8.6).
  static const _defaultTurns = 10;

  Scenario toEntity() => Scenario(
    id: _required(json.readString('id')),
    title: _required(json.readString('title')),
    kind: _kind(json.readString('kind')),
    character: _character(json.readMap('character') ?? const {}),
    intro: _line(json.readMap('intro') ?? const {}),
    role: json.readString('roleAr') ?? '',
    tasks: [
      for (final task in json.readList('tasks') ?? const <Object?>[])
        TalkTask(
          id: _required(asJsonMap(task).readString('id')),
          text: _required(asJsonMap(task).readString('ar')),
        ),
    ],
    maxTurns: json.readInt('maxTurns') ?? _defaultTurns,
    opening: _line(json.readMap('opening') ?? const {}),
    suggestions: _suggestions(json.readList('suggestions')),
  );
}

/// The answer to `POST /api/v1/app/talk/conversations/{id}/turns`.
final class TalkReplyModel {
  const TalkReplyModel(this.json);

  final Map<String, Object?> json;

  TalkReply toEntity() => TalkReply(
    line: _line(json.readMap('reply') ?? const {}),
    tasksDone: {
      for (final id in json.readList('tasksDone') ?? const <Object?>[])
        if (id is String) id,
    },
    suggestions: _suggestions(json.readList('suggestions')),
    turnsLeft: json.readInt('turnsLeft') ?? 0,
  );
}

Map<String, Object?> talkStartToJson({
  required String conversationId,
  required String scenarioId,
}) => {'conversationId': conversationId, 'scenarioId': scenarioId};

Map<String, Object?> talkTurnToJson({
  required String turnId,
  required String text,
  required SaidVia via,
}) => {
  'turnId': turnId,
  'text': text,
  'via': switch (via) {
    SaidVia.mic => 'mic',
    SaidVia.keyboard => 'keyboard',
  },
};
