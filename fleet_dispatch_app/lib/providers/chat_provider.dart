import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/network/sse_client.dart';
import '../core/utils/session_manager.dart';
import '../models/chat_message.dart';
import '../models/sse_event.dart';
import '../services/cache_service.dart';
import '../services/chat_service.dart';
import '../services/session_service.dart';
import 'auth_provider.dart';

// --- Dependency Providers ---

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  client.onUnauthorized = () {
    ref.read(authProvider.notifier).logout();
  };
  return client;
});

final sseClientProvider = Provider<SSEClient>((ref) {
  return SSEClient(ref.read(apiClientProvider));
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(
    ref.read(apiClientProvider),
    ref.read(sseClientProvider),
  );
});

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(ref.read(apiClientProvider));
});

// --- Chat State ---

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String streamingContent;
  final String streamingPhase;
  final String? selectedCategory;
  final String? error;
  final String sessionId;
  final String? loadingMoreMessageId; // ID of message currently loading more rows

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.streamingContent = '',
    this.streamingPhase = '',
    this.selectedCategory,
    this.error,
    required this.sessionId,
    this.loadingMoreMessageId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? streamingContent,
    String? streamingPhase,
    String? selectedCategory,
    String? error,
    bool clearCategory = false,
    bool clearError = false,
    String? loadingMoreMessageId,
    bool clearLoadingMore = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      streamingContent: streamingContent ?? this.streamingContent,
      streamingPhase: streamingPhase ?? this.streamingPhase,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      error: clearError ? null : (error ?? this.error),
      sessionId: sessionId,
      loadingMoreMessageId: clearLoadingMore
          ? null
          : (loadingMoreMessageId ?? this.loadingMoreMessageId),
    );
  }
}

