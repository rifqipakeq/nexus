import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// wrapper dio untuk konfigurasi base url, timeout, dan logging
class ApiService {
  late final Dio dio;

  ApiService({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_LoggingInterceptor());
  }

  // GET
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.get(path, queryParameters: queryParameters, options: options);
  }

  // POST
  Future<Response> post(String path, {dynamic data, Options? options}) {
    return dio.post(path, data: data, options: options);
  }
}

/// logging data hanya pada debug mode
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('→ ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('← ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('✖ ${err.message} ${err.requestOptions.uri}');
    }
    handler.next(err);
  }
}
