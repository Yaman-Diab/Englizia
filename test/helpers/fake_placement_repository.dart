import 'package:englizia/core/l10n/localized_text.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/placement/domain/entities/placement_result.dart';
import 'package:englizia/features/placement/domain/entities/placement_status.dart';
import 'package:englizia/features/placement/domain/entities/placement_summary.dart';
import 'package:englizia/features/placement/domain/entities/placement_test.dart';
import 'package:englizia/features/placement/domain/repositories/placement_repository.dart';

const testAttempt = PlacementAttempt(
  id: 'att',
  stageSizes: [2, 2],
  stage: 1,
  answered: 0,
);

const testOptions = [
  PlacementOption(id: 'o1', text: 'have'),
  PlacementOption(id: 'o2', text: 'make'),
];

const testVocabulary = PlacementQuestion(
  id: 'q1',
  kind: PlacementQuestionKind.vocabulary,
  before: 'I usually',
  after: 'breakfast at seven.',
  options: testOptions,
);

const testGrammar = PlacementQuestion(
  id: 'q2',
  kind: PlacementQuestionKind.grammar,
  before: 'If it',
  after: 'tomorrow.',
  options: testOptions,
);

const testReading = PlacementQuestion(
  id: 'q3',
  kind: PlacementQuestionKind.reading,
  passage: 'Omar works at a bank in the city centre.',
  ask: 'Where does Omar work?',
  options: testOptions,
);

const testListening = PlacementQuestion(
  id: 'q4',
  kind: PlacementQuestionKind.listening,
  audioUrl: 'https://api.test/clip.mp3',
  maxPlays: 2,
  ask: 'What time does the train leave?',
  options: testOptions,
);

const testLevels = [
  PlacementLevel(
    id: 'pre',
    code: 'Pre-A1',
    cefr: 'pre_a1',
    name: LocalizedText(ar: 'البداية', en: 'Beginning'),
  ),
  PlacementLevel(
    id: 'a1',
    code: 'A1',
    cefr: 'a1',
    name: LocalizedText(ar: 'مبتدئ', en: 'Beginner'),
  ),
  PlacementLevel(
    id: 'a2',
    code: 'A2',
    cefr: 'a2',
    name: LocalizedText(ar: 'أساسي', en: 'Elementary'),
  ),
];

const testSkills = [
  PlacementSkill(kind: PlacementSkillKind.vocabulary, score: 1),
  PlacementSkill(kind: PlacementSkillKind.grammar, score: .75),
  PlacementSkill(kind: PlacementSkillKind.reading, score: .5),
];

const testResult = PlacementResult(
  levels: testLevels,
  levelIndex: 2,
  skills: testSkills,
  canLower: true,
);

const testPlacementSummary = PlacementSummary(
  minMinutes: 12,
  maxMinutes: 15,
  stages: 2,
  mayAddStage: true,
);

/// Serves queued results in order, repeating the last one.
class FakePlacementRepository implements PlacementRepository {
  FakePlacementRepository([
    this.results = const [Ok(testPlacementSummary)],
    this.statuses = const [Ok(PlacementNotTaken())],
    this.actions = const [Ok(null)],
    this.attempts = const [Ok(testAttempt)],
    this.stages = const [
      Ok([testVocabulary, testGrammar]),
    ],
    this.completions = const [Ok(null)],
    this.placementResults = const [Ok(testResult)],
    this.accepts = const [Ok(null)],
  ]);

  final List<Result<PlacementSummary>> results;
  final List<Result<PlacementStatus>> statuses;

  /// What putting off answers, one after another.
  final List<Result<void>> actions;
  var calls = 0;
  var statusCalls = 0;
  var defers = 0;

  /// The tracks asked for, in order; null is the active one.
  final tracks = <String?>[];

  final List<Result<PlacementAttempt>> attempts;

  /// The questions of each request for a stage, one after another.
  final List<Result<List<PlacementQuestion>>> stages;
  final List<Result<PlacementNextStage?>> completions;
  var attemptCalls = 0;
  final stageCalls = <int>[];
  final completed = <int>[];
  final answers = <PlacementAnswer>[];
  final plays = <String, int>{};
  var unsent = 0;
  final List<Result<PlacementResult>> placementResults;
  final List<Result<void>> accepts;
  var resultCalls = 0;

  /// Each «ابدأ من …»: true when the learner chose the level below.
  final accepted = <bool>[];

  @override
  void useTrack(String? trackId) => tracks.add(trackId);

  @override
  Future<Result<PlacementSummary>> getSummary() async =>
      results[(calls++).clamp(0, results.length - 1)];

  @override
  Future<Result<PlacementStatus>> getStatus() async =>
      statuses[(statusCalls++).clamp(0, statuses.length - 1)];

  @override
  Future<Result<void>> deferTest() async {
    defers++;
    return _action();
  }

  @override
  Future<Result<PlacementAttempt>> startAttempt() async =>
      attempts[(attemptCalls++).clamp(0, attempts.length - 1)];

  @override
  Future<Result<List<PlacementQuestion>>> getStage(
    String attemptId,
    int stage,
  ) async {
    stageCalls.add(stage);
    return stages[(stageCalls.length - 1).clamp(0, stages.length - 1)];
  }

  @override
  Future<void> saveAnswer(PlacementAnswer answer) async => answers.add(answer);

  @override
  Future<Result<PlacementNextStage?>> completeStage(
    String attemptId,
    int stage,
  ) async {
    completed.add(stage);
    return completions[(completed.length - 1).clamp(0, completions.length - 1)];
  }

  @override
  int unsentAnswers(String attemptId, int stage) => unsent;

  @override
  int playsUsed(String attemptId, String questionId) => plays[questionId] ?? 0;

  @override
  Future<void> savePlays(
    String attemptId,
    String questionId,
    int plays,
  ) async => this.plays[questionId] = plays;

  @override
  Future<Result<PlacementResult>> getResult(String attemptId) async =>
      placementResults[(resultCalls++).clamp(0, placementResults.length - 1)];

  @override
  Future<Result<void>> acceptLevel(
    String attemptId, {
    required bool lower,
  }) async {
    accepted.add(lower);
    return accepts[(accepted.length - 1).clamp(0, accepts.length - 1)];
  }

  Result<void> _action() => actions[(defers - 1).clamp(0, actions.length - 1)];
}
