import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'api_exceptions.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Called when a 401 is received — triggers logout in auth provider
  VoidCallback? onUnauthorized;

  ApiClient({String? baseUrl, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Auth interceptor — adds Bearer token and handles 401
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Skip auth header for login endpoint
        if (!options.path.contains('/api/login')) {
          final token = await _storage.read(key: 'fleet_auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: 'fleet_auth_token');
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) {
        // Only log in debug mode
        assert(() {
          // ignore: avoid_print
          print(obj);
          return true;
        }());
      },
    ));
  }

  /// GET request
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST request
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST request returning raw stream (for SSE)
  Future<Response<ResponseBody>> postStream(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.post<ResponseBody>(
        path,
        data: data,
        options: Options(responseType: ResponseType.stream),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
