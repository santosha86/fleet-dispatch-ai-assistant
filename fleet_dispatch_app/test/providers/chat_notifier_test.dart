import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_dispatch_app/models/chat_message.dart';
import 'package:fleet_dispatch_app/models/query_response.dart';
import 'package:fleet_dispatch_app/models/sse_event.dart';
import 'package:fleet_dispatch_app/models/table_data.dart';
import 'package:fleet_dispatch_app/providers/chat_provider.dart';
import 'package:fleet_dispatch_app/services/chat_service.dart';
import 'package:fleet_dispatch_app/services/session_service.dart';
import 'package:fleet_dispatch_app/core/network/sse_client.dart';
import '../helpers/mock_api_client.dart';

/// Mock ChatService for unit testing ChatNotifier flows.
class MockChatService extends ChatService {
  String? lastRouteQuery;
  String? lastQueryRoute;
  String? lastQueryText;
  String? lastStreamRoute;
  String? lastStreamQuery;
  int? lastPageSize;
  String? lastFetchResultId;
  int? lastFetchPage;

  final String Function(String query, String sessionId)? onGetRoute;
  final QueryResponse Function(String query, String sessionId, String? route)?
      onSendQuery;
  final Stream<SSEEvent> Function(
      String query, String sessionId, String? route)? onStreamQuery;
  final TableData Function(String resultId, int page, int pageSize)?
      onFetchTablePage;

  MockChatService({
    this.onGetRoute,
    this.onSendQuery,
    this.onStreamQuery,
    this.onFetchTablePage,
  }) : super(MockApiClient(), SSEClient(MockApiClient()));

  @override
  Future<String> getRoute(String query, String sessionId) async {
    lastRouteQuery = query;
    if (onGetRoute != null) return onGetRoute!(query, sessionId);
    return 'sql';
  }

  @override
  Future<QueryResponse> sendQuery({
    required String query,
    required String sessionId,
    String? route,
    int? maxRows,
    int? pageSize,
  }) async {
    lastQueryText = query;
    lastQueryRoute = route;
    lastPageSize = pageSize;
    if (onSendQuery != null) return onSendQuery!(query, sessionId, route);
    return QueryResponse(
      content: 'Default response',
      responseTime: '0.1s',
      sources: ['Test'],
    );
  }

  @override
  Stream<SSEEvent> streamQuery({
    required String query,
    required String sessionId,
    String? route,
    int? maxRows,
    int? pageSize,
  }) {
    lastStreamQuery = query;
    lastStreamRoute = route;
    lastPageSize = pageSize;
    if (onStreamQuery != null) {
      return onStreamQuery!(query, sessionId, route);
    }
    return Stream.fromIterable([
      SSEDoneEvent(
        content: 'Streaming response',
        responseTime: '1.0s',
        sources: ['PDF'],
      ),
    ]);
  }

  @override
  Future<TableData> fetchTablePage({
    required String resultId,
    required int page,
    int pageSize = 100,
  }) async {
    lastFetchResultId = resultId;
    lastFetchPage = page;
    if (onFetchTablePage != null) {
      return onFetchTablePage!(resultId, page, pageSize);
    }
    return TableData(
      columns: ['A'],
      rows: [
        ['page$page']
      ],
    );
  }

  @override
  void cancelStream() {}
}

/// Mock SessionService for unit testing.
class MockSessionService extends SessionService {
  bool clearCalled = false;
  String? lastClearedSessionId;

  MockSessionService() : super(MockApiClient());

  @override
  Future<void> clearSession(String sessionId) async {
    clearCalled = true;
    lastClearedSessionId = sessionId;
  }
}

/// Session service that always throws on clear.
class FailingSessionService extends SessionService {
  FailingSessionService() : super(MockApiClient());

  @override
  Future<void> clearSession(String sessionId) async {
    throw Exception('Session clear failed');
  }
}

