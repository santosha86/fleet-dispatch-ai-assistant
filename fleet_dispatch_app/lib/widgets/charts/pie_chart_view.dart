import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';
import '../../models/visualization_config.dart';
import 'chart_widget.dart';

class PieChartView extends StatelessWidget {
  final List<ChartDataPoint> data;
  final VisualizationConfig config;

  const PieChartView({
    super.key,
    required this.data,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.fold<double>(0, (sum, item) => sum + item.value);

    return Row(
      children: [
        // Pie chart
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: data.asMap().entries.map((entry) {
                final percentage = total > 0
                    ? (entry.value.value / total * 100)
                    : 0.0;
                final colorIndex = entry.key % AppColors.chartColors.length;

                return PieChartSectionData(
                  color: AppColors.chartColors[colorIndex],
                  value: entry.value.value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  titlePositionPercentageOffset: 0.6,
                );
              }).toList(),
            ),
          ),
        ),

        // Legend
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.asMap().entries.map((entry) {
                final colorIndex = entry.key % AppColors.chartColors.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.chartColors[colorIndex],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.value.name,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
