import 'dart:convert';
import 'dart:math';

import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/random/stable_order.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';

// Shapes from docs/api/openapi.json (`/api/v1/app/placement`), checked against
// the dev server's answers in test/fixtures/api/placement_*.json.

T _require<T>(T? value, String what) =>
    value ?? (throw FormatException('Placement: no $what'));

/// The result's ladder, Pre-A1 to B2, as the server names its steps.
const placementLadder = ['pre_a1', 'a1', 'a2', 'b1', 'b2'];

/// "pre_a1" → "Pre-A1", "a2" → "A2".
String placementCode(String cefr) =>
    cefr == 'pre_a1' ? 'Pre-A1' : cefr.toUpperCase();

/// A track level as the result names it (`EnrollmentLevelDto`).
final class PlacementLevelModel {
  const PlacementLevelModel({
    required this.id,
    required this.name,
    required this.cefr,
    this.tagline,
    this.canDo = const [],
  });

  static PlacementLevelModel? fromJson(Map<String, Object?>? json) {
    final id = json?.readString('id');
    if (json == null || id == null) return null;
    return PlacementLevelModel(
      id: id,
      name: LocalizedText(
        ar: json.readString('nameAr') ?? '',
        en: json.readString('nameEn') ?? '',
      ),
      cefr: json.readString('cefrCode'),
      tagline: json.readString('taglineAr'),
      canDo: [
        for (final item
            in json.readList('canDoStatements') ?? const <Object?>[])
          if (item is Map)
            if (item.cast<String, Object?>().readString('ar') case final ar?)
              LocalizedText(
                ar: ar,
                en: item.cast<String, Object?>().readString('en') ?? '',
              ),
      ],
    );
  }

  final String id;
  final LocalizedText name;
  final String? cefr;

  /// `taglineAr`: the level in a word, written in the panel.
  final String? tagline;

  /// `canDoStatements`: up to five, in the panel's order.
  final List<LocalizedText> canDo;
}

/// `GET /api/v1/app/placement?trackId=`: where the account stands with the test
/// on that track.
final class PlacementStateModel {
  PlacementStateModel(this.json);

  final Map<String, Object?> json;

  String get state => json.readString('state') ?? 'unavailable';

  /// No test on this track, or no published one: nothing of the test is shown.
  bool get unavailable => state == 'unavailable';

  Map<String, Object?>? get _test => json.readMap('test');
  Map<String, Object?>? get _result => json.readMap('result');

  int _count(String group, String key) =>
      _test?.readMap(group)?.readInt(key) ?? 0;

  int get questionsWithoutTiebreak =>
      _count('questionCount', 'withoutTiebreak');
  int get questionsWithTiebreak => _count('questionCount', 'withTiebreak');

  String? get sessionId => json.readMap('session')?.readString('id');
  int? get sessionStage => json.readMap('session')?.readInt('stage');
  String? get resultSessionId => _result?.readString('sessionId');

  PlacementSummary get summary {
    int minutes(String key) =>
        max(1, (_count('estimatedSeconds', key) / 60).round());
    return PlacementSummary(
      minMinutes: minutes('withoutTiebreak'),
      maxMinutes: minutes('withTiebreak'),
      // Routing, then a block; the server adds the deciding one when needed.
      stages: 2,
      mayAddStage: questionsWithTiebreak > questionsWithoutTiebreak,
    );
  }

  /// [answered] is how far the phone got in the session's stage.
  PlacementStatus status({
    required DateTime now,
    required int Function(String sessionId, int stage) answered,
  }) {
    final result = _result;
    switch (state) {
      case 'in_progress':
        final id = _require(sessionId, 'session');
        final stage = sessionStage ?? 1;
        return PlacementInProgress(
          stage: stage,
          question: answered(id, stage) + 1,
        );
      case 'result':
        return PlacementAwaitingChoice(
          attemptId: _require(resultSessionId, 'result session'),
        );
      case 'done':
        final at = DateTime.tryParse(
          json.readString('retakeAvailableAt') ?? '',
        );
        if (at == null || !now.isBefore(at)) return _retakeOpen(result, now);
        return PlacementRetakeLocked(
          daysLeft: max(1, (at.difference(now).inHours / 24).ceil()),
        );
      case 'available' when json.readBool('isRetake') ?? false:
        return _retakeOpen(result, now);
      default:
        return const PlacementNotTaken();
    }
  }

  static PlacementStatus _retakeOpen(
    Map<String, Object?>? result,
    DateTime now,
  ) {
    final at = DateTime.tryParse(result?.readString('completedAt') ?? '');
    return PlacementRetakeOpen(
      level: placementCode(result?.readString('cefr') ?? 'pre_a1'),
      daysAgo: at == null ? 0 : max(0, now.difference(at).inDays),
    );
  }

  /// The result, on the ladder; the track's own levels where it may start.
  PlacementResult get result {
    final result = _require(_result, 'result');
    final cefr = result.readString('cefr') ?? 'pre_a1';
    final index = max(0, placementLadder.indexOf(cefr));
    final level = PlacementLevelModel.fromJson(result.readMap('level'));
    final lower = PlacementLevelModel.fromJson(result.readMap('lowerLevel'));
    PlacementLevel step(int i) {
      final code = placementLadder[i];
      final own = i == index ? level : (i == index - 1 ? lower : null);
      return PlacementLevel(
        id: own?.id ?? '',
        code: placementCode(code),
        cefr: code,
        name: own?.name ?? LocalizedText(ar: placementCode(code)),
        tagline: own?.tagline,
        canDo: own?.canDo ?? const [],
      );
    }

    return PlacementResult(
      levels: [for (var i = 0; i < placementLadder.length; i++) step(i)],
      levelIndex: index,
      canLower: lower != null && index > 0,
      skills: [
        for (final item in result.readList('skills') ?? const <Object?>[])
          ?_skill(item),
      ],
    );
  }

