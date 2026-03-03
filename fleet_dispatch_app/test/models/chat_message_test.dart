import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/chat_message.dart';
import 'package:fleet_dispatch_app/models/query_response.dart';
import 'package:fleet_dispatch_app/models/table_data.dart';
import 'package:fleet_dispatch_app/models/disambiguation_option.dart';
import 'package:fleet_dispatch_app/models/clarification_option.dart';

void main() {
  group('MessageRole', () {
    test('has user and assistant values', () {
      expect(MessageRole.values.length, 2);
      expect(MessageRole.values, contains(MessageRole.user));
      expect(MessageRole.values, contains(MessageRole.assistant));
    });
  });

  group('ChatMessage', () {
    test('creates user message', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg-1',
        role: MessageRole.user,
        content: 'How many waybills?',
        timestamp: now,
      );

      expect(msg.id, 'msg-1');
      expect(msg.role, MessageRole.user);
      expect(msg.content, 'How many waybills?');
      expect(msg.timestamp, now);
      expect(msg.originalQuery, null);
      expect(msg.metadata, null);
    });

    test('creates assistant message with metadata', () {
      final metadata = MessageMetadata(
        responseTime: '0.02s',
        sources: ['Waybills DB'],
        tableData: TableData(
          columns: ['Status', 'Count'],
          rows: [
            ['Active', 5],
          ],
        ),
      );

      final msg = ChatMessage(
        id: 'msg-2',
        role: MessageRole.assistant,
        content: 'There are 5 active waybills.',
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      expect(msg.role, MessageRole.assistant);
      expect(msg.metadata, isNotNull);
      expect(msg.metadata!.responseTime, '0.02s');
      expect(msg.metadata!.sources, ['Waybills DB']);
      expect(msg.metadata!.tableData!.hasData, true);
    });

    test('stores originalQuery for disambiguation/clarification', () {
      final msg = ChatMessage(
        id: 'msg-3',
        role: MessageRole.assistant,
        content: 'Which status?',
        timestamp: DateTime.now(),
        originalQuery: 'show waybill status breakdown',
      );

      expect(msg.originalQuery, 'show waybill status breakdown');
    });
  });

  group('MessageMetadata', () {
    test('creates with defaults', () {
      final metadata = MessageMetadata(
        responseTime: '1.0s',
        sources: ['System'],
      );

      expect(metadata.needsDisambiguation, false);
      expect(metadata.disambiguationOptions, null);
      expect(metadata.needsClarification, false);
      expect(metadata.clarificationMessage, null);
      expect(metadata.clarificationOptions, null);
      expect(metadata.visualization, null);
      expect(metadata.tableData, null);
      expect(metadata.sqlQuery, null);
    });

    test('creates with disambiguation data', () {
      final options = [
        DisambiguationOption(value: 'Waybill Status'),
        DisambiguationOption(value: 'Delivery Status'),
      ];

      final metadata = MessageMetadata(
        responseTime: '0.0s',
        sources: ['Waybills DB'],
        needsDisambiguation: true,
        disambiguationOptions: options,
      );

      expect(metadata.needsDisambiguation, true);
      expect(metadata.disambiguationOptions!.length, 2);
    });

    test('creates with clarification data', () {
      final options = [
        ClarificationOption(route: 'sql', label: 'Waybills DB'),
        ClarificationOption(route: 'csv', label: 'Dwell Time CSV'),
      ];

      final metadata = MessageMetadata(
        responseTime: '0.1s',
        sources: ['System'],
        needsClarification: true,
        clarificationMessage: 'Which data source?',
        clarificationOptions: options,
      );

      expect(metadata.needsClarification, true);
      expect(metadata.clarificationMessage, 'Which data source?');
      expect(metadata.clarificationOptions!.length, 2);
      expect(metadata.clarificationOptions![0].route, 'sql');
    });

    test('fromQueryResponse maps all fields correctly', () {
      final responseJson = {
        'content': 'Result',
        'response_time': '2.5s',
        'sources': ['Waybills DB'],
        'table_data': {
          'columns': ['A', 'B'],
          'rows': [
            [1, 2],
          ],
        },
        'sql_query': 'SELECT A, B FROM t',
        'needs_disambiguation': true,
        'disambiguation_options': [
          {'value': 'opt1', 'display': 'Option 1'},
        ],
        'needs_clarification': false,
        'clarification_message': null,
        'clarification_options': null,
        'visualization': null,
      };

      final queryResponse = QueryResponse.fromJson(responseJson);
      final metadata = MessageMetadata.fromQueryResponse(queryResponse);

      expect(metadata.responseTime, '2.5s');
      expect(metadata.sources, ['Waybills DB']);
      expect(metadata.tableData!.columns, ['A', 'B']);
      expect(metadata.sqlQuery, 'SELECT A, B FROM t');
      expect(metadata.needsDisambiguation, true);
      expect(metadata.disambiguationOptions!.length, 1);
      expect(metadata.disambiguationOptions![0].displayText, 'Option 1');
      expect(metadata.needsClarification, false);
    });
  });
}
