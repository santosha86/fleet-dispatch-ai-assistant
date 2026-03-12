import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'api_exceptions.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

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

    // Auth interceptor — adds Bearer token and handles 401 with refresh
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Skip auth header for login/refresh/mfa endpoints
        final path = options.path;
        if (!path.contains('/api/login') &&
            !path.contains('/api/token/refresh') &&
            !path.contains('/api/mfa/login')) {
          final token = await _storage.read(key: 'fleet_auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.contains('/api/login') &&
            !error.requestOptions.path.contains('/api/token/refresh') &&
            !error.requestOptions.path.contains('/api/mfa/login')) {
          // Try to refresh the token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the original request with new token
            final newToken = await _storage.read(key: 'fleet_auth_token');
            if (newToken != null) {
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            }
            try {
              final retryResponse = await _dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            } catch (retryError) {
              // Retry failed — fall through to unauthorized
            }
          }
          // Refresh failed — logout
          await _storage.delete(key: 'fleet_auth_token');
          await _storage.delete(key: 'fleet_refresh_token');
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

  /// Attempt to refresh the access token using the stored refresh token.
  Future<bool> _refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refreshToken = await _storage.read(key: 'fleet_refresh_token');
      if (refreshToken == null) return false;

      final response = await _dio.post('/api/token/refresh', data: {
        'refresh_token': refreshToken,
      });

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await _storage.write(key: 'fleet_auth_token', value: data['access_token'] as String);
        if (data['refresh_token'] != null) {
          await _storage.write(key: 'fleet_refresh_token', value: data['refresh_token'] as String);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
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
