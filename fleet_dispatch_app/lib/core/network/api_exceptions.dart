import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timed out. Please try again.',
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null && statusCode >= 500) {
          return ApiException(
            message: 'Server error. Please try again later.',
            statusCode: statusCode,
          );
        }
        final detail = error.response?.data;
        String msg = 'Request failed.';
        if (detail is Map<String, dynamic> && detail.containsKey('detail')) {
          msg = detail['detail'].toString();
        }
        return ApiException(message: msg, statusCode: statusCode);
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'No internet connection. Please check your network.',
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Request was cancelled.');
      default:
        return ApiException(message: 'An unexpected error occurred.');
    }
  }

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
