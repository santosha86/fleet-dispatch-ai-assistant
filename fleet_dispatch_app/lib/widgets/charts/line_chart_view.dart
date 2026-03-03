import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';
import '../../models/visualization_config.dart';
import 'chart_widget.dart';

class LineChartView extends StatelessWidget {
  final List<ChartDataPoint> data;
  final VisualizationConfig config;

  /// Minimum width per data point for horizontal scrolling
  static const double _minPointWidth = 40.0;

  const LineChartView({
    super.key,
    required this.data,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY =
        data.fold<double>(0, (max, d) => d.value > max ? d.value : max);
    final minY = data.fold<double>(
        double.infinity, (min, d) => d.value < min ? d.value : min);
    final minChartWidth = data.length * _minPointWidth;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16, end: 16, bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final needsScroll = minChartWidth > availableWidth;
          final chartWidth = needsScroll ? minChartWidth : availableWidth;

          final chart = SizedBox(
            width: chartWidth,
            child: LineChart(
              LineChartData(
                minY: minY > 0 ? 0 : minY * 1.1,
                maxY: maxY * 1.15,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final idx = spot.x.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return LineTooltipItem('', const TextStyle());
                        }
                        return LineTooltipItem(
                          '${data[idx].name}\n${spot.y.toStringAsFixed(1)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: data.length > 10
                          ? (data.length / 5).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final label = data[index].name;
                        return SideTitleWidget(
                          meta: meta,
                          child: RotatedBox(
                            quarterTurns: data.length > 5 ? -1 : 0,
                            child: Text(
                              label.length > 10
                                  ? '${label.substring(0, 8)}..'
                                  : label,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
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
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(
                          entry.key.toDouble(), entry.value.value);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.chartColors[0],
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: data.length <= 20,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.chartColors[0]
                          .withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
              duration: data.length > 20
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
            ),
          );

          if (needsScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
