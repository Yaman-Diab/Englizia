import 'package:englizia/core/result/result.dart';
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
  ]);

  final List<Result<PlacementSummary>> results;
  final List<Result<PlacementStatus>> statuses;

  /// What restarting and putting off answer, one after another.
  final List<Result<void>> actions;
  var calls = 0;
  var statusCalls = 0;
  var restarts = 0;
  var defers = 0;

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

  @override
  Future<Result<PlacementSummary>> getSummary() async =>
      results[(calls++).clamp(0, results.length - 1)];

  @override
  Future<Result<PlacementStatus>> getStatus() async =>
      statuses[(statusCalls++).clamp(0, statuses.length - 1)];

  @override
  Future<Result<void>> restartTest() async {
    restarts++;
    return _action();
  }

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

  Result<void> _action() =>
      actions[(restarts + defers - 1).clamp(0, actions.length - 1)];
}
