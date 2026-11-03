import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/core/network/network_exception.dart';
import 'package:englizia/features/lessons/data/models/explanation_model.dart';
import 'package:flutter/services.dart';

abstract interface class ExplainRemoteDataSource {
  Future<ExplainModel> explain(Map<String, Object?> request);

  Future<void> rate(String explanationId, Map<String, Object?> request);
}

final class ExplainRemoteDataSourceImpl implements ExplainRemoteDataSource {
  const ExplainRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<ExplainModel> explain(Map<String, Object?> request) async =>
      ExplainModel(
        asJsonMap(await _client.post(ApiEndpoints.explanations, data: request)),
      );

  @override
  Future<void> rate(String explanationId, Map<String, Object?> request) =>
      _client.post(
        ApiEndpoints.explanationRating(explanationId),
        data: request,
      );
}

/// Mock mode (`env/mock.json`): the bundled explanations by question, with the
/// day's count going down. The second one asked for fails once, so «تعذّر
/// الشرح الآن» can be seen. Deleted once the endpoints are confirmed.
final class ExplainFakeDataSource implements ExplainRemoteDataSource {
  ExplainFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 1700),
  });

  static const asset = 'assets/mock/lessons/explanations.json';
  static const _failing = 2;

  final AssetBundle _bundle;

  /// The design's wait while the AI writes.
  final Duration latency;
  var _asked = 0;
  var _failed = false;
  var _left = 5;

  @override
  Future<ExplainModel> explain(Map<String, Object?> request) async {
    await Future<void>.delayed(latency);
    if (++_asked == _failing && !_failed) {
      _failed = true;
      throw const NetworkException('connectionError');
    }
    if (_left <= 0) return const ExplainModel({'status': 'quotaOut'});
    final all = asJsonMap(jsonDecode(await _bundle.loadString(asset)));
    final explanation = all[request.readString('questionId')] ?? all['default'];
    return ExplainModel({
      'status': 'ready',
      'explanation': explanation,
      'left': --_left,
    });
  }

  @override
  Future<void> rate(String explanationId, Map<String, Object?> request) =>
      Future<void>.delayed(const Duration(milliseconds: 200));
}