void main() {
  group('ChatNotifier - CSV Query Flow', () {
    test('routes csv query to non-streaming handler', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'csv',
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Average dwell time is 4.5 hours.',
          responseTime: '0.3s',
          sources: ['Dwell Time CSV'],
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('What is the average dwell time?');

      expect(notifier.state.messages.length, 2); // user + bot
      expect(notifier.state.messages[0].role, MessageRole.user);
      expect(notifier.state.messages[1].role, MessageRole.assistant);
      expect(notifier.state.messages[1].content, contains('dwell time'));
      expect(mockChat.lastQueryRoute, 'csv');
      expect(notifier.state.isLoading, false);
    });
  });

  group('ChatNotifier - Math Query Flow', () {
    test('routes math query to streaming handler', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'math',
        onStreamQuery: (query, sessionId, route) => Stream.fromIterable([
          SSEPhaseEvent(phase: 'reasoning'),
          SSEPhaseEvent(phase: 'answer', content: 'The answer is 42.'),
          SSEDoneEvent(
            content: 'The answer is 42.',
            responseTime: '2.1s',
            sources: ['Math Engine'],
          ),
        ]),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('Calculate 6 times 7');

      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[1].content, 'The answer is 42.');
      expect(mockChat.lastStreamRoute, 'math');
      expect(notifier.state.isLoading, false);
      expect(notifier.state.streamingContent, '');
    });
  });

  group('ChatNotifier - Out-of-Scope Query Flow', () {
    test('routes out_of_scope query to streaming handler', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'out_of_scope',
        onStreamQuery: (query, sessionId, route) => Stream.fromIterable([
          SSEPhaseEvent(phase: 'planning'),
          SSEDoneEvent(
            content: 'I can only help with dispatch and waybill queries.',
            responseTime: '0.5s',
            sources: ['System'],
          ),
        ]),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('What is the weather today?');

      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[1].content,
          contains('dispatch and waybill'));
      expect(mockChat.lastStreamRoute, 'out_of_scope');
    });
  });

  group('ChatNotifier - Session Clear', () {
    test('clearChat resets messages and generates new session', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'sql',
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Result',
          responseTime: '0.1s',
          sources: ['DB'],
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      // Send a message first
      await notifier.sendMessage('test query');
      expect(notifier.state.messages.length, 2);

      final oldSessionId = notifier.state.sessionId;

      // Clear chat
      await notifier.clearChat();

      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.streamingContent, '');
      expect(notifier.state.sessionId, isNot(equals(oldSessionId)));
      expect(mockSession.clearCalled, true);
    });

    test('clearChat works even if API call fails', () async {
      final mockChat = MockChatService();

      final failingNotifier = ChatNotifier(
        chatService: mockChat,
        sessionService: FailingSessionService(),
      );

      await failingNotifier.sendMessage('test');
      await failingNotifier.clearChat();

      // Should still clear local state
      expect(failingNotifier.state.messages, isEmpty);
    });
  });

  group('ChatNotifier - Follow-up Queries', () {
    test('multiple queries maintain same session until clear', () async {
      final sessionIds = <String>[];

      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) {
          sessionIds.add(sessionId);
          return 'sql';
        },
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Response for: $query',
          responseTime: '0.1s',
          sources: ['DB'],
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('First query');
      await notifier.sendMessage('Follow-up query');

      expect(notifier.state.messages.length, 4); // 2 user + 2 bot
      expect(sessionIds[0], equals(sessionIds[1]));
    });

    test('session changes after clearChat', () async {
      final sessionIds = <String>[];

      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) {
          sessionIds.add(sessionId);
          return 'sql';
        },
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Response',
          responseTime: '0.1s',
          sources: ['DB'],
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('Before clear');
      await notifier.clearChat();
      await notifier.sendMessage('After clear');

      expect(sessionIds[0], isNot(equals(sessionIds[1])));
    });
  });

  group('ChatNotifier - Clarification Flow', () {
    test('sendMessage with forcedRoute skips routing', () async {
      bool routeCalled = false;

      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) {
          routeCalled = true;
          return 'sql';
        },
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Forced route result',
          responseTime: '0.2s',
          sources: ['DB'],
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('my query', forcedRoute: 'sql');

      expect(routeCalled, false);
      expect(mockChat.lastQueryRoute, 'sql');
      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[1].content, 'Forced route result');
    });

    test('forcedRoute csv goes to non-streaming handler', () async {
      final mockChat = MockChatService(
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'CSV forced result',
          responseTime: '0.1s',
          sources: ['CSV'],
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('dwell time', forcedRoute: 'csv');

      expect(mockChat.lastQueryRoute, 'csv');
      expect(notifier.state.messages[1].content, 'CSV forced result');
    });

    test('forcedRoute pdf goes to streaming handler', () async {
      final mockChat = MockChatService(
        onStreamQuery: (query, sessionId, route) => Stream.fromIterable([
          SSEDoneEvent(
            content: 'PDF forced result',
            responseTime: '1.0s',
            sources: ['PDF Manual'],
          ),
        ]),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('dwell time policy', forcedRoute: 'pdf');

      expect(mockChat.lastStreamRoute, 'pdf');
      expect(notifier.state.messages[1].content, 'PDF forced result');
    });
  });

  group('ChatNotifier - Error Handling', () {
    test('empty messages are rejected', () async {
      final mockChat = MockChatService();
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('   ');

      expect(notifier.state.messages, isEmpty);
    });

    test('streaming error event shows error message', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'pdf',
        onStreamQuery: (query, sessionId, route) => Stream.fromIterable([
          SSEErrorEvent(message: 'LLM service unavailable'),
        ]),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('test query');

      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[1].content,
          contains('LLM service unavailable'));
      expect(notifier.state.isLoading, false);
    });

    test('API error during route call shows error message', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => throw Exception('Network error'),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('test query');

      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[1].content, contains('Error'));
      expect(notifier.state.isLoading, false);
    });
  });

  group('ChatNotifier - Category Selection', () {
    test('selectCategory updates state', () {
      final mockChat = MockChatService();
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      notifier.selectCategory('waybills');
      expect(notifier.state.selectedCategory, 'waybills');

      notifier.selectCategory('operations');
      expect(notifier.state.selectedCategory, 'operations');
    });

    test('selectCategory with null clears selection', () {
      final mockChat = MockChatService();
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      notifier.selectCategory('waybills');
      expect(notifier.state.selectedCategory, 'waybills');

      notifier.selectCategory(null);
      expect(notifier.state.selectedCategory, isNull);
    });

    test('sending message clears category selection', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'sql',
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Result',
          responseTime: '0.1s',
          sources: ['DB'],
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      notifier.selectCategory('waybills');
      expect(notifier.state.selectedCategory, 'waybills');

      await notifier.sendMessage('How many waybills?');
      expect(notifier.state.selectedCategory, isNull);
    });
  });

  group('ChatNotifier - Pagination', () {
    test('sendQuery passes pageSize to ChatService', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'sql',
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Paginated result',
          responseTime: '0.5s',
          sources: ['DB'],
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('Show all waybills');

      expect(mockChat.lastPageSize, 100);
    });

    test('streamQuery passes pageSize to ChatService', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'pdf',
        onStreamQuery: (query, sessionId, route) => Stream.fromIterable([
          SSEDoneEvent(
            content: 'Streamed result',
            responseTime: '1.0s',
            sources: ['PDF'],
          ),
        ]),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('Some PDF query');

      expect(mockChat.lastPageSize, 100);
    });

    test('loadPage fetches a specific page and replaces rows', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'sql',
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Table result',
          responseTime: '0.5s',
          sources: ['DB'],
          tableData: TableData(
            columns: ['Name', 'Value'],
            rows: [
              ['Row1', '100'],
              ['Row2', '200'],
            ],
            totalRowCount: 6,
            resultId: 'test-result-123',
            page: 1,
            totalPages: 3,
            pageSize: 2,
          ),
        ),
        onFetchTablePage: (resultId, page, pageSize) => TableData(
          columns: ['Name', 'Value'],
          rows: [
            ['Row3', '300'],
            ['Row4', '400'],
          ],
          totalRowCount: 6,
          resultId: 'test-result-123',
          page: 2,
          totalPages: 3,
          pageSize: 2,
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      // Send initial query to get paginated data
      await notifier.sendMessage('Show data');
      expect(notifier.state.messages.length, 2);

      final botMessage = notifier.state.messages[1];
      expect(botMessage.metadata?.tableData?.rows.length, 2);
      expect(botMessage.metadata?.tableData?.hasMorePages, true);

      // Load page 2
      await notifier.loadPage(botMessage.id, 2);

      // Verify rows were replaced (not appended)
      final updatedMessage = notifier.state.messages[1];
      expect(updatedMessage.metadata?.tableData?.rows.length, 2);
      expect(updatedMessage.metadata?.tableData?.rows[0][0], 'Row3');
      expect(updatedMessage.metadata?.tableData?.page, 2);
      expect(updatedMessage.metadata?.tableData?.totalPages, 3);
      expect(notifier.state.loadingMoreMessageId, isNull);
    });

    test('loadPage skips if already on requested page', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'sql',
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Result',
          responseTime: '0.1s',
          sources: ['DB'],
          tableData: TableData(
            columns: ['A'],
            rows: [
              ['val1']
            ],
            totalRowCount: 10,
            resultId: 'test-id',
            page: 1,
            totalPages: 5,
            pageSize: 2,
          ),
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('Query');
      final msgId = notifier.state.messages[1].id;

      // Request page 1 again — should be a no-op
      await notifier.loadPage(msgId, 1);

      expect(mockChat.lastFetchResultId, isNull); // fetchTablePage not called
    });

    test('loadPage does nothing for non-paginated results', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'sql',
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Small result',
          responseTime: '0.1s',
          sources: ['DB'],
          tableData: TableData(
            columns: ['A'],
            rows: [
              ['val1']
            ],
            totalRowCount: 1,
          ),
        ),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('Small query');
      final msgId = notifier.state.messages[1].id;

      await notifier.loadPage(msgId, 2);

      // Should remain unchanged (no resultId)
      expect(notifier.state.messages[1].metadata?.tableData?.rows.length, 1);
    });

    test('loadPage handles invalid messageId gracefully', () async {
      final mockChat = MockChatService();
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      // Should not throw
      await notifier.loadPage('non-existent-id', 2);
      expect(notifier.state.loadingMoreMessageId, isNull);
    });

    test('loadPage clears loading state on error', () async {
      final mockChat = MockChatService(
        onGetRoute: (query, sessionId) => 'sql',
        onSendQuery: (query, sessionId, route) => QueryResponse(
          content: 'Result',
          responseTime: '0.1s',
          sources: ['DB'],
          tableData: TableData(
            columns: ['A'],
            rows: [
              ['val1']
            ],
            totalRowCount: 10,
            resultId: 'expired-result',
            page: 1,
            totalPages: 5,
            pageSize: 2,
          ),
        ),
        onFetchTablePage: (resultId, page, pageSize) =>
            throw Exception('Result expired'),
      );
      final mockSession = MockSessionService();

      final notifier = ChatNotifier(
        chatService: mockChat,
        sessionService: mockSession,
      );

      await notifier.sendMessage('Query');
      final msgId = notifier.state.messages[1].id;

      await notifier.loadPage(msgId, 3);

      expect(notifier.state.loadingMoreMessageId, isNull);
      // Original data should remain unchanged
      expect(notifier.state.messages[1].metadata?.tableData?.rows.length, 1);
    });
  });
}
