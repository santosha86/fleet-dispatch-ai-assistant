import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_overview.dart';
import '../models/usage_stats.dart';
import '../services/stats_service.dart';
import 'chat_provider.dart';

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService(ref.read(apiClientProvider));
});

final aiOverviewProvider = FutureProvider<AIAssistantOverview>((ref) {
  return ref.read(statsServiceProvider).getAIOverview();
});

final usageStatsProvider = FutureProvider<UsageStatsData>((ref) {
  return ref.read(statsServiceProvider).getUsageStats();
});
