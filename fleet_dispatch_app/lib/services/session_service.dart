import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class SessionService {
  final ApiClient _apiClient;

  SessionService(this._apiClient);

  /// Clear session conversation history
  Future<void> clearSession(String sessionId) async {
    await _apiClient.post(
      ApiEndpoints.sessionClear,
      data: {'session_id': sessionId},
    );
  }
}
