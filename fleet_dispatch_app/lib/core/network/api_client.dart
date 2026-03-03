import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'api_exceptions.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({String? baseUrl}) {
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
