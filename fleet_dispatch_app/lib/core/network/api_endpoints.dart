class ApiEndpoints {
  ApiEndpoints._();

  static const String healthCheck = '/';
  static const String aiOverview = '/api/ai-overview';
  static const String usageStats = '/api/usage-stats';
  static const String categories = '/api/categories';
  static String categoryQueries(String id) => '/api/categories/$id/queries';
  static const String query = '/api/query';
  static const String queryStream = '/api/query/stream';
  static const String route = '/api/route';
  static const String sessionClear = '/api/session/clear';
  static String tableDataPage(String resultId) => '/api/table-data/$resultId';
}
