import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:fleet_dispatch_app/core/network/api_exceptions.dart';

void main() {
  group('ApiException', () {
    test('constructor stores message and statusCode', () {
      final exception = ApiException(
        message: 'Server error',
        statusCode: 500,
        data: {'detail': 'Internal error'},
      );

      expect(exception.message, 'Server error');
      expect(exception.statusCode, 500);
      expect(exception.data, isNotNull);
    });

    test('toString formats correctly', () {
      final exception = ApiException(message: 'Not found', statusCode: 404);
      expect(exception.toString(), 'ApiException: Not found (status: 404)');
    });

    test('toString handles null statusCode', () {
      final exception = ApiException(message: 'Timeout');
      expect(exception.toString(), 'ApiException: Timeout (status: null)');
    });

    test('fromDioException handles connectionTimeout', () {
      final dioError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('timed out'));
    });

    test('fromDioException handles sendTimeout', () {
      final dioError = DioException(
        type: DioExceptionType.sendTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('timed out'));
    });

    test('fromDioException handles receiveTimeout', () {
      final dioError = DioException(
        type: DioExceptionType.receiveTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('timed out'));
    });

    test('fromDioException handles 500+ server error', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 503,
          requestOptions: RequestOptions(path: '/test'),
        ),
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('Server error'));
      expect(exception.statusCode, 503);
    });

    test('fromDioException handles 4xx with detail message', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 422,
          data: {'detail': 'Validation failed'},
          requestOptions: RequestOptions(path: '/test'),
        ),
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, 'Validation failed');
      expect(exception.statusCode, 422);
    });

    test('fromDioException handles 4xx without detail', () {
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 400,
          data: 'Bad request',
          requestOptions: RequestOptions(path: '/test'),
        ),
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, 'Request failed.');
      expect(exception.statusCode, 400);
    });

    test('fromDioException handles connectionError', () {
      final dioError = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('internet connection'));
    });

    test('fromDioException handles cancel', () {
      final dioError = DioException(
        type: DioExceptionType.cancel,
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('cancelled'));
    });

    test('fromDioException handles unknown type', () {
      final dioError = DioException(
        type: DioExceptionType.unknown,
        requestOptions: RequestOptions(path: '/test'),
      );

      final exception = ApiException.fromDioException(dioError);
      expect(exception.message, contains('unexpected error'));
    });
  });
}