  static PlacementSkill? _skill(Object? item) {
    if (item is! Map) return null;
    final json = item.cast<String, Object?>();
    final kind = PlacementSkillKind.values
        .asNameMap()[json.readString('skill')];
    final percent = json.readInt('percent');
    if (kind == null || percent == null) return null;
    return PlacementSkill(kind: kind, score: percent.clamp(0, 100) / 100);
  }
}

/// A test session (`PlacementSessionDto`): the stage to answer and its
/// questions, or the result once it is over.
final class PlacementSessionModel {
  PlacementSessionModel(this.json);

  final Map<String, Object?> json;

  String get id => _require(json.readString('id'), 'session id');
  bool get completed => json.readString('status') == 'completed';
  int get stage => json.readInt('stage') ?? 1;
  int get listenCount => json.readInt('listenCount') ?? 0;
  List<Object?> get _questions => json.readList('questions') ?? const [];

  /// The stage that follows the one just sent, or null when the test is over.
  PlacementNextStage? get next {
    if (completed) return null;
    final questions = this.questions('');
    return PlacementNextStage(
      stage: stage,
      questionCount: questions.length,
      listeningCount: questions
          .where((q) => q.kind == PlacementQuestionKind.listening)
          .length,
      // The third stage only comes to settle a result between two levels.
      deciding: stage >= 3,
    );
  }

  /// [seed] gives each learner their own order of the options, the same each
  /// time: the server sends them unshuffled, and never the answer.
  List<PlacementQuestion> questions(String seed) {
    final media = json.readMap('media') ?? const <String, Object?>{};
    return [
      for (final question in _questions)
        _question(asJsonMap(question), media, seed),
    ];
  }

  static final _blank = RegExp('_{2,}');

  PlacementQuestion _question(
    Map<String, Object?> json,
    Map<String, Object?> media,
    String seed,
  ) {
    final id = _require(json.readString('id'), 'question id');
    final kind = PlacementQuestionKind.values
        .asNameMap()[json.readString('skill')];
    final template = json.readString('template');
    final options = json.readList('options') ?? const [];
    if (kind == null ||
        (template != 'multiple_choice' && template != 'listen_choose') ||
        options.isEmpty) {
      throw const FormatException("Placement: a question it can't show");
    }
    final prompt = json.readString('prompt') ?? '';
    final blank = _blank.firstMatch(prompt);
    final sentence =
        kind == PlacementQuestionKind.vocabulary ||
        kind == PlacementQuestionKind.grammar;
    final audioId = json.readString('audioMediaId');
    return PlacementQuestion(
      id: id,
      kind: kind,
      instruction: json.readString('instructionAr') ?? '',
      options: stableOrder([
        for (final option in options)
          PlacementOption(
            id: _require(asJsonMap(option).readString('id'), 'option id'),
            text: _require(asJsonMap(option).readString('text'), 'option'),
          ),
      ], '$seed:$id'),
      before: sentence
          ? (blank == null ? prompt : prompt.substring(0, blank.start))
          : '',
      after: sentence && blank != null ? prompt.substring(blank.end) : '',
      passage: json.readString('passage') ?? '',
      ask: sentence ? '' : prompt,
      audioUrl: audioId == null
          ? ''
          : media.readMap(audioId)?.readString('url') ?? '',
      maxPlays: audioId == null ? 0 : listenCount,
    );
  }
}

/// What the phone keeps of one session: the current stage's answers, which
/// the server hears of only when the stage ends, the listens, and the sizes
/// of the stages it has seen.
final class PlacementProgressModel {
  PlacementProgressModel(
    this.attemptId, {
    List<Map<String, Object?>>? kept,
    Map<String, int>? plays,
    Map<String, int>? sizes,
  }) : kept = kept ?? [],
       plays = plays ?? {},
       sizes = sizes ?? {};

  /// Null for anything unreadable: nothing was kept, then.
  static PlacementProgressModel? decode(String? saved) {
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved) as Map<String, Object?>;
      return PlacementProgressModel(
        json['attemptId']! as String,
        kept: [
          for (final answer in json['kept']! as List)
            (answer as Map).cast<String, Object?>(),
        ],
        plays: (json['plays']! as Map).cast<String, int>(),
        sizes: (json['sizes']! as Map).cast<String, int>(),
      );
    } on Object {
      return null;
    }
  }

  final String attemptId;

  /// `{stage, questionId, optionId}` or `{stage, questionId, dontKnow}`.
  final List<Map<String, Object?>> kept;
  final Map<String, int> plays;

  /// Questions per stage, by the stage's number.
  final Map<String, int> sizes;

  List<Map<String, Object?>> keptOf(int stage) => [
    for (final answer in kept)
      if (answer['stage'] == stage) answer,
  ];

  /// The stage's answers as `POST …/stages/{stage}` takes them.
  List<Map<String, Object?>> answersOf(int stage) => [
    for (final answer in keptOf(stage))
      if (answer['optionId'] case final String option)
        {'questionId': answer['questionId'], 'optionId': option}
      else
        {'questionId': answer['questionId'], 'dontKnow': true},
  ];

  String encode() => jsonEncode({
    'attemptId': attemptId,
    'kept': kept,
    'plays': plays,
    'sizes': sizes,
  });
}
