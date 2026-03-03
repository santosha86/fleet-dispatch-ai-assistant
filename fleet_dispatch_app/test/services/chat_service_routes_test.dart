import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/services/chat_service.dart';
import 'package:fleet_dispatch_app/core/network/sse_client.dart';
import '../helpers/mock_api_client.dart';

void main() {
  group('ChatService - Route Classification', () {
    test('getRoute returns csv route for CSV-related query', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/api/route') {
            return {'route': 'csv'};
          }
          throw Exception('Unexpected path: $path');
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      final route = await chatService.getRoute(
        'Show me the dwell time data from CSV',
        'session-csv-1',
      );

      expect(route, 'csv');
    });

    test('getRoute returns math route for math query', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          return {'route': 'math'};
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      final route = await chatService.getRoute(
        'Calculate the average delivery time',
        'session-math-1',
      );

      expect(route, 'math');
    });

    test('getRoute returns out_of_scope for unrelated queries', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          return {'route': 'out_of_scope'};
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      final route = await chatService.getRoute(
        'What is the weather today?',
        'session-oos-1',
      );

      expect(route, 'out_of_scope');
    });

    test('getRoute sends correct request body', () async {
      dynamic capturedData;

      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          capturedData = data;
          return {'route': 'sql'};
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      await chatService.getRoute('test query', 'my-session');

      expect(capturedData['query'], 'test query');
      expect(capturedData['session_id'], 'my-session');
    });
  });

  group('ChatService - CSV Query', () {
    test('sendQuery with csv route returns response', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/api/query') {
            return {
              'content': 'The average dwell time is 4.5 hours.',
              'response_time': '0.5s',
              'sources': ['Dwell Time CSV'],
              'table_data': {
                'columns': ['Plant', 'Avg Dwell Time'],
                'rows': [
                  ['PP10', 4.5],
                  ['PP11', 3.2],
                ],
              },
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
        query: 'What is the average dwell time?',
        sessionId: 'session-csv-1',
        route: 'csv',
      );

      expect(response.content, contains('dwell time'));
      expect(response.sources, contains('Dwell Time CSV'));
      expect(response.tableData, isNotNull);
      expect(response.tableData!.columns.length, 2);
      expect(response.tableData!.rows.length, 2);
    });

    test('sendQuery with csv route sends correct request data', () async {
      dynamic capturedData;

      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          capturedData = data;
          return {
            'content': 'Result',
            'response_time': '0.1s',
            'sources': ['CSV'],
            'needs_disambiguation': false,
            'needs_clarification': false,
          };
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      await chatService.sendQuery(
        query: 'csv query test',
        sessionId: 'sess-123',
        route: 'csv',
      );

      expect(capturedData['query'], 'csv query test');
      expect(capturedData['session_id'], 'sess-123');
      expect(capturedData['route'], 'csv');
    });
  });

  group('ChatService - Follow-up Queries', () {
    test('sendQuery maintains session_id for follow-ups', () async {
      final requestLog = <Map<String, dynamic>>[];

      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/api/query') {
            requestLog.add(Map<String, dynamic>.from(data as Map));
            return {
              'content': 'Response ${requestLog.length}',
              'response_time': '0.1s',
              'sources': ['Waybills DB'],
              'needs_disambiguation': false,
              'needs_clarification': false,
            };
          }
          if (path == '/api/route') {
            return {'route': 'sql'};
          }
          throw Exception('Unexpected path: $path');
        },
      );
      final sseClient = SSEClient(mockClient);
      final chatService = ChatService(mockClient, sseClient);

      // First query
      await chatService.sendQuery(
        query: 'How many waybills?',
        sessionId: 'persistent-session',
        route: 'sql',
      );

      // Follow-up query with same session
      await chatService.sendQuery(
        query: 'Show me more details',
        sessionId: 'persistent-session',
        route: 'sql',
      );

      expect(requestLog.length, 2);
      expect(requestLog[0]['session_id'], 'persistent-session');
      expect(requestLog[1]['session_id'], 'persistent-session');
      expect(requestLog[0]['query'], 'How many waybills?');
      expect(requestLog[1]['query'], 'Show me more details');
    });
  });
}
