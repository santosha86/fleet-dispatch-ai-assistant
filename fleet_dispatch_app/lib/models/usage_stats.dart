class UsageStatsData {
  final int queriesProcessed;
  final String userSatisfaction;
  final String avgResponseTime;
  final int uniqueUsers;
  final Map<String, String> topCategories;

  UsageStatsData({
    required this.queriesProcessed,
    required this.userSatisfaction,
    required this.avgResponseTime,
    required this.uniqueUsers,
    required this.topCategories,
  });

  factory UsageStatsData.fromJson(Map<String, dynamic> json) {
    return UsageStatsData(
      queriesProcessed: json['queries_processed'] as int? ?? 0,
      userSatisfaction: json['user_satisfaction'] as String? ?? '0%',
      avgResponseTime: json['avg_response_time'] as String? ?? '0s',
      uniqueUsers: json['unique_users'] as int? ?? 0,
      topCategories:
          (json['top_categories'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, value.toString()),
              ) ??
              {},
    );
  }
}
