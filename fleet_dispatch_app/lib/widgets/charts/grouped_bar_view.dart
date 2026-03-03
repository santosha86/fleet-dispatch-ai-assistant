import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';
import '../../models/table_data.dart';
import '../../models/visualization_config.dart';

class GroupedBarView extends StatelessWidget {
  final TableData tableData;
  final VisualizationConfig config;
  final bool horizontal;

  /// Minimum width per bar group (all rods + spacing)
  static const double _minGroupWidth = 50.0;

  const GroupedBarView({
    super.key,
    required this.tableData,
    required this.config,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final pivotResult = _pivotData() ?? _wideFormatData();
    if (pivotResult == null) return const Center(child: Text('No data'));

    final xLabels = pivotResult.xLabels;
    final groupNames = pivotResult.groupNames;
    final pivotedData = pivotResult.data;

    final maxY = pivotedData.values.fold<double>(0, (max, groupMap) {
      final groupMax =
          groupMap.values.fold<double>(0, (m, v) => v > m ? v : m);
      return groupMax > max ? groupMax : max;
    });

    // Calculate minimum width needed for all bar groups
    final minChartWidth = xLabels.length * _minGroupWidth;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16, end: 16, bottom: 8),
      child: Column(
        children: [
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: groupNames.asMap().entries.map((entry) {
              final colorIndex = entry.key % AppColors.chartColors.length;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.chartColors[colorIndex],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.value,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Chart - scrollable horizontally when items don't fit
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final needsScroll = minChartWidth > availableWidth;
                final chartWidth =
                    needsScroll ? minChartWidth : availableWidth;

                final chart = SizedBox(
                  width: chartWidth,
                  child: _buildBarChart(
                    xLabels: xLabels,
                    groupNames: groupNames,
                    pivotedData: pivotedData,
                    maxY: maxY,
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
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart({
    required List<String> xLabels,
    required List<String> groupNames,
    required Map<String, Map<String, double>> pivotedData,
    required double maxY,
  }) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final idx = group.x.toInt();
              if (idx < 0 || idx >= xLabels.length) return null;
              final xLabel = xLabels[idx];
              if (rodIndex >= groupNames.length) return null;
              final gName = groupNames[rodIndex];
              return BarTooltipItem(
                '$xLabel\n$gName: ${rod.toY.toStringAsFixed(1)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= xLabels.length) {
                  return const SizedBox.shrink();
                }
                final label = xLabels[index];
                return SideTitleWidget(
                  meta: meta,
                  child: RotatedBox(
                    quarterTurns: xLabels.length > 5 ? -1 : 0,
                    child: Text(
                      label.length > 12
                          ? '${label.substring(0, 10)}..'
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
        barGroups: xLabels.asMap().entries.map((entry) {
          final xLabel = entry.value;
          final groupData = pivotedData[xLabel] ?? {};

          return BarChartGroupData(
            x: entry.key,
            barRods: groupNames.asMap().entries.map((gEntry) {
              final colorIndex =
                  gEntry.key % AppColors.chartColors.length;
              final value = groupData[gEntry.value] ?? 0.0;
              return BarChartRodData(
                toY: value,
                width: groupNames.length > 3 ? 8 : 14,
                color: AppColors.chartColors[colorIndex],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
      // Disable animations for large datasets to reduce GPU/memory pressure
      duration: xLabels.length > 20 ? Duration.zero : const Duration(milliseconds: 150),
    );
  }

  _PivotResult? _pivotData() {
    final xAxis = config.xAxis;
    final yAxis = config.yAxis;
    final groupBy = config.groupBy;

    if (xAxis == null || yAxis == null || groupBy == null) return null;

    final xIdx = tableData.columns.indexOf(xAxis);
    final yIdx = tableData.columns.indexOf(yAxis);
    final gIdx = tableData.columns.indexOf(groupBy);

    if (xIdx < 0 || yIdx < 0 || gIdx < 0) return null;

    final groupNames = <String>{};
    final xLabels = <String>{};

    // {xLabel: {groupName: value}}
    final data = <String, Map<String, double>>{};

    for (final row in tableData.rows) {
      final xVal = row[xIdx]?.toString() ?? '';
      final gVal = row[gIdx]?.toString() ?? '';
      final yVal = row[yIdx] is num
          ? (row[yIdx] as num).toDouble()
          : double.tryParse(row[yIdx]?.toString() ?? '') ?? 0;

      xLabels.add(xVal);
      groupNames.add(gVal);
      data.putIfAbsent(xVal, () => {});
      data[xVal]![gVal] = yVal;
    }

    return _PivotResult(
      xLabels: xLabels.toList(),
      groupNames: groupNames.toList(),
      data: data,
    );
  }

  _PivotResult? _wideFormatData() {
    final xAxis = config.xAxis;
    if (xAxis == null) return null;

    final xIdx = tableData.columns.indexOf(xAxis);
    if (xIdx < 0) return null;

    // Determine which columns are the Y-axis values (each becomes a "group")
    List<String> yCols;
    if (config.yAxisList != null && config.yAxisList!.isNotEmpty) {
      yCols = config.yAxisList!;
    } else if (config.yAxis != null) {
      yCols = [
        config.yAxis!,
        if (config.yAxisSecondary != null) config.yAxisSecondary!,
      ];
    } else {
      return null;
    }

    // Resolve column indices, skip any that don't exist
    final yIndices = <int>[];
    final groupNames = <String>[];
    for (final col in yCols) {
      final idx = tableData.columns.indexOf(col);
      if (idx >= 0) {
        yIndices.add(idx);
        groupNames.add(col);
      }
    }
    if (groupNames.isEmpty) return null;

    final xLabels = <String>{};
    final data = <String, Map<String, double>>{};

    for (final row in tableData.rows) {
      final xVal = row[xIdx]?.toString() ?? '';
      xLabels.add(xVal);
      data.putIfAbsent(xVal, () => {});

      for (int i = 0; i < yIndices.length; i++) {
        final yIdx = yIndices[i];
        final yVal = yIdx < row.length && row[yIdx] is num
            ? (row[yIdx] as num).toDouble()
            : double.tryParse(
                    yIdx < row.length ? (row[yIdx]?.toString() ?? '') : '') ??
                0;
        data[xVal]![groupNames[i]] = yVal;
      }
    }

    return _PivotResult(
      xLabels: xLabels.toList(),
      groupNames: groupNames,
      data: data,
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _PivotResult {
  final List<String> xLabels;
  final List<String> groupNames;
  final Map<String, Map<String, double>> data;

  _PivotResult({
    required this.xLabels,
    required this.groupNames,
    required this.data,
  });
}
