enum ChartType {
  bar,
  horizontalBar,
  line,
  pie,
  groupedBar,
  horizontalGroupedBar;

  static ChartType? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'bar':
        return ChartType.bar;
      case 'horizontal_bar':
        return ChartType.horizontalBar;
      case 'line':
        return ChartType.line;
      case 'pie':
        return ChartType.pie;
      case 'grouped_bar':
        return ChartType.groupedBar;
      case 'horizontal_grouped_bar':
        return ChartType.horizontalGroupedBar;
      default:
        return null;
    }
  }
}

class VisualizationConfig {
  final bool shouldVisualize;
  final ChartType? chartType;
  final String? xAxis;
  final String? yAxis;
  final String? yAxisSecondary;
  final List<String>? yAxisList;
  final String? groupBy;
  final String? title;

  VisualizationConfig({
    required this.shouldVisualize,
    this.chartType,
    this.xAxis,
    this.yAxis,
    this.yAxisSecondary,
    this.yAxisList,
    this.groupBy,
    this.title,
  });

  factory VisualizationConfig.fromJson(Map<String, dynamic> json) {
    return VisualizationConfig(
      shouldVisualize: json['should_visualize'] ?? false,
      chartType: ChartType.fromString(json['chart_type'] as String?),
      xAxis: json['x_axis'] as String?,
      yAxis: json['y_axis'] as String?,
      yAxisSecondary: json['y_axis_secondary'] as String?,
      yAxisList: (json['y_axis_list'] as List?)?.cast<String>(),
      groupBy: json['group_by'] as String?,
      title: json['title'] as String?,
    );
  }
}
