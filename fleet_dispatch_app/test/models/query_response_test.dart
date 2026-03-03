import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/query_response.dart';

void main() {
  group('QueryResponse', () {
    test('fromJson parses full SQL response', () {
      final json = {
        'content': 'Crude Oil has the highest requested quantity.',
        'response_time': '0.02s',
        'sources': ['Waybills DB'],
        'table_data': {
          'columns': ['Fuel Type Desc', 'total_requested_quantity'],
          'rows': [
            ['Crude Oil (A-030)', 491198200]
          ],
        },
        'sql_query': 'SELECT "Fuel Type Desc" FROM waybills',
        'needs_disambiguation': false,
        'disambiguation_options': null,
        'needs_clarification': false,
        'clarification_message': null,
        'clarification_options': null,
        'visualization': {
          'should_visualize': false,
          'chart_type': null,
          'x_axis': null,
          'y_axis': null,
          'y_axis_secondary': null,
          'y_axis_list': null,
          'group_by': null,
          'title': null,
        },
      };

      final response = QueryResponse.fromJson(json);

      expect(response.content, contains('Crude Oil'));
      expect(response.responseTime, '0.02s');
      expect(response.sources, ['Waybills DB']);
      expect(response.tableData, isNotNull);
      expect(response.tableData!.columns.length, 2);
      expect(response.tableData!.rows.length, 1);
      expect(response.sqlQuery, contains('SELECT'));
      expect(response.needsDisambiguation, false);
      expect(response.needsClarification, false);
      expect(response.visualization, isNotNull);
      expect(response.visualization!.shouldVisualize, false);
    });

    test('fromJson parses disambiguation response', () {
      final json = {
        'content': 'Which status do you mean?',
        'response_time': '0.0s',
        'sources': ['Waybills DB'],
        'table_data': null,
        'sql_query': null,
        'needs_disambiguation': true,
        'disambiguation_options': [
          {
            'value': 'Waybill Status',
            'display': 'Waybill Status',
            'description': 'Current status of the waybill',
          },
          {
            'value': 'Delivery Status',
            'display': 'Delivery Status',
            'description': 'Delivery completion status',
          },
        ],
        'needs_clarification': false,
        'clarification_message': null,
        'clarification_options': null,
        'visualization': null,
      };

      final response = QueryResponse.fromJson(json);

      expect(response.needsDisambiguation, true);
      expect(response.disambiguationOptions, isNotNull);
      expect(response.disambiguationOptions!.length, 2);
      expect(response.disambiguationOptions![0].value, 'Waybill Status');
      expect(response.disambiguationOptions![0].displayText, 'Waybill Status');
      expect(response.tableData, null);
    });

    test('fromJson parses clarification response', () {
      final json = {
        'content': 'This query could be answered from multiple sources.',
        'response_time': '0.1s',
        'sources': ['System'],
        'needs_clarification': true,
        'clarification_message': 'Which data source?',
        'clarification_options': [
          {'value': 'sql', 'label': 'Waybills Database'},
          {'value': 'csv', 'label': 'Dwell Time CSV'},
        ],
      };

      final response = QueryResponse.fromJson(json);

      expect(response.needsClarification, true);
      expect(response.clarificationMessage, 'Which data source?');
      expect(response.clarificationOptions, isNotNull);
      expect(response.clarificationOptions!.length, 2);
      expect(response.clarificationOptions![0].route, 'sql');
      expect(response.clarificationOptions![0].label, 'Waybills Database');
    });

    test('fromJson handles minimal response', () {
      final json = <String, dynamic>{
        'content': 'Hello',
      };

      final response = QueryResponse.fromJson(json);

      expect(response.content, 'Hello');
      expect(response.responseTime, '0s');
      expect(response.sources, ['System']);
      expect(response.needsDisambiguation, false);
      expect(response.needsClarification, false);
    });

    test('fromJson parses chart visualization', () {
      final json = {
        'content': 'Here is the breakdown.',
        'response_time': '15.12s',
        'sources': ['Waybills DB'],
        'table_data': {
          'columns': ['Status', 'count'],
          'rows': [
            ['Cancelled', 4450],
            ['Paid', 13606],
            ['Expired', 1230],
          ],
        },
        'visualization': {
          'should_visualize': true,
          'chart_type': 'bar',
          'x_axis': 'Status',
          'y_axis': 'count',
          'title': 'Waybill Status Distribution',
        },
      };

      final response = QueryResponse.fromJson(json);

      expect(response.visualization, isNotNull);
      expect(response.visualization!.shouldVisualize, true);
      expect(response.visualization!.chartType.toString(), contains('bar'));
      expect(response.tableData, isNotNull);
      expect(response.tableData!.rowCount, 3);
    });
  });
}
