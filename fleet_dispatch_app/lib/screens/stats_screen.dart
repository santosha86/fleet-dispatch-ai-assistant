import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../models/ai_overview.dart';
import '../models/usage_stats.dart';
import '../providers/stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final overviewAsync = ref.watch(aiOverviewProvider);
    final statsAsync = ref.watch(usageStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statistics),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(aiOverviewProvider);
          ref.invalidate(usageStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI Overview Section
            overviewAsync.when(
              data: (overview) => _OverviewSection(overview: overview),
              loading: () => const _LoadingCard(),
              error: (e, s) => _ErrorCard(
                message: l10n.errorServer,
                onRetry: () => ref.invalidate(aiOverviewProvider),
              ),
            ),
            const SizedBox(height: 16),

            // Usage Stats Section
            statsAsync.when(
              data: (stats) => _UsageStatsSection(stats: stats),
              loading: () => const _LoadingCard(),
              error: (e, s) => _ErrorCard(
                message: l10n.errorServer,
                onRetry: () => ref.invalidate(usageStatsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final AIAssistantOverview overview;
  const _OverviewSection({required this.overview});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Header card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.userBubbleGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (overview.languageSupport.isNotEmpty)
                        Text(
                          overview.languageSupport,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Key metrics grid
        if (overview.keyMetrics.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: overview.keyMetrics.map((metric) {
              return _KeyMetricCard(metric: metric);
            }).toList(),
          ),
        ],

        // Capabilities
        if (overview.capabilities.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.capabilities,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...overview.capabilities.map(
                    (cap) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            _capabilityIcon(cap.icon),
                            size: 20,
                            color: AppColors.indigo500,
                          ),
                          const SizedBox(width: 12),
                          Text(cap.label),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Process comparison
        if (overview.processComparison.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Before',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...(overview.processComparison['old_way'] ?? [])
                                .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.close,
                                        size: 14, color: AppColors.error),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(item,
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'After',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...(overview.processComparison['new_way'] ?? [])
                                .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.check,
                                        size: 14, color: AppColors.success),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(item,
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _capabilityIcon(String icon) {
    switch (icon) {
      case 'search':
        return Icons.search;
      case 'chart':
        return Icons.bar_chart;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'trending':
        return Icons.trending_up;
      default:
        return Icons.star_outline;
    }
  }
}

class _KeyMetricCard extends StatelessWidget {
  final KeyMetric metric;
  const _KeyMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              metric.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.indigo500,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              metric.label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageStatsSection extends StatelessWidget {
  final UsageStatsData stats;
  const _UsageStatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Key stats row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.query_stats,
                label: l10n.queriesProcessed,
                value: stats.queriesProcessed.toString(),
                color: AppColors.indigo500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.timer_outlined,
                label: l10n.avgResponseTime,
                value: stats.avgResponseTime,
                color: AppColors.purple600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.thumb_up_outlined,
                label: l10n.userSatisfaction,
                value: stats.userSatisfaction,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.people_outlined,
                label: 'Users',
                value: stats.uniqueUsers.toString(),
                color: AppColors.warning,
              ),
            ),
          ],
        ),

        // Top categories breakdown
        if (stats.topCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Categories',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...stats.topCategories.entries.map(
                    (entry) => _CategoryRow(
                      category: entry.key,
                      percentage: entry.value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String category;
  final String percentage;

  const _CategoryRow({
    required this.category,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final pctValue = double.tryParse(
            percentage.replaceAll('%', '').trim()) ??
        0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                percentage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pctValue / 100,
              backgroundColor: AppColors.indigo500.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.indigo500),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
