import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';
import '../../models/visualization_config.dart';
import 'chart_widget.dart';

class HorizontalBarView extends StatelessWidget {
  final List<ChartDataPoint> data;
  final VisualizationConfig config;

  /// Minimum height per bar (bar + spacing) for vertical scrolling
  static const double _minBarHeight = 30.0;

  const HorizontalBarView({
    super.key,
    required this.data,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxX =
        data.fold<double>(0, (max, d) => d.value > max ? d.value : max);
    final minChartHeight = data.length * _minBarHeight;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
          top: 16, end: 16, bottom: 8, start: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final needsScroll = minChartHeight > availableHeight;
          final chartHeight = needsScroll ? minChartHeight : availableHeight;

          final chart = SizedBox(
            height: chartHeight,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxX * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final idx = group.x.toInt();
                      if (idx < 0 || idx >= data.length) return null;
                      return BarTooltipItem(
                        '${data[idx].name}\n${rod.toY.toStringAsFixed(1)}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 100,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final label = data[index].name;
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            label.length > 15
                                ? '${label.substring(0, 13)}..'
                                : label,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatNumber(value),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  final colorIndex = entry.key % AppColors.chartColors.length;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value,
                        width: 16,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.chartColors[colorIndex],
                            AppColors.chartColors[colorIndex]
                                .withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
              duration: data.length > 20
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
            ),
          );

          if (needsScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: chart,
            );
          }
          return chart;
        },
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
