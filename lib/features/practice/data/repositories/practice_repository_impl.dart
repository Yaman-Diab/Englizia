import 'dart:async';
import 'dart:convert';

import 'package:englizia/core/error/failure.dart';
import 'package:englizia/core/logging/app_logger.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/result/guard.dart';
import 'package:englizia/core/result/result.dart';
import 'package:englizia/core/storage/send_queue.dart';
import 'package:englizia/core/storage/settings_storage_service.dart';
import 'package:englizia/features/practice/data/datasources/practice_remote_data_source.dart';
import 'package:englizia/features/practice/data/models/word_bank_model.dart';
import 'package:englizia/features/practice/domain/entities/word_bank.dart';
import 'package:englizia/features/practice/domain/repositories/practice_repository.dart';
import 'package:englizia/features/practice/domain/services/review_schedule.dart';

final class PracticeRepositoryImpl implements PracticeRepository {
  PracticeRepositoryImpl(
    this._remote,
    this._settings, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _queue = SendQueue(
      read: () => _settings.wordBankOutbox,
      write: _settings.setWordBankOutbox,
      send: _send,
    );
  }

  static const _reviewKind = 'review';
  static const _removeKind = 'remove';

  final PracticeRemoteDataSource _remote;
  final SettingsStorageService _settings;
  final DateTime Function() _now;
  late final SendQueue _queue;

  @override
  WordBank? get keptBank {
    final kept = _settings.wordBank;
    if (kept == null) return null;
    try {
      return WordBankModel(asJsonMap(jsonDecode(kept))).toEntity();
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'The kept word bank is unreadable');
      return null;
    }
  }

  Future<void> _keep(WordBank bank) async {
    try {
      await _settings.setWordBank(jsonEncode(WordBankModel.fromEntity(bank)));
    } catch (error, stackTrace) {
      AppLogger.error(error, stackTrace, 'Keeping the word bank failed');
    }
  }

  /// What is still waiting is laid over the server's bank, which hasn't seen it.
  @override
  Future<Result<WordBank>> getBank() async {
    await sendPending();
    final result = await guard(
      () async => (await _remote.getBank()).toEntity(),
    );
    switch (result) {
      case Ok(:final value):
        final bank = _withPending(value);
        await _keep(bank);
        return Ok(bank);
      case Err(:final failure):
        if (failure is NetworkFailure && keptBank != null) {
          return Ok(keptBank!);
        }
        return result;
    }
  }

  WordBank _withPending(WordBank bank) {
    final waiting = _queue.entries;
    if (waiting.isEmpty) return bank;
    final kept = {
      for (final word in keptBank?.words ?? const <BankWord>[]) word.id: word,
    };
    final removed = {
      for (final entry in waiting)
        if (entry.readString('kind') == _removeKind) entry.readString('wordId'),
    };
    final answered = {
      for (final entry in waiting)
        if (entry.readString('kind') == _reviewKind) entry.readString('wordId'),
    };
    return bank.copyWith(
      words: [
        for (final word in bank.words)
          if (!removed.contains(word.id))
            answered.contains(word.id) ? kept[word.id] ?? word : word,
      ],
    );
  }

  @override
  Future<BankWord> answer(BankWord word, {required bool known}) async {
    final now = _now();
    final moved = answered(word, known: known, now: now);
    final bank = keptBank;
    if (bank != null) {
      await _keep(
        bank.copyWith(
          words: [for (final w in bank.words) w.id == word.id ? moved : w],
        ),
      );
    }
    await _enqueue({
      'kind': _reviewKind,
      'wordId': word.id,
      'request': reviewToJson(
        reviewId: SettingsStorageService.randomId(),
        wordId: word.id,
        known: known,
        at: now,
      ),
    });
    return moved;
  }

  @override
  Future<void> remove(BankWord word) async {
    final bank = keptBank;
    if (bank != null) {
      await _keep(
        bank.copyWith(words: [...bank.words.where((w) => w.id != word.id)]),
      );
    }
    await _enqueue({'kind': _removeKind, 'wordId': word.id});
  }

  Future<void> _enqueue(Map<String, Object?> entry) => _queue.add(entry);

  @override
  Future<void> sendPending() => _queue.flush();

  Future<void> _send(Map<String, Object?> entry) =>
      switch (entry.readString('kind')) {
        _reviewKind => _remote.sendReview(asJsonMap(entry['request'])),
        _ => _remote.removeWord(entry.readString('wordId')!),
      };
}
