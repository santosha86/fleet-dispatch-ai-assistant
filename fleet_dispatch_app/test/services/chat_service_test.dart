import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/services/chat_service.dart';
import 'package:fleet_dispatch_app/core/network/sse_client.dart';
import '../helpers/mock_api_client.dart';

void main() {
  group('ChatService', () {
    test('getRoute returns route string from API', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/api/route') {
            return {'route': 'sql'};
          }
          throw Exception('Unexpected path: $path');
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      final route = await chatService.getRoute(
        'How many waybills?',
        'session-123',
      );

      expect(route, 'sql');
    });

    test('getRoute returns pdf route', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          return {'route': 'pdf'};
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      final route = await chatService.getRoute(
        'What is the dwell time policy?',
        'session-456',
      );

      expect(route, 'pdf');
    });

    test('sendQuery returns QueryResponse with table data', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/api/query') {
            return {
              'content': 'Crude Oil has the highest quantity.',
              'response_time': '0.02s',
              'sources': ['Waybills DB'],
              'table_data': {
                'columns': ['Fuel Type Desc', 'total_requested_quantity'],
                'rows': [
                  ['Crude Oil (A-030)', 491198200],
                ],
              },
              'sql_query': 'SELECT "Fuel Type Desc" FROM waybills',
              'needs_disambiguation': false,
              'needs_clarification': false,
            };
          }
          throw Exception('Unexpected path: $path');
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      final response = await chatService.sendQuery(
        query: 'Which fuel type has the highest quantity?',
        sessionId: 'session-789',
        route: 'sql',
      );

      expect(response.content, contains('Crude Oil'));
      expect(response.responseTime, '0.02s');
      expect(response.sources, ['Waybills DB']);
      expect(response.tableData, isNotNull);
      expect(response.tableData!.columns.length, 2);
      expect(response.tableData!.rows.length, 1);
      expect(response.sqlQuery, contains('SELECT'));
      expect(response.needsDisambiguation, false);
    });

    test('sendQuery returns disambiguation response', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          return {
            'content': 'Which status do you mean?',
            'response_time': '0.0s',
            'sources': ['Waybills DB'],
            'needs_disambiguation': true,
            'disambiguation_options': [
              {'value': 'Waybill Status', 'display': 'Waybill Status'},
              {'value': 'Delivery Status', 'display': 'Delivery Status'},
            ],
            'needs_clarification': false,
          };
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      final response = await chatService.sendQuery(
        query: 'show status breakdown',
        sessionId: 'session-123',
      );

      expect(response.needsDisambiguation, true);
      expect(response.disambiguationOptions!.length, 2);
      expect(response.disambiguationOptions![0].value, 'Waybill Status');
    });

    test('sendQuery returns clarification response', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          return {
            'content': 'This query could be answered from multiple sources.',
            'response_time': '0.1s',
            'sources': ['System'],
            'needs_disambiguation': false,
            'needs_clarification': true,
            'clarification_message': 'Which data source?',
            'clarification_options': [
              {'value': 'sql', 'label': 'Waybills Database'},
              {'value': 'csv', 'label': 'Dwell Time CSV'},
            ],
          };
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      final response = await chatService.sendQuery(
        query: 'dwell time data',
        sessionId: 'session-123',
      );

      expect(response.needsClarification, true);
      expect(response.clarificationMessage, 'Which data source?');
      expect(response.clarificationOptions!.length, 2);
      expect(response.clarificationOptions![0].route, 'sql');
    });

    test('cancelStream delegates to SSEClient', () {
      final mockClient = MockApiClient();
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      // Should not throw
      chatService.cancelStream();
    });
  });
}
