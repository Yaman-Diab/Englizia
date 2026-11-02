import 'dart:convert';
import 'dart:io';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:englizia/features/practice/data/models/word_bank_model.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/repositories/practice_repository.dart';
import 'package:englizia/features/practice/domain/services/review_schedule.dart';

/// The mock bank, its days moved to [today].
WordBank mockBank(DateTime today) => WordBankModel(
  PracticeFakeDataSource.movedToToday(
    asJsonMap(
      ApiClient.unwrap(
        jsonDecode(File(PracticeFakeDataSource.asset).readAsStringSync()),
      ),
    ),
    today,
  ),
).toEntity();

class FakePracticeRepository implements PracticeRepository {
  FakePracticeRepository({this.bank, this.failure, DateTime? now})
    : now = now ?? DateTime(2026, 11, 2, 10);

  WordBank? bank;

  /// What the server answers instead of the bank.
  Failure? failure;
  final DateTime now;
  final answers = <(String, bool)>[];
  final removed = <String>[];
  var sends = 0;

  @override
  WordBank? get keptBank => bank;

  @override
  Future<Result<WordBank>> getBank() async {
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Ok(bank!);
  }

  @override
  Future<BankWord> answer(BankWord word, {required bool known}) async {
    answers.add((word.id, known));
    final moved = answered(word, known: known, now: now);
    bank = bank!.copyWith(
      words: [for (final w in bank!.words) w.id == word.id ? moved : w],
    );
    return moved;
  }

  @override
  Future<void> remove(BankWord word) async {
    removed.add(word.id);
    bank = bank!.copyWith(
      words: [...bank!.words.where((w) => w.id != word.id)],
    );
  }

  @override
  Future<void> sendPending() async => sends++;
}