// --- Chat Notifier ---

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _chatService;
  final SessionService _sessionService;
  final CacheService? _cacheService;

  static const int _pageSize = 100;

  ChatNotifier({
    required ChatService chatService,
    required SessionService sessionService,
    CacheService? cacheService,
  })  : _chatService = chatService,
        _sessionService = sessionService,
        _cacheService = cacheService,
        super(ChatState(sessionId: SessionManager.generateSessionId()));

  /// Send a message (handles routing, streaming, disambiguation)
  Future<void> sendMessage(String text, {String? forcedRoute}) async {
    if (text.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      streamingContent: '',
      streamingPhase: '',
      clearCategory: true,
      clearError: true,
    );

    try {
      // Step 1: Get route classification (skip if forced)
      final route = forcedRoute ??
          await _chatService.getRoute(text, state.sessionId);

      if (route == 'sql' || route == 'csv') {
        // Step 2a: Non-streaming query
        await _handleNonStreamingQuery(text, route);
      } else {
        // Step 2b: Streaming query (pdf, math, out_of_scope, meta)
        await _handleStreamingQuery(text, route);
      }
    } catch (e) {
      // Try serving from cache when offline
      if (_cacheService != null && _cacheService.hasCachedResponse(text)) {
        _serveCachedResponse(text);
      } else {
        _addErrorMessage(_extractErrorMessage(e));
      }
    }
  }

  Future<void> _handleNonStreamingQuery(String text, String route) async {
    final response = await _chatService.sendQuery(
      query: text,
      sessionId: state.sessionId,
      route: route,
      pageSize: _pageSize,
    );

    // Cache the response content for offline use
    _cacheService?.cacheResponse(
      query: text,
      responseJson: {
        'content': response.content,
        'response_time': response.responseTime,
        'sources': response.sources,
      },
    );

    final botMessage = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      role: MessageRole.assistant,
      content: response.content,
      timestamp: DateTime.now(),
      originalQuery: text,
      metadata: MessageMetadata.fromQueryResponse(response),
    );

    state = state.copyWith(
      messages: [...state.messages, botMessage],
      isLoading: false,
    );
  }

  Future<void> _handleStreamingQuery(String text, String route) async {
    String accumulatedContent = '';
    SSEDoneEvent? finalEvent;

    await for (final event in _chatService.streamQuery(
      query: text,
      sessionId: state.sessionId,
      route: route,
      pageSize: _pageSize,
    )) {
      switch (event) {
        case SSEPhaseEvent():
          if (event.phase == 'answer' && event.content != null) {
            accumulatedContent += event.content!;
            state = state.copyWith(
              streamingContent: accumulatedContent,
              streamingPhase: '',
            );
          } else {
            final phaseText = _getPhaseText(event.phase);
            state = state.copyWith(streamingPhase: phaseText);
          }
        case SSEDoneEvent():
          finalEvent = event;
          if (accumulatedContent.isEmpty) {
            accumulatedContent = event.content;
          }
        case SSEErrorEvent():
          _addErrorMessage(event.message);
          return;
      }
    }

    // Cache streaming response content
    final finalContent = accumulatedContent.isNotEmpty
        ? accumulatedContent
        : finalEvent?.content ?? 'No response';

    _cacheService?.cacheResponse(
      query: text,
      responseJson: {
        'content': finalContent,
        'response_time': finalEvent?.responseTime ?? '0s',
        'sources': finalEvent?.sources ?? ['System'],
      },
    );

    // Finalize message
    final botMessage = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      role: MessageRole.assistant,
      content: accumulatedContent.isNotEmpty
          ? accumulatedContent
          : finalEvent?.content ?? 'No response',
      timestamp: DateTime.now(),
      originalQuery: text,
      metadata: finalEvent != null
          ? MessageMetadata(
              responseTime: finalEvent.responseTime,
              sources: finalEvent.sources,
              tableData: finalEvent.tableData,
              sqlQuery: finalEvent.sqlQuery,
              needsDisambiguation: finalEvent.needsDisambiguation,
              disambiguationOptions: finalEvent.disambiguationOptions,
              needsClarification: finalEvent.needsClarification,
              clarificationMessage: finalEvent.clarificationMessage,
              clarificationOptions: finalEvent.clarificationOptions,
              visualization: finalEvent.visualization,
            )
          : MessageMetadata(responseTime: '0s', sources: ['System']),
    );

    state = state.copyWith(
      messages: [...state.messages, botMessage],
      isLoading: false,
      streamingContent: '',
      streamingPhase: '',
    );
  }

  /// Load a specific page for a paginated table result
  Future<void> loadPage(String messageId, int page) async {
    // Find the message
    final msgIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final message = state.messages[msgIndex];
    final tableData = message.metadata?.tableData;
    if (tableData == null || tableData.resultId == null) return;
    if (page == tableData.page) return; // Already on this page

    // Set loading state
    state = state.copyWith(loadingMoreMessageId: messageId);

    try {
      final newPage = await _chatService.fetchTablePage(
        resultId: tableData.resultId!,
        page: page,
        pageSize: tableData.pageSize ?? _pageSize,
      );

      // Replace rows with the new page data
      final updatedTableData = tableData.replacePage(newPage);
      final updatedMetadata =
          message.metadata!.copyWithTableData(updatedTableData);
      final updatedMessage = message.copyWithMetadata(updatedMetadata);

      // Replace the message in the list
      final updatedMessages = [...state.messages];
      updatedMessages[msgIndex] = updatedMessage;

      state = state.copyWith(
        messages: updatedMessages,
        clearLoadingMore: true,
      );
    } catch (e) {
      state = state.copyWith(clearLoadingMore: true);
    }
  }

  /// Serve a cached response when offline
  void _serveCachedResponse(String query) {
    final cached = _cacheService?.getCachedResponse(query);
    if (cached == null) return;

    final botMessage = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      role: MessageRole.assistant,
      content: cached['content'] as String? ?? '',
      timestamp: DateTime.now(),
      originalQuery: query,
      metadata: MessageMetadata(
        responseTime: cached['response_time'] as String? ?? '0s',
        sources: (cached['sources'] as List?)?.cast<String>() ?? ['Cache'],
      ),
    );

    state = state.copyWith(
      messages: [...state.messages, botMessage],
      isLoading: false,
      streamingContent: '',
      streamingPhase: '',
    );
  }

  String _getPhaseText(String phase) {
    switch (phase) {
      case 'planning':
        return 'Planning...';
      case 'retrieval':
        return 'Retrieving documents...';
      case 'reasoning':
        return 'Analyzing...';
      default:
        return '';
    }
  }

  String _extractErrorMessage(Object e) {
    if (e is DioException) {
      final apiError = ApiException.fromDioException(e);
      return apiError.message;
    }
    if (e is ApiException) {
      return e.message;
    }
    return e.toString();
  }

  void _addErrorMessage(String error) {
    final errorMessage = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      role: MessageRole.assistant,
      content: '**Error:** $error',
      timestamp: DateTime.now(),
      metadata: MessageMetadata(
        responseTime: '0s',
        sources: ['Error'],
      ),
    );

    state = state.copyWith(
      messages: [...state.messages, errorMessage],
      isLoading: false,
      streamingContent: '',
      streamingPhase: '',
    );
  }

  /// Clear all messages and reset session
  Future<void> clearChat() async {
    try {
      await _sessionService.clearSession(state.sessionId);
    } catch (_) {}

    state = ChatState(sessionId: SessionManager.generateSessionId());
  }

  /// Select a category for browsing
  void selectCategory(String? categoryId) {
    state = state.copyWith(
      selectedCategory: categoryId,
      clearCategory: categoryId == null,
    );
  }

  /// Cancel active streaming
  void cancelStream() {
    _chatService.cancelStream();
  }
}

// --- Main Provider ---

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(
    chatService: ref.read(chatServiceProvider),
    sessionService: ref.read(sessionServiceProvider),
    cacheService: CacheService(),
  );
});
