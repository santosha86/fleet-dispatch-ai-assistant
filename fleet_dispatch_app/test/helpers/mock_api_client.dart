import 'package:dio/dio.dart';
import 'package:fleet_dispatch_app/core/network/api_client.dart';

/// A fake ApiClient that returns predefined responses for testing.
class MockApiClient extends ApiClient {
  final Map<String, dynamic> Function(String path, {dynamic data})? onPost;
  final dynamic Function(String path)? onGet;

  MockApiClient({this.onPost, this.onGet}) : super(baseUrl: 'http://test');

  @override
  Future<Response<dynamic>> post(String path, {dynamic data}) async {
    if (onPost != null) {
      final responseData = onPost!(path, data: data);
      return Response(
        data: responseData,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw UnimplementedError('No onPost handler for $path');
  }

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    if (onGet != null) {
      final responseData = onGet!(path);
      return Response(
        data: responseData,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw UnimplementedError('No onGet handler for $path');
  }
}
