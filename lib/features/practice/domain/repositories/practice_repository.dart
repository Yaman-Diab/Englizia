import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';

/// The learner's word bank. It is kept on the phone, so «تدرّب» opens and a
/// review runs without a connection; answers and deletions wait there until
/// they reach the server, with ids that make sending them twice harmless.
abstract interface class PracticeRepository {
  /// The server's bank, or the phone's when there is no connection.
  Future<Result<WordBank>> getBank();

  /// The bank as last kept, with what was done since.
  WordBank? get keptBank;

  /// «عرفتها» or «لم أعرفها»: the word moves at once, and the answer goes when
  /// it can. Returns the word where it now stands.
  Future<BankWord> answer(BankWord word, {required bool known});

  /// «احذف من بنك الكلمات».
  Future<void> remove(BankWord word);

  /// Sends what is waiting. Never fails.
  Future<void> sendPending();
}
