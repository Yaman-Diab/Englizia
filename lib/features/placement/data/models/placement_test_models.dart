import 'dart:convert';

import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';

// ASSUMPTION(api): this whole file is proposed (docs/api/placement.md).

T _require<T>(T? value, String what) =>
    value ?? (throw FormatException('Placement: no $what'));

final class PlacementAttemptModel {
  const PlacementAttemptModel(this.entity);

  factory PlacementAttemptModel.fromJson(Map<String, Object?> json) {
    final sizes = json['stageSizes'];
    if (sizes is! List || sizes.isEmpty) {
      throw const FormatException('Placement: no stage sizes');
    }
    return PlacementAttemptModel(
      PlacementAttempt(
        id: _require(json.readString('attemptId'), 'attempt id'),
        stageSizes: [for (final size in sizes) size as int],
        stage: json.readInt('stage') ?? 1,
        answered: json.readInt('answered') ?? 0,
      ),
    );
  }

  final PlacementAttempt entity;
}

final class PlacementStageModel {
  const PlacementStageModel(this.questions);

  factory PlacementStageModel.fromJson(Map<String, Object?> json) {
    final questions = json['questions'];
    if (questions is! List || questions.isEmpty) {
      throw const FormatException('Placement: a stage with no questions');
    }
    return PlacementStageModel([
      for (final question in questions) _question(asJsonMap(question)),
    ]);
  }

  static PlacementQuestion _question(Map<String, Object?> json) {
    final kind = PlacementQuestionKind.values
        .asNameMap()[json.readString('type')];
    final options = json['options'];
    if (kind == null || options is! List || options.isEmpty) {
      throw const FormatException('Placement: a question it can\'t show');
    }
    return PlacementQuestion(
      id: _require(json.readString('id'), 'question id'),
      kind: kind,
      options: [
        for (final option in options)
          PlacementOption(
            id: _require(asJsonMap(option).readString('id'), 'option id'),
            text: _require(asJsonMap(option).readString('text'), 'option'),
          ),
      ],
      before: json.readString('before') ?? '',
      after: json.readString('after') ?? '',
      passage: json.readString('passage') ?? '',
      ask: json.readString('ask') ?? '',
      audioUrl: json.readString('audioUrl') ?? '',
      maxPlays: json.readInt('maxPlays') ?? 0,
    );
  }

  final List<PlacementQuestion> questions;
}

final class PlacementNextModel {
  const PlacementNextModel(this.entity);

  factory PlacementNextModel.fromJson(Map<String, Object?> json) {
    final next = json.readMap('next');
    if (next == null) return const PlacementNextModel(null);
    return PlacementNextModel(
      PlacementNextStage(
        stage: _require(next.readInt('stage'), 'next stage'),
        questionCount: _require(
          next.readInt('questionCount'),
          'question count',
        ),
        listeningCount: next.readInt('listeningCount') ?? 0,
        deciding: next.readBool('deciding') ?? false,
      ),
    );
  }

  final PlacementNextStage? entity;
}

/// What is kept on the phone for one attempt.
final class PlacementProgressModel {
  PlacementProgressModel(
    this.attemptId, {
    List<Map<String, Object?>>? unsent,
    Map<String, int>? plays,
  }) : unsent = unsent ?? [],
       plays = plays ?? {};

  /// Null for anything unreadable: nothing was kept, then.
  static PlacementProgressModel? decode(String? saved) {
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved) as Map<String, Object?>;
      return PlacementProgressModel(
        json['attemptId']! as String,
        unsent: [
          for (final answer in json['unsent']! as List)
            (answer as Map).cast<String, Object?>(),
        ],
        plays: (json['plays']! as Map).cast<String, int>(),
      );
    } on Object {
      return null;
    }
  }

  final String attemptId;

  /// In the shape of the answer's request, with the `stage` it belongs to.
  final List<Map<String, Object?>> unsent;
  final Map<String, int> plays;

  String encode() =>
      jsonEncode({'attemptId': attemptId, 'unsent': unsent, 'plays': plays});
}
