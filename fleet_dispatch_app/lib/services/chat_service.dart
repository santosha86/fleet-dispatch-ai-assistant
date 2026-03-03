import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/sse_client.dart';
import '../models/query_request.dart';
import '../models/query_response.dart';
import '../models/sse_event.dart';
import '../models/table_data.dart';

class ChatService {
  final ApiClient _apiClient;
  final SSEClient _sseClient;

  ChatService(this._apiClient, this._sseClient);

  /// Get route classification for a query
  Future<String> getRoute(String query, String sessionId) async {
    final response = await _apiClient.post(
      ApiEndpoints.route,
      data: QueryRequest(query: query, sessionId: sessionId).toJson(),
    );
    return response.data['route'] as String;
  }

  /// Send a non-streaming query (SQL/CSV)
  Future<QueryResponse> sendQuery({
    required String query,
    required String sessionId,
    String? route,
    int? maxRows,
    int? pageSize,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.query,
      data: QueryRequest(
        query: query,
        sessionId: sessionId,
        route: route,
        maxRows: maxRows,
        pageSize: pageSize,
      ).toJson(),
    );
    return QueryResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Send a streaming query (PDF/Math/Out-of-scope)
  Stream<SSEEvent> streamQuery({
    required String query,
    required String sessionId,
    String? route,
    int? maxRows,
    int? pageSize,
  }) {
    return _sseClient.connect(
      query: query,
      sessionId: sessionId,
      route: route,
      maxRows: maxRows,
      pageSize: pageSize,
    );
  }

  /// Fetch a specific page of cached table data
  Future<TableData> fetchTablePage({
    required String resultId,
    required int page,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.tableDataPage(resultId),
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );
    return TableData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Cancel active streaming
  void cancelStream() {
    _sseClient.cancel();
  }
}
