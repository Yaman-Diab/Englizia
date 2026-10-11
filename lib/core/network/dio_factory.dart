import 'package:dio/dio.dart';
import 'package:englizia/core/config/app_config.dart';
import 'package:englizia/core/network/auth_interceptor.dart';
import 'package:englizia/core/network/redacting_log_interceptor.dart';
import 'package:englizia/core/network/token_refresh_service.dart';
import 'package:englizia/core/storage/token_storage.dart';
import 'package:flutter/foundation.dart';

abstract final class DioFactory {
  static BaseOptions baseOptions(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: AppConfig.jsonTimeout,
    sendTimeout: AppConfig.jsonTimeout,
    receiveTimeout: AppConfig.jsonTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  );

  /// App-wide client: headers → auth → (debug) logger.
  /// Uploads override `sendTimeout` per request.
  static Dio createMainDio({
    required String baseUrl,
    required Interceptor headers,
    required TokenStorage tokens,
    required TokenRefresher refresher,
    required Future<void> Function() onSessionExpired,
  }) {
    final dio = Dio(baseOptions(baseUrl));
    dio.interceptors.addAll([
      headers,
      AuthInterceptor(
        tokens: tokens,
        refresher: refresher,
        retry: dio.fetch<Object?>,
        onSessionExpired: onSessionExpired,
      ),
      if (kDebugMode) RedactingLogInterceptor(),
    ]);
    return dio;
  }

  /// Bare client for the refresh call: no auth interceptor, so a failing
  /// refresh can never recurse into another refresh.
  static Dio createRefreshDio({
    required String baseUrl,
    required Interceptor headers,
  }) {
    final dio = Dio(baseOptions(baseUrl));
    dio.interceptors.addAll([
      headers,
      if (kDebugMode) RedactingLogInterceptor(),
    ]);
    return dio;
  }
}
