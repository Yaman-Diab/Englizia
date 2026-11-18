import 'dart:convert';

import 'package:englizia/core/network/api_client.dart';
import 'package:englizia/core/network/api_endpoints.dart';
import 'package:englizia/core/network/json_reader.dart';
import 'package:englizia/features/downloads/data/models/download_manifest_model.dart';
import 'package:flutter/services.dart';

abstract interface class DownloadRemoteDataSource {
  /// The lesson and its files; a lesson the server doesn't offer is its 403
  /// or 404.
  Future<DownloadManifestModel> getManifest(String lessonId);
}

final class DownloadRemoteDataSourceImpl implements DownloadRemoteDataSource {
  const DownloadRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<DownloadManifestModel> getManifest(String lessonId) async =>
      DownloadManifestModel.fromJson(
        asJsonMap(await _client.get(ApiEndpoints.lessonDownload(lessonId))),
      );
}

/// Mock mode (`env/mock.json`): the contract's example, for any lesson.
/// Deleted once the endpoint exists (docs/STATUS.md).
final class DownloadFakeDataSource implements DownloadRemoteDataSource {
  const DownloadFakeDataSource(
    this._bundle, {
    this.latency = const Duration(milliseconds: 300),
  });

  static const asset = 'assets/mock/downloads/manifest.json';

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<DownloadManifestModel> getManifest(String lessonId) async {
    await Future<void>.delayed(latency);
    final body = jsonDecode(await _bundle.loadString(asset));
    return DownloadManifestModel.fromJson({
      ...asJsonMap(ApiClient.unwrap(body)),
      'lessonId': lessonId,
    });
  }
}
