import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/lessons/domain/entities/explanation.dart';

abstract interface class ExplainRepository {
  /// The explanation of a wrong answer. One asked for before comes from the
  /// phone; with none left today, the server isn't asked. A failure isn't
  /// counted.
  Future<Result<ExplainOutcome>> explain(ExplainRequest request);

  /// Whether it helped, to improve what the AI is told.
  Future<void> rate(String explanationId, {required bool helpful});
}
