import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/practice/data/models/word_bank_model.dart';
import 'package:flutter/services.dart';

abstract interface class PracticeRemoteDataSource {
  Future<WordBankModel> getBank();

  /// One answer of a review; its id makes repeating it harmless.
  Future<void> sendReview(Map<String, Object?> request);

  Future<void> removeWord(String wordId);
}

final class PracticeRemoteDataSourceImpl implements PracticeRemoteDataSource {
  const PracticeRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<WordBankModel> getBank() async =>
      WordBankModel(asJsonMap(await _client.get(ApiEndpoints.wordBank)));

  @override
  Future<void> sendReview(Map<String, Object?> request) =>
      _client.post(ApiEndpoints.wordBankReviews, data: request);

  @override
  Future<void> removeWord(String wordId) =>
      _client.delete(ApiEndpoints.wordBankWord(wordId));
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled asset
/// the tests also use, its days moved to today. Deleted once the endpoints are
/// confirmed.
final class PracticeFakeDataSource implements PracticeRemoteDataSource {
  PracticeFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
    this.kids = false,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const asset = 'assets/mock/practice/word_bank.json';
  static const kidsAsset = 'assets/mock/practice/kid_word_bank.json';

  /// A child's bank (`env/mock_kids.json`): pictured words by unit.
  final bool kids;

  final AssetBundle _bundle;
  final Duration latency;
  final DateTime Function() _now;

  @override
  Future<WordBankModel> getBank() async {
    await Future<void>.delayed(latency);
    return WordBankModel(
      movedToToday(
        asJsonMap(
          ApiClient.unwrap(
            jsonDecode(await _bundle.loadString(kids ? kidsAsset : asset)),
          ),
        ),
        _now(),
      ),
    );
  }

  /// The asset's dates are written for its `mockToday`.
  static Map<String, Object?> movedToToday(
    Map<String, Object?> json,
    DateTime now,
  ) {
    final written = DateTime.parse(json.readString('mockToday')!);
    final shift = DateTime(now.year, now.month, now.day).difference(written);
    return {
      ...json,
      'words': [
        for (final word in json.readList('words') ?? const <Object?>[])
          {
            ...asJsonMap(word),
            'dueAt': DateTime.parse(
              asJsonMap(word).readString('dueAt')!,
            ).add(shift).toIso8601String(),
          },
      ],
    };
  }

  @override
  Future<void> sendReview(Map<String, Object?> request) =>
      Future<void>.delayed(latency);

  @override
  Future<void> removeWord(String wordId) => Future<void>.delayed(latency);
}
