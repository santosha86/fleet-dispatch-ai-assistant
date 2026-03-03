import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/ai_overview.dart';
import '../models/usage_stats.dart';

class StatsService {
  final ApiClient _apiClient;

  StatsService(this._apiClient);

  /// Fetch AI assistant overview
  Future<AIAssistantOverview> getAIOverview() async {
    final response = await _apiClient.get(ApiEndpoints.aiOverview);
    return AIAssistantOverview.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetch usage statistics
  Future<UsageStatsData> getUsageStats() async {
    final response = await _apiClient.get(ApiEndpoints.usageStats);
    return UsageStatsData.fromJson(response.data as Map<String, dynamic>);
  }
}
