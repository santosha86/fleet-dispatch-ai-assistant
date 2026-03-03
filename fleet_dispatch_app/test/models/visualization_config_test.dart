import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/visualization_config.dart';

void main() {
  group('ChartType', () {
    test('fromString parses all chart types', () {
      expect(ChartType.fromString('bar'), ChartType.bar);
      expect(ChartType.fromString('horizontal_bar'), ChartType.horizontalBar);
      expect(ChartType.fromString('line'), ChartType.line);
      expect(ChartType.fromString('pie'), ChartType.pie);
      expect(ChartType.fromString('grouped_bar'), ChartType.groupedBar);
      expect(
          ChartType.fromString('horizontal_grouped_bar'),
          ChartType.horizontalGroupedBar);
    });

    test('fromString returns null for unknown type', () {
      expect(ChartType.fromString('scatter'), null);
      expect(ChartType.fromString(''), null);
    });

    test('fromString returns null for null input', () {
      expect(ChartType.fromString(null), null);
    });
  });

  group('VisualizationConfig', () {
    test('fromJson parses full config', () {
      final json = {
        'should_visualize': true,
        'chart_type': 'bar',
        'x_axis': 'Waybill Status Desc',
        'y_axis': 'count',
        'y_axis_secondary': null,
        'y_axis_list': null,
        'group_by': null,
        'title': 'Waybill Status Distribution',
      };

      final config = VisualizationConfig.fromJson(json);

      expect(config.shouldVisualize, true);
      expect(config.chartType, ChartType.bar);
      expect(config.xAxis, 'Waybill Status Desc');
      expect(config.yAxis, 'count');
      expect(config.yAxisSecondary, null);
      expect(config.yAxisList, null);
      expect(config.groupBy, null);
      expect(config.title, 'Waybill Status Distribution');
    });

    test('fromJson parses grouped bar with y_axis_list', () {
      final json = {
        'should_visualize': true,
        'chart_type': 'grouped_bar',
        'x_axis': 'Vendor Name',
        'y_axis': 'cancelled',
        'y_axis_secondary': 'expired',
        'y_axis_list': ['cancelled', 'expired', 'rejected'],
        'group_by': null,
        'title': 'Vendor Comparison',
      };

      final config = VisualizationConfig.fromJson(json);

      expect(config.chartType, ChartType.groupedBar);
      expect(config.yAxisList, ['cancelled', 'expired', 'rejected']);
      expect(config.yAxisSecondary, 'expired');
    });

    test('fromJson handles no-visualization response', () {
      final json = {
        'should_visualize': false,
        'chart_type': null,
        'x_axis': null,
        'y_axis': null,
        'y_axis_secondary': null,
        'y_axis_list': null,
        'group_by': null,
        'title': null,
      };

      final config = VisualizationConfig.fromJson(json);

      expect(config.shouldVisualize, false);
      expect(config.chartType, null);
    });

    test('fromJson defaults should_visualize to false when missing', () {
      final json = <String, dynamic>{};
      final config = VisualizationConfig.fromJson(json);
      expect(config.shouldVisualize, false);
    });
  });
}
