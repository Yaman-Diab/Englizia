import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/network/api_client.dart';

/// Fetches a lesson's files (pictures, clips, a video's parts) from wherever
/// they are served. Not the API: it carries no session and no app headers,
/// as a signed link is all the file's host needs and the account's token is
/// not its to see. Errors are `ApiClient`'s: `ApiException` or
/// `NetworkException`.
abstract interface class MediaClient {
  /// [onReceived] is told each time more bytes arrive, with the total so far.
  Future<Uint8List> fetch(Uri uri, {void Function(int received)? onReceived});
}

final class DioMediaClient implements MediaClient {
  DioMediaClient([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: AppConfig.jsonTimeout,
              // A slow line still downloads: only silence ends a file.
              receiveTimeout: const Duration(seconds: 60),
              responseType: ResponseType.bytes,
            ),
          );

  final Dio _dio;

  @override
  Future<Uint8List> fetch(
    Uri uri, {
    void Function(int received)? onReceived,
  }) async {
    try {
      final response = await _dio.getUri<List<int>>(
        uri,
        onReceiveProgress: onReceived == null
            ? null
            : (received, _) => onReceived(received),
      );
      final bytes = response.data ?? const <int>[];
      return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ApiClient.convertDioException(error),
        stackTrace,
      );
    }
  }
}

/// Mock mode (`env/mock.json`): files that take a moment and arrive in
/// steps, so a download's progress can be seen with no network. An address
/// ending in `.m3u8` is a short plain stream.
final class FakeMediaClient implements MediaClient {
  const FakeMediaClient({this.step = const Duration(milliseconds: 120)});

  static const _steps = 4;
  static const _playlist = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
s0.ts
#EXTINF:6.0,
s1.ts
#EXTINF:6.0,
s2.ts
#EXTINF:6.0,
s3.ts
#EXT-X-ENDLIST
''';

  final Duration step;

  @override
  Future<Uint8List> fetch(
    Uri uri, {
    void Function(int received)? onReceived,
  }) async {
    if (uri.path.endsWith('.m3u8')) {
      return Uint8List.fromList(_playlist.codeUnits);
    }
    final size = switch (uri.path.split('.').last) {
      'ts' => 200000,
      'mp3' => 60000,
      _ => 40000,
    };
    for (var i = 1; i <= _steps; i++) {
      await Future<void>.delayed(step);
      onReceived?.call(size * i ~/ _steps);
    }
    return Uint8List(size);
  }
}
