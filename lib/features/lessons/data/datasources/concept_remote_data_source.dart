import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/lessons/data/models/concept_model.dart';
import 'package:flutter/services.dart';

abstract interface class ConceptRemoteDataSource {
  Future<ConceptBankModel> getBank();

  Future<void> sendAnswer(Map<String, Object?> request);

  Future<void> sendReport(Map<String, Object?> request);
}

final class ConceptRemoteDataSourceImpl implements ConceptRemoteDataSource {
  const ConceptRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<ConceptBankModel> getBank() async =>
      ConceptBankModel(asJsonMap(await _client.get(ApiEndpoints.concepts)));

  @override
  Future<void> sendAnswer(Map<String, Object?> request) =>
      _client.post(ApiEndpoints.conceptAnswers, data: request);

  @override
  Future<void> sendReport(Map<String, Object?> request) =>
      _client.post(ApiEndpoints.conceptReports, data: request);
}

/// Mock mode (`env/mock.json`): the contract's example from the bundled asset
/// the tests also use. Deleted once the endpoints are confirmed.
final class ConceptFakeDataSource implements ConceptRemoteDataSource {
  const ConceptFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 400),
  });

  static const asset = 'assets/mock/practice/concepts.json';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<ConceptBankModel> getBank() async {
    await Future<void>.delayed(latency);
    return ConceptBankModel(
      asJsonMap(ApiClient.unwrap(jsonDecode(await _bundle.loadString(asset)))),
    );
  }

  @override
  Future<void> sendAnswer(Map<String, Object?> request) =>
      Future<void>.delayed(latency);

  @override
  Future<void> sendReport(Map<String, Object?> request) =>
      Future<void>.delayed(latency);
}
