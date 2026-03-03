import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';

import '../../core/config/app_colors.dart';
import '../../models/table_data.dart';
import '../../models/visualization_config.dart';
import '../chat/data_table_view.dart';
import 'bar_chart_view.dart';
import 'horizontal_bar_view.dart';
import 'line_chart_view.dart';
import 'pie_chart_view.dart';
import 'grouped_bar_view.dart';

/// Data point for simple charts (bar, line, pie)
class ChartDataPoint {
  final String name;
  final double value;

  ChartDataPoint({required this.name, required this.value});
}

class ChartWidget extends StatefulWidget {
  final VisualizationConfig visualization;
  final TableData tableData;

  const ChartWidget({
    super.key,
    required this.visualization,
    required this.tableData,
  });

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget> {
  bool _showChart = true;
  final _chartKey = GlobalKey();
  bool _wrapForShare = false;

  List<ChartDataPoint> _transformData() {
    final xAxis =
        widget.visualization.xAxis ?? widget.tableData.columns.first;
    final yAxis = widget.visualization.yAxis ??
        (widget.tableData.columns.length > 1
            ? widget.tableData.columns[1]
            : widget.tableData.columns.first);
    final xIndex = widget.tableData.columns.indexOf(xAxis);
    final yIndex = widget.tableData.columns.indexOf(yAxis);

    return widget.tableData.rows.map((row) {
      final xi = xIndex >= 0 ? xIndex : 0;
      final yi = yIndex >= 0 ? yIndex : (row.length > 1 ? 1 : 0);
      return ChartDataPoint(
        name: row[xi]?.toString() ?? '',
        value: _parseDouble(row[yi]),
      );
    }).toList();
  }

  Future<void> _shareChartAsImage() async {
    HapticFeedback.lightImpact();
    try {
      // Temporarily wrap chart in RepaintBoundary for capture
      setState(() => _wrapForShare = true);
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _chartKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _wrapForShare = false);
        return;
      }

      // Use lower pixelRatio on mobile to avoid OOM
      final pixelRatio = kIsWeb ? 3.0 : 1.5;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      // Remove RepaintBoundary immediately after capture
      setState(() => _wrapForShare = false);

      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/chart_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.visualization.title ?? 'Chart',
      );
    } catch (e) {
      setState(() => _wrapForShare = false);
      debugPrint('Chart share failed: $e');
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Chart/Table toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_showChart)
              IconButton(
                icon: const Icon(Icons.share, size: 16),
                tooltip: l10n.shareChart,
                onPressed: _shareChartAsImage,
                visualDensity: VisualDensity.compact,
              ),
            TextButton.icon(
              onPressed: () => setState(() => _showChart = true),
              icon: const Icon(Icons.bar_chart, size: 16),
              label: Text(l10n.showChart),
              style: TextButton.styleFrom(
                foregroundColor:
                    _showChart ? AppColors.indigo500 : AppColors.textMuted,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showChart = false),
              icon: const Icon(Icons.table_chart, size: 16),
              label: Text(l10n.showTable),
              style: TextButton.styleFrom(
                foregroundColor:
                    !_showChart ? AppColors.indigo500 : AppColors.textMuted,
              ),
            ),
          ],
        ),

        // Content
        if (_showChart)
          _buildChartContainer()
        else
          DataTableView(tableData: widget.tableData),
      ],
    );
  }

  Widget _buildChartContainer() {
    final chart = SizedBox(
      height: 300,
      child: _buildChart(),
    );

    // Only wrap in RepaintBoundary when capturing for share
    if (_wrapForShare) {
      return RepaintBoundary(
        key: _chartKey,
        child: chart,
      );
    }
    return chart;
  }

  Widget _buildChart() {
    final config = widget.visualization;
    final data = _transformData();

    switch (config.chartType) {
      case ChartType.bar:
        return BarChartView(data: data, config: config);
      case ChartType.horizontalBar:
        return HorizontalBarView(data: data, config: config);
      case ChartType.line:
        return LineChartView(data: data, config: config);
      case ChartType.pie:
        return PieChartView(data: data, config: config);
      case ChartType.groupedBar:
        return GroupedBarView(
          tableData: widget.tableData,
          config: config,
          horizontal: false,
        );
      case ChartType.horizontalGroupedBar:
        return GroupedBarView(
          tableData: widget.tableData,
          config: config,
          horizontal: true,
        );
      default:
        return const Center(child: Text('Unsupported chart type'));
    }
  }
}
