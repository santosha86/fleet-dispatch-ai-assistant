import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/sse_event.dart';
import 'package:fleet_dispatch_app/models/table_data.dart';
import 'package:fleet_dispatch_app/models/visualization_config.dart';
import 'package:fleet_dispatch_app/models/disambiguation_option.dart';
import 'package:fleet_dispatch_app/models/clarification_option.dart';

void main() {
  group('SSEPhaseEvent', () {
    test('creates with phase and content', () {
      final event = SSEPhaseEvent(phase: 'retrieval', content: 'Searching...');

      expect(event.phase, 'retrieval');
      expect(event.content, 'Searching...');
    });

    test('creates with phase only', () {
      final event = SSEPhaseEvent(phase: 'thinking');

      expect(event.phase, 'thinking');
      expect(event.content, null);
    });

    test('is an SSEEvent', () {
      final SSEEvent event = SSEPhaseEvent(phase: 'streaming');

      expect(event, isA<SSEPhaseEvent>());
      expect(event, isA<SSEEvent>());
    });
  });

  group('SSEDoneEvent', () {
    test('creates with required fields', () {
      final event = SSEDoneEvent(
        content: 'Here is the answer.',
        responseTime: '2.5s',
        sources: ['Waybills DB'],
      );

      expect(event.content, 'Here is the answer.');
      expect(event.responseTime, '2.5s');
      expect(event.sources, ['Waybills DB']);
      expect(event.tableData, null);
      expect(event.sqlQuery, null);
      expect(event.needsDisambiguation, false);
      expect(event.disambiguationOptions, null);
      expect(event.needsClarification, false);
      expect(event.clarificationMessage, null);
      expect(event.clarificationOptions, null);
      expect(event.visualization, null);
    });

    test('creates with all fields', () {
      final tableData = TableData(
        columns: ['Status', 'Count'],
        rows: [
          ['Active', 10],
        ],
      );
      final vizConfig = VisualizationConfig(
        shouldVisualize: true,
        chartType: ChartType.bar,
        xAxis: 'Status',
        yAxis: 'Count',
      );
      final disambigOptions = [
        DisambiguationOption(value: 'opt1'),
      ];
      final clarifyOptions = [
        ClarificationOption(route: 'sql', label: 'DB'),
      ];

      final event = SSEDoneEvent(
        content: 'Full response',
        responseTime: '5.0s',
        sources: ['Waybills DB', 'Dwell Time CSV'],
        tableData: tableData,
        sqlQuery: 'SELECT * FROM waybills',
        needsDisambiguation: true,
        disambiguationOptions: disambigOptions,
        needsClarification: true,
        clarificationMessage: 'Choose a source',
        clarificationOptions: clarifyOptions,
        visualization: vizConfig,
      );

      expect(event.tableData, isNotNull);
      expect(event.tableData!.columns.length, 2);
      expect(event.sqlQuery, contains('SELECT'));
      expect(event.needsDisambiguation, true);
      expect(event.disambiguationOptions!.length, 1);
      expect(event.needsClarification, true);
      expect(event.clarificationMessage, 'Choose a source');
      expect(event.clarificationOptions!.length, 1);
      expect(event.visualization!.shouldVisualize, true);
    });

    test('is an SSEEvent', () {
      final SSEEvent event = SSEDoneEvent(
        content: '',
        responseTime: '0s',
        sources: [],
      );

      expect(event, isA<SSEDoneEvent>());
      expect(event, isA<SSEEvent>());
    });
  });

  group('SSEErrorEvent', () {
    test('creates with message', () {
      final event = SSEErrorEvent(message: 'Connection lost');

      expect(event.message, 'Connection lost');
    });

    test('is an SSEEvent', () {
      final SSEEvent event = SSEErrorEvent(message: 'Error');

      expect(event, isA<SSEErrorEvent>());
      expect(event, isA<SSEEvent>());
    });
  });

  group('SSEEvent sealed class pattern matching', () {
    test('switch handles all subtypes', () {
      final events = <SSEEvent>[
        SSEPhaseEvent(phase: 'retrieval'),
        SSEDoneEvent(content: 'done', responseTime: '1s', sources: []),
        SSEErrorEvent(message: 'err'),
      ];

      final types = events.map((event) {
        return switch (event) {
          SSEPhaseEvent() => 'phase',
          SSEDoneEvent() => 'done',
          SSEErrorEvent() => 'error',
        };
      }).toList();

      expect(types, ['phase', 'done', 'error']);
    });
  });
}
