import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeResponse {
  const FakeResponse(this.statusCode, {this.body, this.headers = const {}});

  final int statusCode;
  final Object? body;
  final Map<String, List<String>> headers;
}

/// Snapshot of a request as it left the interceptors (headers are copied,
/// because a retry mutates the same `RequestOptions`).
class RecordedRequest {
  RecordedRequest(RequestOptions options)
    : method = options.method,
      path = options.path,
      headers = Map.of(options.headers),
      data = options.data;

  final String method;
  final String path;
  final Map<String, Object?> headers;
  final Object? data;
}

/// Records requests and answers them with [handler] instead of the network.
/// Throw a `DioException` from [handler] to simulate a transport failure.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final FutureOr<FakeResponse> Function(RequestOptions options) handler;
  final requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedRequest(options));
    final response = await handler(options);
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...response.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
