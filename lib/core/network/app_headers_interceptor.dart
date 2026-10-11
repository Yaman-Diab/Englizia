import 'package:dio/dio.dart';

/// Headers sent with every request so the backend can localize responses
/// and gate old app versions.
class AppHeadersInterceptor extends Interceptor {
  AppHeadersInterceptor({
    required String Function() languageCode,
    required String appVersion,
    required String platform,
  }) : _languageCode = languageCode,
       _appVersion = appVersion,
       _platform = platform;

  final String Function() _languageCode;
  final String _appVersion;
  final String _platform;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll({
      'Accept': 'application/json',
      'Accept-Language': _languageCode(),
      'X-App-Version': _appVersion,
      'X-Platform': _platform,
    });
    handler.next(options);
  }
}
